package require TclOO
package require fileutil
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_detector.tcl]

# A class to manage and set up a complete CTSimU scenario,
# includes e.g. all coordinate systems, etc.

namespace eval ::ctsimu {
	::oo::class create scenario {
		variable _running
		variable _batch_is_running
		variable _json_loaded_successfully
		variable _settings;  # dictionary with simulation settings

		variable _cs_world
		variable _detector

		constructor { } {
			# State
			my _set_run_status       0
			my _set_batch_run_status 0

			# Settings
			set _settings [dict create]

			# Standard settings
			my set output_fileformat        "tiff"
			my set output_datatype          "16bit"
			my set output_basename          "proj_"
			my set output_folder            ""

			# CERA config file options:
			my set create_cera_config_file  1
			my set cera_output_datatype     "16bit"

			# openCT config file options:
			my set create_openct_config_file 1
			my set openct_output_datatype   "16bit"

			# Initialize a world coordinate system:
			set _cs_world  [::ctsimu::coordinate_system new "World"]
			$_cs_world reset
			
			# Objects in the scene:
			set _detector [::ctsimu::detector new]

			my reset
		}

		destructor {
			$_cs_world destroy
			$_detector destroy
		}

		method reset { } {
			# Reset scenario to standard settings.
			my _set_json_load_status      0

			my set json_file             ""
			my set start_angle            0
			my set stop_angle           360
			my set n_projections       2000
			my set projection_counter_format "%04d"
			my set proj_nr                0
			my set include_final_angle    0
			my set start_proj_nr          0

			my set dark_field             0; # 1=yes, 0=no
			my set n_darks                1
			my set n_flats                1
			my set n_flat_avg            20
			my set flat_field_ideal       0; # 1=yes, 0=no

			$_detector reset
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
			my reset

			set jsonfiledir [file dirname "$json_filename"]

			set jsonfile [open $json_filename r]
			fconfigure $jsonfile -encoding utf-8
			set jsonstring [read $jsonfile]
			close $jsonfile
			
			# Detector
			# ------------
			$_detector set_from_json $jsonstring $_cs_world $_cs_world

			return 1
		}
	}
}