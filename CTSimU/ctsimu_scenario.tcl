package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_samplemanager.tcl]

# A class to manage and set up a complete CTSimU scenario,
# includes e.g. all coordinate systems, etc.

namespace eval ::ctsimu {
	::oo::class create scenario {
		variable _running
		variable _batch_is_running
		variable _json_loaded_successfully
		variable _settings;  # dictionary with simulation settings

		variable _source
		variable _stage
		variable _detector
		variable _sample_manager
		variable _material_manager

		constructor { } {
			# State
			my _set_run_status       0
			my _set_batch_run_status 0

			# Settings
			set _settings [dict create]

			# Standard settings
			my set output_fileformat        "tiff"
			my set output_datatype          "uint16"
			my set output_basename          "proj_"
			my set output_folder            ""

			# CERA config file options:
			my set create_cera_config_file  1
			my set cera_output_datatype     "float32"

			# openCT config file options:
			my set create_openct_config_file 1
			my set openct_output_datatype   "float32"

			# Objects in the scene:
			set _source   [::ctsimu::source new]
			set _stage    [::ctsimu::stage new]
			set _detector [::ctsimu::detector new]
			set _sample_manager [::ctsimu::samplemanager new]
			set _material_manager [::ctsimu::materialmanager new]

			my reset
		}

		destructor {
			$_source destroy
			$_stage destroy
			$_detector destroy
			$_sample_manager destroy
		}

		method reset { } {
			# Reset scenario to standard settings.
			my _set_json_load_status      0

			my set json_file             ""
			my set json_file_directory   ""
			my set start_angle            0
			my set stop_angle           360
			my set n_projections       2000
			my set frame_average          1
			my set projection_counter_format "%04d"
			my set proj_nr                0
			my set include_final_angle    0
			my set start_proj_nr          0
			my set scan_direction     "CCW"

			my set dark_field             0; # 1=yes, 0=no
			my set n_darks                1
			my set n_flats                1
			my set n_flat_avg            20
			my set flat_field_ideal       0; # 1=yes, 0=no

			my set current_frame          0
			my set n_frames            2000; # frame_average * n_projections

			my set environment_material "void"

			my set show_stage             1; # show stage as object in the scene

			$_detector reset
			$_stage reset
			$_source reset

			# Delete all samples:
			$_sample_manager reset
		}

		# Getters
		method get { setting } {
			# Get a settings value from the settings dict
			return [dict get $_settings $setting]
		}

		method is_running { } {
			return $_running
		}

		method batch_is_running { } {
			return $_batch_is_running
		}

		method json_loaded_successfully { } {
			return $_json_loaded_successfully
		}

		# Setters
		method set { setting value } {
			# Set a settings value in the settings dict
			dict set _settings $setting $value

			# The projection counter format (e.g. %04d) needs
			# to be adapted to the number of projections:
			if { $setting == {n_projections} } {
				my create_projection_counter_format { $value }
			}
		}

		method _set_run_status { status } {
			set _running $status
		}

		method _set_batch_run_status { status } {
			set _batch_is_running $status
		}

		method _set_json_load_status { status } {
			set _json_loaded_successfully $status
		}

		method set_basename_from_json { json_filename } {
			# Extracts the base name of a JSON file and
			# sets the output_basename setting accordingly.
			set baseName [file root [file tail $json_filename]]
			set outputBaseName $baseName
			#append outputBaseName "_aRTist"
			my set output_basename $outputBaseName
		}

		method create_projection_counter_format { nProjections } {
			# Sets the number format string to get the correct
			# number of digits in the consecutive projection file names.
			set digits 4

			# For anything bigger than 10000 projections (0000 ... 9999) we need more filename digits.
			if { $nProjections > 10000 } {
				set digits [expr int(ceil(log10($nProjections)))]
			}

			set pcformat "%0"
			append pcformat $digits
			append pcformat "d"

			my set projection_counter_format $pcformat
		}

		method load_json_scene { json_filename } {
			::ctsimu::status_info "Reading JSON file..."

			my reset
			my set json_file $json_filename
			my set json_file_directory [file dirname "$json_filename"]

			set jsonstring [::ctsimu::read_json_file $json_filename]

			# Default output basename and folder
			# ------------------------------------
			my set output_basename [file root [file tail $json_filename]]
			set folder [my get json_file_directory]
			append folder "/"
			append folder [my get output_basename]
			my set output_folder $folder

			# Acquisition Parameters
			# -------------------------
			::ctsimu::status_info "Reading acquisition parameters..."
			my set start_angle [::ctsimu::get_value_in_unit "deg" $jsonstring {acquisition start_angle} 0]
			my set stop_angle [::ctsimu::get_value_in_unit "deg" $jsonstring {acquisition stop_angle} 360]

			my set n_projections [::ctsimu::get_value $jsonstring {acquisition number_of_projections} 1]
			my set frame_average [::ctsimu::get_value $jsonstring {acquisition frame_average} 1]
			my set n_frames [expr [my get n_projections] * [my get frame_average]]

			my set include_final_angle [::ctsimu::get_value_in_unit "bool" $jsonstring {acquisition include_final_angle} 0]
			my set scan_direction [::ctsimu::get_value $jsonstring {acquisition direction} "CCW"]

			# Materials
			# -------------
			$_material_manager set_from_json $jsonstring

			# Environment Material:
			# ------------------------
			my set environment_material [::ctsimu::get_value $jsonstring {environment material_id} "null"]
			if { [my get environment_material] == "null" } {
				::ctsimu::warn "No environment material found. Set to \'void\'."
				my set environment_material "void"
			}

			# Stage
			# -------------
			::ctsimu::status_info "Reading stage parameters..."
			$_stage set_from_json $jsonstring

			# X-Ray Source
			# -------------
			::ctsimu::status_info "Reading X-ray source parameters..."
			$_source set_from_json $jsonstring [$_stage current_coordinate_system]
			
			# Detector
			# -------------
			::ctsimu::status_info "Reading detector source parameters..."
			$_detector set_from_json $jsonstring [$_stage current_coordinate_system]

			# Place objects in scene
			# ------------------------
			::ctsimu::status_info "Placing objects..."
			$_source   place_in_scene [$_stage current_coordinate_system]
			$_detector place_in_scene [$_stage current_coordinate_system]

			# Add the stage as a sample to the sample manager
			# so that it can be shown in the scene:
			if { [my get show_stage] } {
				$_sample_manager add_sample [$_stage get_sample_copy [my get environment_material]]
			}

			$_sample_manager set_frame [$_stage current_coordinate_system] [my get current_frame] [my get n_frames]
			$_sample_manager load_meshes [$_stage current_coordinate_system]

			::ctsimu::status_info "Scenario loaded."
			return 1
		}

		method set_frame { frame { force 0 } } {
			my set current_frame $frame

			$_material_manager set_frame $frame [my get n_frames]
			$_sample_manager set_frame [$_stage current_coordinate_system] $frame [my get n_frames]

			# Set environment material:
			if { [::ctsimu::aRTist_available] } {
				# We have to ask the material manager for the
				# aRTist id of the environment material in each frame,
				# just in case it has changed from vacuum (void) to
				# a higher-density material:
				set ::Xsetup(SpaceMaterial) [ [$_material_manager get [my get environment_material]] aRTist_id ]
			}
		}
	}
}