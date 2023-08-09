package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_samplemanager.tcl]

# A class to manage and set up a complete CTSimU scenario,
# includes e.g. all coordinate systems, etc.

namespace eval ::ctsimu {
	::oo::class create scenario {
		variable _supported_fileformat_major
		variable _supported_fileformat_minor

		variable _running
		variable _json_loaded_successfully
		variable _settings;  # dictionary with simulation settings

		variable _source
		variable _stage
		variable _detector
		variable _sample_manager
		variable _material_manager

		variable _initial_SDD
		variable _initial_SOD
		variable _initial_ODD
		# Computed by the 'update' method:
		variable _SDD
		variable _SOD
		variable _ODD

		constructor { } {
			# Maximum supported file format version:
			set _supported_fileformat_major 1
			set _supported_fileformat_minor 2

			# State
			my _set_run_status 0

			# Settings
			set _settings [dict create]

			# Standard settings
			my set output_fileformat        "tiff"
			my set output_datatype          "uint16"
			my set output_basename          "proj_"
			my set output_folder            ""

			# Option to show stage coordinate system in scene:
			my set show_stage               1

			# CERA config file options:
			my set create_cera_config_file  1
			my set cera_output_datatype     "float32"

			# openCT config file options:
			my set create_openct_config_file 1
			my set openct_output_datatype   "float32"

			# Sample and material manager:
			set _sample_manager [::ctsimu::samplemanager new]
			set _material_manager [::ctsimu::materialmanager new]

			# Objects in the scene:
			set _source   [::ctsimu::source new]
			set _stage    [::ctsimu::stage new]
			set _detector [::ctsimu::detector new]

			$_source initialize $_material_manager
			$_detector initialize $_material_manager

			my reset
		}

		destructor {
			$_source destroy
			$_stage destroy
			$_detector destroy
			$_sample_manager destroy
			$_material_manager destroy
		}

		method reset { } {
			# Reset scenario to standard settings.
			my _set_json_load_status       0

			my set json_file              ""; # full path + name of JSON file
			my set json_file_name         ""; # JSON filename without path
			my set json_file_directory    ""; # Path to JSON file
			my set start_angle             0
			my set stop_angle            360
			my set projection_counter_format "%04d"
			my set include_final_angle     0
			my set start_projection_number 0
			my set scan_direction      "CCW"

			# Scattering using McRay
			# interval: re-calculate scatter image every n images:
			my set scattering_on                  0
			my set scattering_image_interval      1
			my set scattering_current_image_step -1
			my set scattering_mcray_photons      2e7

			# Number of dark and flat field images:
			my set n_darks                0
			my set n_darks_avg            1
			my set n_flats                1
			my set n_flats_avg           20
			my set dark_field_ideal       1; # 1=yes, 0=no
			my set flat_field_ideal       0; # 1=yes, 0=no
			my set ff_correction_on       0; # run a flat field correction in aRTist?

			my set current_frame          0
			my set frame_average          1
			my set n_projections       2000
			my set n_frames            2000; # = frame_average * n_projections

			my set environment_material "void"; # id of the environment material

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

		method json_loaded_successfully { } {
			return $_json_loaded_successfully
		}

		method detector { } {
			return $_detector
		}

		method source { } {
			return $_source
		}

		method stage { } {
			return $_stage
		}

		method get_current_stage_rotation_angle { } {
			set startAngle    [expr double([my get start_angle])]
			set stopAngle     [expr double([my get stop_angle])]
			set nPositions    [expr double([my get n_frames])]

			# If the final projection is taken at the stop angle (and not one step before),
			# the number of positions has to be decreased by 1, resulting in one less
			# angular step being performed.
			if { [my get include_final_angle] == 1} {
				if {$nPositions > 0} {
					set nPositions [expr $nPositions - 1]
				}
			}

			set angularRange 0.0
			if {$startAngle <= $stopAngle} {
				set angularRange [expr $stopAngle - $startAngle]
			} else {
				::ctsimu::fail "The start angle cannot be greater than the stop angle. Scan direction must be specified by the acquisition \'direction\' keyword (CCW or CW)."
				return 0
			}

			set angularPosition $startAngle
			if {$nPositions != 0} {
				set angularPosition [expr $startAngle + [my get current_frame]*$angularRange / $nPositions]
			}

			# Mathematically negative:
			if {[my get scan_direction] == "CW"} {
				set angularPosition [expr -$angularPosition]
			}

			return $angularPosition
		}

		# Setters
		method set { setting value } {
			# We changed the keywords for the data types:
			# 16bit -> uint16
			# 32bit -> float32
			# For backwards compatibility, we need to check
			# if someone still has those in their aRTist settings.
			if { $setting == {output_datatype} || $setting == {cera_output_datatype} || $setting == {openct_output_datatype} } {
				if { $value == "16bit" } {
					set value "uint16"
				} elseif { $value == "32bit" } {
					set value "float32"
				}
			}

			# Set a settings value in the settings dict
			dict set _settings $setting $value

			# The projection counter format (e.g. %04d) needs
			# to be adapted to the number of projections:
			if { $setting == {n_projections} } {
				my set projection_counter_format [::ctsimu::generate_projection_counter_format $value]

				# The number of frames should currently match
				# the number of projections, as long as we don't use
				# sophisticated blurring techniques during frame
				# averaging.
				my set n_frames $value
			}
		}

		method _set_run_status { status } {
			set _running $status
		}

		method _set_json_load_status { status } {
			set _json_loaded_successfully $status
		}

		method set_basename_from_json { json_filename } {
			# Extracts the base name of a JSON file and
			# sets the output_basename setting accordingly.
			set baseName [file rootname [file tail $json_filename]]
			set outputBaseName $baseName
			#append outputBaseName "_aRTist"
			my set output_basename $outputBaseName
		}

		method create_run_filenames { { run 1 } { nruns 1 } } {
			# Generate the strings for output basename,
			# projection folder and reconstruction folder.
			# Decides whether the run number must be added.

			set s_run_output_basename [my get output_basename]

			set s_run_projection_folder [my get output_folder]
			append s_run_projection_folder "/projections"

			set s_run_recon_folder [my get output_folder]
			append s_run_recon_folder "/reconstruction"

			if { $nruns > 1 } {
				# Multiple runs. We need to add the run number
				# to the names of files and folders.
				set s_run "run[format "%03d" $run]"

				if { $s_run_output_basename != "" } {
					append s_run_output_basename "_"
				}
				append s_run_output_basename $s_run
				append s_run_projection_folder "/$s_run"
				append s_run_recon_folder "/$s_run"
			}

			my set run_output_basename $s_run_output_basename
			my set run_projection_folder $s_run_projection_folder
			my set run_recon_folder $s_run_recon_folder

			# dots_to_root is the relative path prefix
			# to get from the projection folder to the project's root:
			if { $nruns > 1 } {
				my set dots_to_root "../.."
				my set ff_projection_short_path "projections/$s_run/corrected"
			} else {
				my set dots_to_root ".."
				my set ff_projection_short_path "projections/corrected"
			}
		}

		method set_next_frame { } {
			# Set up the next frame in aRTist.
			my set_frame [expr [my get current_frame]+1]
		}

		method set_previous_frame { } {
			# Set up the previous frame in aRTist.
			my set_frame [expr [my get current_frame]-1]
		}

		method load_json_scene { json_filename } {
			# Loads a CTSimU scenario from the given JSON file.
			::ctsimu::status_info "Reading JSON file..."

			my reset
			my set json_file $json_filename
			my set json_file_name [file tail "$json_filename"]
			my set json_file_directory [file dirname "$json_filename"]
			::ctsimu::set_json_path [my get json_file_directory]

			set jsonstring [::ctsimu::read_json_file $json_filename]

			# Check file type and file format version.
			# -------------------------------------------
			if { [::ctsimu::json_exists $jsonstring {file file_type}] } {
				if { [::ctsimu::get_value $jsonstring {file file_type}] == "CTSimU Scenario" } {
					# Check file format version:
					set major 0
					set minor 0
					if { [::ctsimu::json_exists $jsonstring {file file_format_version major}] } {
						set major [::ctsimu::get_value $jsonstring {file file_format_version major}]
					} else {
						::ctsimu::fail "No major file format version number found."
					}

					if { [::ctsimu::json_exists $jsonstring {file file_format_version minor}] } {
						set minor [::ctsimu::get_value $jsonstring {file file_format_version minor}]
					} else {
						::ctsimu::fail "No minor file format version number found."
					}

					if { $major == 0 } {
						if { $minor <= 9} {
							# pass
						} else {
							::ctsimu::fail "File format version $major.$minor is not supported."
						}
					} elseif { $major < $_supported_fileformat_major } {
						# All file format versions prior to
						# the supported major version should be supported.
						# Otherwise, add additional guards here, like for
						# major version 0.
					} elseif { $major == $_supported_fileformat_major} {
						if { $minor <= $_supported_fileformat_minor } {
							# pass
						} else {
							::ctsimu::fail "File format version $major.$minor is not supported."
						}
					} else {
						::ctsimu::fail "File format version $major.$minor is not supported."
					}
				} else {
					::ctsimu::fail "Invalid scenario file. The file type must be set to \"CTSimU Scenario\"."
				}
			} else {
				::ctsimu::fail "Invalid scenario file. Check for JSON syntax errors. Or maybe you tried to load a CTSimU metadata file?"
			}

			# Default output basename and folder
			# ------------------------------------
			my set output_basename [file rootname [file tail $json_filename]]
			set folder [my get json_file_directory]
			append folder "/"
			append folder [my get output_basename]
			my set output_folder $folder

			# Acquisition Parameters
			# -------------------------
			::ctsimu::status_info "Reading acquisition parameters..."
			my set start_angle [::ctsimu::get_value_in_native_unit "deg" $jsonstring {acquisition start_angle} 0]
			my set stop_angle [::ctsimu::get_value_in_native_unit "deg" $jsonstring {acquisition stop_angle} 360]

			my set n_projections [::ctsimu::get_value $jsonstring {acquisition number_of_projections} 1]
			my set frame_average [::ctsimu::get_value $jsonstring {acquisition frame_average} 1]

			my set include_final_angle [::ctsimu::get_value_in_native_unit "bool" $jsonstring {acquisition include_final_angle} 0]
			my set scan_direction [::ctsimu::get_value $jsonstring {acquisition direction} "CCW"]

			# Dark and flat field correction settings
			# ------------------------------------------
			my set n_darks [::ctsimu::get_value $jsonstring {acquisition dark_field number} 0]
			# aRTist can currently only take ideal dark field images.
			# Averaging=1 and ideal mode are therefore currently forced.
			#my set n_darks_avg [::ctsimu::get_value $jsonstring {acquisition dark_field frame_average} 1]
			# my set dark_field_ideal [::ctsimu::get_value_in_native_unit "bool" $jsonstring {acquisition dark_field ideal} 0]
			if { [my get n_darks] > 0 } {
				# In (currently forced) ideal mode, one dark image is enough.
				my set n_darks 1
			}

			my set n_flats [::ctsimu::get_value $jsonstring {acquisition flat_field number} 0]
			my set n_flats_avg [::ctsimu::get_value $jsonstring {acquisition flat_field frame_average} 1]
			my set flat_field_ideal [::ctsimu::get_value_in_native_unit "bool" $jsonstring {acquisition flat_field ideal} 0]


			my set ff_correction_on [::ctsimu::get_value_in_native_unit "bool" $jsonstring {acquisition flat_field correction} 0]

			# Materials
			# -------------
			$_material_manager set_from_json $jsonstring

			# Environment Material:
			# ------------------------
			my set environment_material [::ctsimu::get_value $jsonstring {environment material_id} "null"]
			if { [my get environment_material] == "null" } {
				::ctsimu::warning "No environment material found. Set to \'void\'."
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
			$_source set voltage_max [[$_source parameter voltage] maximum_value [my get n_frames] 0]

			# Detector
			# -------------
			::ctsimu::status_info "Reading detector parameters..."
			$_detector set_from_json $jsonstring [$_stage current_coordinate_system]
			::ctsimu::info "Detector hash: [$_detector hash]"

			# Place objects in scene
			# ------------------------
			set stageCS [$_stage current_coordinate_system]

			$_source set_frame 0 [my get current_frame] [my get n_frames] 0
			set _initial_source_Xray_current [$_source get current]

			$_detector set_frame 0 [my get current_frame] [my get n_frames] 0

			my update
			set _initial_SDD $_SDD
			set _initial_SOD $_SOD
			set _initial_ODD $_ODD

			$_source initialize $_material_manager
			$_detector initialize $_material_manager $_initial_SDD $_initial_source_Xray_current

			$_detector place_in_scene $stageCS
			$_source place_in_scene $stageCS

			# Add the stage as a sample to the sample manager
			# so that it can be shown in the scene:
			if { [my get show_stage] } {
				# Calculate a scaling factor for the stage object,
				# such that it matches 2/3 of the detector height. The size
				# of the original stage STL is 52 mm in each direction.
				set stage_scaling_factor [expr [$_detector physical_height] / 52.0 / 1.5 ]

				# Create a sample for the stage
				# that can be added to the sample manager:
				set stage_copy [$_stage get_sample_copy]
				$stage_copy set scaling_factor_r $stage_scaling_factor
				$stage_copy set scaling_factor_s $stage_scaling_factor
				$stage_copy set scaling_factor_t $stage_scaling_factor

				$_sample_manager add_sample $stage_copy
			}

			$_sample_manager set_from_json $jsonstring $stageCS
			$_sample_manager set_frame $stageCS [my get current_frame] [my get n_frames]

			$_sample_manager load_meshes $stageCS $_material_manager

			# Multisampling
			# -----------------
			if { [::ctsimu::aRTist_available] } {
				if { ([$_source get spot_sigma_u] == 0) || \
					 ([$_source get spot_sigma_v] == 0) } {
					# For point sources, set the detector multisampling
					# to 3x3 as default value.
					$_detector set multisampling "3x3"
					$_source set multisampling "point"
				} else {
					$_detector set multisampling "2x2"
					$_source set multisampling "20"
				}
			}

			# any user-specific multisampling options?
			$_detector set_parameter_from_key multisampling $jsonstring {simulation aRTist multisampling_detector}
			$_source set_parameter_from_key multisampling $jsonstring {simulation aRTist multisampling_spot}

			# Scattering
			# -----------------
			my set scattering_on [::ctsimu::get_value_in_native_unit "bool" $jsonstring {acquisition scattering} 0]
			my set scattering_image_interval [::ctsimu::get_value $jsonstring {simulation aRTist scattering_image_interval value} [my get scattering_image_interval]]
			my set scattering_mcray_photons [::ctsimu::get_value $jsonstring {simulation aRTist scattering_mcray_photons value} [my get scattering_mcray_photons]]

			# Set the source and detector as static
			# if they are not subject to drifts. This
			# prevents them from having their coordinate
			# systems re-calculated in each frame.
			# -> Faster calculation of projection matrices.
			$_detector set_static_if_no_drifts
			$_source set_static_if_no_drifts

			my _set_json_load_status 1

			# Activate flat field correction within aRTist?
			if { [my get ff_correction_on] } {
				my set_frame 0
				::ctsimu::status_info "Taking flat field image..."
				::XDetector::FFCorrClearCmd
				set ::Xdetector(FFCorrRun) 1
				my render_projection_image 0
			} else {
				set ::Xdetector(FFCorrRun) 0
			}

			return 1
		}

		method set_frame { frame } {
			# Set up the given frame number in the aRTist scene.
			if { $_json_loaded_successfully == 0 } {
				# No JSON scene loaded yet?
				::ctsimu::warning "No scenario loaded."
				return
			}

			if { [my is_running] == 0 } {
				::ctsimu::status_info "Setting frame $frame..."
			}

			my set current_frame $frame
			set nFrames [my get n_frames]

			# Stage rotation:
			set stage_rotation_angle_in_rad [::ctsimu::in_rad [my get_current_stage_rotation_angle]]
			$_stage set_frame $::ctsimu::world $frame $nFrames $stage_rotation_angle_in_rad

			# Material changes may already affect source and detector:
			$_material_manager set_frame $frame $nFrames

			$_source set_frame 0 $frame $nFrames 0
			$_detector set_frame 0 $frame $nFrames 0

			set stageCS [$_stage current_coordinate_system]
			$_sample_manager set_frame $stageCS $frame $nFrames
			$_sample_manager update_scene $stageCS $_material_manager
			$_detector place_in_scene $stageCS
			$_source place_in_scene $stageCS

			if { [::ctsimu::aRTist_available] } {
				# We have to ask the material manager for the
				# aRTist id of the environment material in each frame,
				# just in case it has changed from vacuum (void) to
				# a higher-density material:
				set ::Xsetup(SpaceMaterial) [ [$_material_manager get [my get environment_material]] aRTist_id ]

				if { [my is_running] == 0 } {
					::ctsimu::status_info "Generating X-ray source and spectrum..."
				}
				$_source set_in_aRTist

				if { [my is_running] == 0 } {
					::ctsimu::status_info "Generating detector..."
				}
				$_detector set_in_aRTist [$_source get voltage_max]
				if { [my is_running] == 0 } {
					::ctsimu::status_info "Setting frame $frame..."
				}

				# Scattering:
				if { ([my get scattering_on] == 1) && ([my get scattering_image_interval] > 0) } {
					set ::Xscattering(AutoBase) min
					set ::Xscattering(nPhotons) [my get scattering_mcray_photons]

					if { [my get scattering_image_interval] > 1 } {
						set ::Xscattering(McRayInitFile) 1

						# Do we have to calculate a new scatter image?
						# This is the case if the scattering image step has changed.
						set this_scattering_image_step [expr floor($frame/[my get scattering_image_interval])]
						if { $this_scattering_image_step != [my get scattering_current_image_step] } {
							my set scattering_current_image_step $this_scattering_image_step
							set ::Xscattering(Mode) McRay
						} else {
							# External file loading is set by aRTist automatically.
						}
					} else {
						# A scatter image is calculated for each frame.
						set ::Xscattering(McRayInitFile) 0
						set ::Xscattering(Mode) McRay
					}
				} else {
					set ::Xscattering(Mode) off
					set ::Xscattering(McRayInitFile) 0
				}

				if { [my is_running] == 0 } {
					::ctsimu::status_info "Rendering preview for frame $frame..."
				}

				${::ctsimu::ctsimu_module_namespace}::setFrameNumber $frame
				Engine::RenderPreview
			}

			if { [my is_running] == 0 } {
				::ctsimu::status_info "Ready."
			}
		}

		method set_frame_for_recon { frame } {
			# Internally set up coordinate systems for scene as
			# "seen" by the reconstruction software.
			# Used to compute projection matrices.
			my set current_frame $frame
			set nFrames [my get n_frames]

			set stage_rotation_angle_in_rad [::ctsimu::in_rad [my get_current_stage_rotation_angle]]
			$_stage set_frame_for_recon $::ctsimu::world $frame $nFrames $stage_rotation_angle_in_rad

			$_source set_frame_for_recon 0 $frame $nFrames 0
			$_detector set_frame_for_recon 0 $frame $nFrames 0
		}

		method update { } {
			# Calculate some geometry parameters (SDD, SOD, ODD)
			# for the current frame.
			set source_cs           [ $_source current_coordinate_system ]
			set stage_cs            [ $_stage current_coordinate_system ]
			set detector_cs         [ $_detector current_coordinate_system ]

			set source_from_image   [$source_cs get_copy]
			set stage_from_detector [$stage_cs get_copy]

			$source_from_image change_reference_frame $::ctsimu::world $detector_cs
			$stage_from_detector change_reference_frame $::ctsimu::world $detector_cs

			set _SDD [expr abs([[$source_from_image center] z])]
			set _ODD [expr abs([[$stage_from_detector center] z])]
			set _SOD [ [$source_cs center] distance [$stage_cs center] ]
		}

		method stop_scan { { noMessage 0 } } {
			# Stop the scan simulation.
			# noMessage can be set to 1 if the "Stopped" status message
			# should not appear in the module's GUI.
			my _set_run_status 0
			if { $noMessage == 0 } {
				::ctsimu::status_info "Stopped."
			}
		}

		method start_scan { { run 1 } { nruns 1 } } {
			# Start the scan simulation for the given run number, out of a total of nruns.

			# Some guards to check for correct conditions:
			if { $run <= 0 } {
				::ctsimu::fail "Cannot start scan. Number of current run is given as $run. Must be >0."
				return
			}
			if { $nruns <= 0 } {
				::ctsimu::fail "Cannot start scan. Number of runs is given as $nruns. Must be >0."
				return
			}
			if { ![my json_loaded_successfully] } {
				::ctsimu::fail "Cannot start scan. JSON scenario was not loaded correctly."
				return
			}

			my create_run_filenames $run $nruns
			my prepare_postprocessing_configs

			my _set_run_status 1

			if { [my is_running] } {
				# Create flat field and dark field images.
				my generate_flats_and_darks
			}

			my set scattering_current_image_step -1

			if { [my is_running] } {
				# Run actual scan.
				set nProjections [my get n_projections]
				set projCtrFmt [my get projection_counter_format]

				if {$nProjections > 0} {
					#aRTist::InitProgress
					#aRTist::ProgressQuantum $nProjections

					for {set projNr [my get start_projection_number]} {$projNr < $nProjections} {incr projNr} {
						my set_frame $projNr

						set pnr [expr $projNr+1]
						set prcnt [expr round((100.0*($projNr+1.0))/$nProjections)]
						::ctsimu::status_info "Taking projection $pnr/$nProjections... ($prcnt%)"
						set fileNameSuffix [format $projCtrFmt $projNr]
						my save_projection_image $projNr $fileNameSuffix

						if {[my is_running] == 0} {break}
					}

					#aRTist::ProgressFinished
				}
			}

			# Check if we are still successfully running.
			# If so, print a "done" message after stopping the simulation.
			# Otherwise, the "stopped" status info message will remain
			# in the CTSimU Module window.
			set display_done_message 0
			if { [my is_running] } {
				set display_done_message 1
			}

			my stop_scan

			if { $display_done_message == 1 } {
				::ctsimu::status_info "Simulation done."
			}
		}

		method prepare_postprocessing_configs { } {
			# Generates the flat field correction Python script
			# and config files for various reconstruction softwares,
			# depending on the current settings.

			# Make projection folder and metadata file:
			file mkdir [my get run_projection_folder]

			# Create metadata file:
			my create_metadata_file

			# Create flat fiel correction script
			# if flat field images are generated:
			if { [my get n_flats] > 0 } {
				my create_flat_field_correction_script
			}

			# Make reconstruction files for scans with multiple projections,
			# if activated in the settings.
			if { ([my get n_projections] > 1) && \
				 ([my get create_openct_config_file] || [my get create_cera_config_file]) } {
				file mkdir [my get run_recon_folder]
				my create_recon_configs
			}
		}

		method render_projection_image { projNr } {
			# Run a full simulation in aRTist to get the
			# projection image for the given projection number (`projNr`).
			# set_frame must have been called beforehand.
			if { [::ctsimu::aRTist_available] } {
				set Scale [vtkImageShiftScale New]
				if {[my get output_datatype] == "float32"} {
					$Scale SetOutputScalarTypeToFloat
					$Scale ClampOverflowOff
				} else {
					$Scale SetOutputScalarTypeToUnsignedInt
					$Scale ClampOverflowOn
				}

				update

				set imglist [::Engine::Go]
				::Image::Show $imglist
				lassign $imglist img

				$Scale SetInput [$img GetImage]

				#aRTist::SignalProgress
				update

				foreach img $imglist { $img Delete }
				if { [info exists Scale] } { $Scale Delete }

				::xrEngine ClearOutput
				::xrEngine ClearObjects
			}
		}

		method save_projection_image { projNr fileNameSuffix} {
			# Save the currently simulated projection image.
			set projectionFolder [my get run_projection_folder]
			set outputBaseName [my get run_output_basename]

			if { [::ctsimu::aRTist_available] } {
				set Scale [vtkImageShiftScale New]
				if {[my get output_datatype] == "float32"} {
					$Scale SetOutputScalarTypeToFloat
					$Scale ClampOverflowOff
				} else {
					$Scale SetOutputScalarTypeToUnsignedInt
					$Scale ClampOverflowOn
				}

				update
				if {[my is_running] == 0} {return}

				set imglist [::Engine::Go]
				::Image::Show $imglist
				lassign $imglist img

				$Scale SetInput [$img GetImage]

				# Write TIFF or RAW:
				set currFile "$projectionFolder/$outputBaseName"
				append currFile "_$fileNameSuffix"
				if {[my get output_fileformat] == "raw"} {
					append currFile ".raw"
				} else {
					append currFile ".tif"
				}

				set tmp [Image::aRTistImage %AUTO%]
				if { [catch {
					$Scale Update
					$tmp ShallowCopy [$Scale GetOutput]
					$tmp SetMetaData [$img GetMetaData]
					if {[my get output_datatype] == "float32"} {
						set convtmp [::Image::ConvertToFloat $tmp]
					} else {
						set convtmp [::Image::ConvertTo16bit $tmp]
					}

					if {[my get output_fileformat] == "raw"} {
						::Image::SaveRawFile $convtmp $currFile true . "" 0.0
					} else {
						::Image::SaveTIFF $convtmp $currFile true . NoCompression
					}

					$tmp Delete
					$convtmp Delete
				} err errdict] } {
					Utils::nohup { $tmp Delete }
					return -options $errdict $err
				}

				#aRTist::SignalProgress
				update

				foreach img $imglist { $img Delete }
				if { [info exists Scale] } { $Scale Delete }

				::xrEngine ClearOutput
				::xrEngine ClearObjects
			}
		}

		method generate_flats_and_darks { } {
			# Generate flat field and dark field images (if required by the scenario).
			if { [::ctsimu::aRTist_available] } {
				SceneView::SetInteractive 1
				set imglist {}

				if { [my get n_darks] > 0 } {
					if {[my is_running] == 0} {return}
					::ctsimu::status_info "Taking ideal dark field..."

					# Take dark field image(s):
					set savedXrayCurrent   $::Xsource(Exposure)
					set savedNoiseFactorOn $::Xdetector(NoiseFactorOn)
					set savedNoiseFactor   $::Xdetector(NoiseFactor)
					set savedNFrames       $::Xdetector(NrOfFrames)
					set savedScatter       $::Xscattering(Mode)

					set savedUnsharpness   $::Xdetector(Unsharpness)
					set savedLRRatio       $::Xdetector(LRRatio)
					set savedLRUnsharpness $::Xdetector(LRUnsharpness)

					# Take ideal dark image at 0 current and 0 noise:
					set ::Xsource(Exposure) 0
					set ::Xdetector(NoiseFactorOn) 1
					set ::Xdetector(NoiseFactor) 0
					set ::Xdetector(NrOfFrames) 1
					set ::Xscattering(Mode) off

					set ::Xdetector(Unsharpness) 0
					set ::Xdetector(LRRatio) 0
					set ::Xdetector(LRUnsharpness) 0
					set ::Xdetector(UnsharpnessOn) 1
					::XDetector::UnsharpnessOverrideSet

					my save_projection_image 0 "dark"

					set ::Xsource(Exposure) $savedXrayCurrent
					set ::Xdetector(NoiseFactorOn) $savedNoiseFactorOn
					set ::Xdetector(NoiseFactor) $savedNoiseFactor
					set ::Xdetector(NrOfFrames) $savedNFrames
					set ::Xscattering(Mode) $savedScatter

					set ::Xdetector(Unsharpness) $savedUnsharpness
					set ::Xdetector(LRRatio) $savedLRRatio
					set ::Xdetector(LRUnsharpness) $savedLRUnsharpness
					set ::Xdetector(UnsharpnessOn) 0
					::XDetector::UnsharpnessOverrideSet
				}

				if { [my get n_flats] } {
					if {[my is_running] == 0} {return}
					::ctsimu::status_info "Taking flat field..."

					::PartList::SelectAll
					::PartList::SetVisibility 0
					::PartList::UnselectAll

					if { [my get flat_field_ideal] == 1 } {
						set savedNoiseFactorOn $::Xdetector(NoiseFactorOn)
						set savedNoiseFactor   $::Xdetector(NoiseFactor)
						set savedNFrames       $::Xdetector(NrOfFrames)

						# Take ideal flat image at 0 noise:
						set ::Xdetector(NoiseFactorOn) 1
						set ::Xdetector(NoiseFactor) 0
						set ::Xdetector(NrOfFrames) 1

						if {[my get n_flats] > 1} {
							# Save all frames as individual images
							set projCtrFmt [::ctsimu::generate_projection_counter_format [my get n_flats]]
							for {set flatImgNr 0} {$flatImgNr < [my get n_flats]} {incr flatImgNr} {
								set fnr [expr $flatImgNr+1]
								::ctsimu::status_info "Taking flat field $fnr/[my get n_flats]..."
								set flatFileNameSuffix "flat_[format $projCtrFmt $flatImgNr]"
								my save_projection_image 0 $flatFileNameSuffix

								if {[my is_running] == 0} {break}
							}
						} elseif {[my get n_flats] == 1} {
							::ctsimu::status_info "Taking flat field..."
							my save_projection_image 0 "flat"
						} else {
							my stop_scan
							::PartList::SelectAll
							::PartList::SetVisibility 1
							::PartList::UnselectAll
							::ctsimu::fail "Invalid number of flat field images."
						}

						set ::Xdetector(NoiseFactorOn) $savedNoiseFactorOn
						set ::Xdetector(NoiseFactor) $savedNoiseFactor
						set ::Xdetector(NrOfFrames) $savedNFrames
					} else {
						if {[my get n_flats_avg] > 0} {
							# Flat field frame averaging
							set savedNFrames $::Xdetector(NrOfFrames)
							set ::Xdetector(NrOfFrames) [my get n_flats_avg]

							if {[my get n_flats] > 1} {
								# Save all frames as individual images
								set projCtrFmt [::ctsimu::generate_projection_counter_format [my get n_flats]]
								for {set flatImgNr 0} {$flatImgNr < [my get n_flats]} {incr flatImgNr} {
									set fnr [expr $flatImgNr+1]
									::ctsimu::status_info "Taking flat field $fnr/[my get n_flats]..."
									set flatFileNameSuffix "flat_[format $projCtrFmt $flatImgNr]"
									my save_projection_image 0 $flatFileNameSuffix

									if {[my is_running] == 0} {break}
								}
							} elseif {[my get n_flats] == 1} {
								::ctsimu::status_info "Taking flat field..."
								my save_projection_image 0 "flat"
							} else {
								my stop_scan
								::PartList::SelectAll
								::PartList::SetVisibility 1
								::PartList::UnselectAll
								::ctsimu::fail "Invalid number of flat field images."
							}

							set ::Xdetector(NrOfFrames) $savedNFrames
						} else {
							my stop_scan
							::PartList::SelectAll
							::PartList::SetVisibility 1
							::PartList::UnselectAll
							::ctsimu::fail "Number of flat field averages must be greater than 0."
						}
					}

					::PartList::SelectAll
					::PartList::SetVisibility 1
					::PartList::UnselectAll
				}
			}
		}

		method create_flat_field_correction_script { } {
			# Create a flat field correction script for Python,
			# using the CTSimU Toolbox.
			set ff_filename [my get run_projection_folder]
			append ff_filename "/"
			append ff_filename [my get output_basename]
			append ff_filename "_flat.py"

			set ff_content "from ctsimu.toolbox import Toolbox\n"
			append ff_content "Toolbox(\"correction\", \""
			append ff_content [my get output_basename]
			append ff_content "_metadata.json"
			append ff_content "\", rescaleFactor="
			append ff_content [ $_detector get ff_rescale_factor]
			append ff_content ")"

			fileutil::writeFile -encoding utf-8 $ff_filename $ff_content
		}

		method create_metadata_file { } {
			# Create a metadata JSON file for the simulation.
			set metadata {
				{
					"file":
					{
						"name": "",
						"description": "",

						"contact": "",
						"date_created": "",
						"date_changed": "",
						"version": {"major": 1, "minor": 0}
					},

					"output":
					{
						"system": "",
						"date_measured": "",
						"projections":
						{
							"filename":   "",
							"datatype":   "",
							"byteorder":  "little",
							"headersize": null,

							"number": 1,
							"dimensions": {
								"x": {"value": 1000, "unit": "px"},
								"y": {"value": 1000, "unit": "px"}
							},
							"pixelsize": {
								"x": {"value": 0.1, "unit": "mm"},
								"y": {"value": 0.1, "unit": "mm"}
							},
							"dark_field": {
								"number": 0,
								"frame_average": null,
								"filename": null,
								"projections_corrected": false
							},
							"flat_field": {
								"number": 0,
								"frame_average": null,
								"filename": null,
								"projections_corrected": false
							}
						},
						"tomogram": null,
						"reconstruction": null,
						"acquisitionGeometry":
						{
							"path_to_CTSimU_JSON": ""
						}
					}
				}
			}

			set systemTime [clock seconds]
			set today [clock format $systemTime -format %Y-%m-%d]

			set aRTistVersion "unknown"
			set modulename "CTSimU"
			set moduleversion "unknown"

			if {[::ctsimu::aRTist_available]} {
				set aRTistVersion [::aRTist::GetVersion]
				set moduleInfo [${::ctsimu::ctsimu_module_namespace}::Info]
				set modulename [dict get $moduleInfo Description]
				set moduleversion [dict get $moduleInfo Version]
			}

			set fileExtension ".tif"
			set headerSizeValid 0
			if {[my get output_fileformat] == "raw"} {
				set fileExtension ".raw"
				set headerSizeValid 1
			}
			set projFilename [my get run_output_basename]
			append projFilename "_"
			append projFilename [my get projection_counter_format]
			append projFilename $fileExtension


			# Fill template:
			::rl_json::json set metadata file name [::rl_json::json new string [my get run_output_basename]]

			set systemTime [clock seconds]
			set today [clock format $systemTime -format %Y-%m-%d]
			::rl_json::json set metadata file date_created [::rl_json::json new string $today]
			::rl_json::json set metadata file date_changed [::rl_json::json new string $today]

			::rl_json::json set metadata output system [::rl_json::json new string "aRTist $aRTistVersion, $modulename $moduleversion"]
			::rl_json::json set metadata output date_measured [::rl_json::json new string $today]
			::rl_json::json set metadata output projections filename [::rl_json::json new string $projFilename]
			::rl_json::json set metadata output projections datatype [::rl_json::json new string [my get output_datatype]]

			if {$headerSizeValid==1} {
				::rl_json::json set metadata output projections headersize {{"file": 0, "image": 0}}
			}

			# Projection number and size:
			::rl_json::json set metadata output projections number [::rl_json::json new number [my get n_projections]]
			::rl_json::json set metadata output projections dimensions x value [::rl_json::json new number [$_detector get columns]]
			::rl_json::json set metadata output projections dimensions y value [::rl_json::json new number [$_detector get rows]]
			::rl_json::json set metadata output projections pixelsize x value [::rl_json::json new number [$_detector get pitch_u]]
			::rl_json::json set metadata output projections pixelsize y value [::rl_json::json new number [$_detector get pitch_v]]

			# Dark field:
			if {[my get n_darks] > 0} {
				::rl_json::json set metadata output projections dark_field number [::rl_json::json new number [my get n_darks]]
				::rl_json::json set metadata output projections dark_field frame_average [::rl_json::json new number [my get n_darks_avg]]

				set dark_filename_pattern [my get run_output_basename]
				append dark_filename_pattern "_dark"

				if { [my get n_darks] == 1 } {
					append dark_filename_pattern $fileExtension
					::rl_json::json set metadata output projections dark_field filename [::rl_json::json new string $dark_filename_pattern]
				} else {
					append dark_filename_pattern "_"
					append dark_filename_pattern [::ctsimu::generate_projection_counter_format [my get n_darks]]; # something like %04d
					append dark_filename_pattern $fileExtension

					::rl_json::json set metadata output projections dark_field filename [::rl_json::json new string $dark_filename_pattern]
				}
			}

			# Flat field:
			if {[my get n_flats] > 0} {
				::rl_json::json set metadata output projections flat_field number [::rl_json::json new number [my get n_flats]]
				::rl_json::json set metadata output projections flat_field frame_average [::rl_json::json new number [my get n_flats_avg]]

				set flat_filename_pattern [my get run_output_basename]
				append flat_filename_pattern "_flat"

				if { [my get n_flats] == 1 } {
					append flat_filename_pattern $fileExtension
					::rl_json::json set metadata output projections flat_field filename [::rl_json::json new string $flat_filename_pattern]
				} else {
					append flat_filename_pattern "_"
					append flat_filename_pattern [::ctsimu::generate_projection_counter_format [my get n_flats]]; # something like %04d
					append flat_filename_pattern $fileExtension

					::rl_json::json set metadata output projections flat_field filename [::rl_json::json new string $flat_filename_pattern]
				}
			}

			if { [my get ff_correction_on] } {
				::rl_json::json set metadata output projections flat_field projections_corrected [::rl_json::json new boolean 1]
			}

			# JSON filename:
			::rl_json::json set metadata output acquisitionGeometry path_to_CTSimU_JSON [::rl_json::json new string [my get json_file_name]]

			# Write metadata file:
			set metadataFilename "[my get run_projection_folder]/[my get run_output_basename]_metadata.json"
			fileutil::writeFile -encoding utf-8 $metadataFilename [::rl_json::json pretty $metadata]
		}

		method create_recon_configs { } {
			# Create config files for the individual reconstruction programs (if required by the scenario).
			set matrices_openCT {}
			set matrices_CERA {}
			set projection_filenames {}

			set outputBaseName [my get run_output_basename]
			set projCtrFmt [my get projection_counter_format]

			# Set to "running", so computation
			# of projection matrices can be cancelled.
			my _set_run_status 1

			my set_up_CERA_RDabcuv; # also necessary for openCT

			# Projection matrix for each projection:
			for {set p 0} {$p < [my get n_projections]} {incr p} {
				set pnr [expr $p+1]
				::ctsimu::status_info "Calculating projection matrix $pnr/[my get n_projections]..."

				my set_frame_for_recon $p

				# Calculate and store projection matrices:
				if { [my get create_openct_config_file] == 1} {
					set P_openCT [my projection_matrix 0 0 "openCT"]
					lappend matrices_openCT $P_openCT
				}

				if { [my get create_cera_config_file] == 1} {
					set P_CERA [my projection_matrix 0 0 "CERA"]
					lappend matrices_CERA $P_CERA
				}

				# Projection filename:
				set fileNameSuffix [format $projCtrFmt $p]
				set currFile "$outputBaseName"
				append currFile "_$fileNameSuffix"
				if {[my get output_fileformat] == "raw"} {
					append currFile ".raw"
				} else {
					append currFile ".tif"
				}
				lappend projection_filenames $currFile

				update
				if { [my is_running] == 0} {
					# Run has been stopped (by user?)
					return 0
				}
			}

			# Create recon config files:
			if { [my get create_openct_config_file] == 1} {
				my save_clFDK_script
				my save_openCT_config_file $projection_filenames $matrices_openCT
			}

			if { [my get create_cera_config_file] == 1} {
				my save_CERA_config_file $matrices_CERA
			}

			# Destroy matrix objects:
			foreach P $matrices_openCT {
				$P destroy
			}
			foreach P $matrices_CERA {
				$P destroy
			}

			my stop_scan 1
			return 1
		}

		method projection_matrix { { volumeCS 0 } { imageCS 0 } { mode 0 } } {
			# Calculate a projection matrix for the current geometry.
			#
			#
			# Parameters
			# ----------
			# volumeCS : ::ctsimu::coordinate_system
			#     Position of the reconstruction volume coordinate system in terms of the
			#     stage coordinate system. If `0` is given, the volume
			#     coordinate system is assumed to be the stage coordinate system.
			#     See notes for details.
			#
			# imageCS : ::ctsimu::coordinate_system
			#     Position of the image coordinate system in terms of the
			#     detector coordinate system. If `0` is given, the image
			#     coordinate system is assumed to be the detector coordinate system.
			#     See notes for details.
			#
			# mode : str
			#     Pre-defined modes. Either "openCT" or "CERA" are supported.
			#     They override the `volumeCS` and `imageCS`, which can be set
			#     to `0` when using one of the pre-defined modes.
			#
			# Returns
			# -------
			# P : Matrix
			#     Projection matrix.
			#
			# Notes
			# -----
			# The image coordinate system (`imageCS`) should match the location,
			# scale and orientation used by the reconstruction software and is
			# expressed in terms of the detector coordinate system.
			#
			# The detector coordinate system has its origin at the detector `center`,
			# the `u` unit vector points in the row vector direction, and the
			# `v` unit vector points in column vector direction (they are always
			# assumed to be unit vectors).
			#
			# The `center` (origin) of the `imageCS` should be where the reconstruction
			# software places the origin of its own projection image coordinate
			# system. For example, CERA places it at the center of the lower-left
			# pixel of the projection image.
			#
			# Similarly, a volume coordinate system (`volumeCS`) can be provided
			# that describes the location, scale and orientation of the reconstruction
			# volume with respect to the stage coordinate system.
			#
			# If the reconstruction software expects a different unit for the image
			# or volume coordinate system (e.g. mm or voxels) than the world
			# coordinates (e.g. mm), you can scale the basis vectors accordingly.
			# For example, if you need a pixel and voxel coordinate system instead
			# of a millimeter coordinate system, scale the basis vectors by the
			# respective pixel and voxel size:
			#
			# [$imageCS u] scale $pixelSize_u
			# [$imageCS v] scale $pixelSize_v
			# [$imageCS w] scale 1.0; # Do not scale the detector normal!
			#
			# [$volumeCS u] scale $voxelSize_u
			# [$volumeCS v] scale $voxelSize_v
			# [$volumeCS w] scale $voxelSize_w

			set valid_modes [list "openCT" "CERA"]

			if { $mode != 0 } {
				# Override image CS:
				set image [::ctsimu::coordinate_system new "Image"]
				$image reset

				# The 3D volume (reconstruction space).
				if { $volumeCS != 0 } {
					set volume [$volumeCS get_copy]

					# The given volume CS would be given in terms of the stage CS.
					# Transform to world CS:
					$volume change_reference_frame [$_stage current_coordinate_system] $::ctsimu::world
				} else {
					# The volume CS is the current stage CS:
					set volume [ [$_stage current_coordinate_system] get_copy]
				}

				if { $mode == "openCT" } {
					# openCT places the origin of the image CS at the detector
					# center. The constructor places it at (0,0,0) automatically,
					# so there is nothing to do. Comments for illustration.
					# [$image center] set_x 0
					# [$image center] set_y 0
					# [$image center] set_z 0

					# openCT's image CS is in mm units. We assume that all
					# other coordinate systems are in mm as well here (at least
					# when imported from JSON file). No scaling of the basis vectors is necessary.
					# [$image u] scale 1.0
					# [$image v] scale 1.0
					# [$image w] scale 1.0

					[$volume w] invert; # mirror volume
				} elseif { $mode == "CERA" } {
					# CERA places the origin of the image CS in the center
					# of the lower left pixel of the projection image.
					[$image center] set_x [expr -([$_detector physical_width] - [$_detector get pitch_u]) / 2.0]
					[$image center] set_y [expr  ([$_detector physical_height] - [$_detector get pitch_v]) / 2.0]

					# CERA's unit of the image CS is in px, so we need to
					# scale the image CS basis vectors by the pixel size.
					# Also, v points up instead of down.
					[$image u] scale [$_detector get pitch_u]
					[$image v] scale [expr -[$_detector get pitch_v]]

					[$volume w] invert; # mirror volume
				}
			} else {
				if { $imageCS != 0 } {
					set image [$imageCS get_copy]
				} else {
					# Set a standard coordinate system. Results in pure
					# detector coordinate system after transformation.
					set image [::ctsimu::coordinate_system new "Image"]
					$image reset
				}

				if { $volumeCS != 0 } {
					set volume [$volumeCS get_copy]
				} else {
					# Set a standard coordinate system. Results in pure
					# detector coordinate system after transformation.
					set volume [::ctsimu::coordinate_system new "Volume"]
					$volume reset
				}
			}

			set source [ [$_source current_coordinate_system] get_copy]

			# The volume scale factors are derived from the lengths of
			# the basis vectors of the volume CS.
			set scale_volume_u [ [$volume u] length ]
			set scale_volume_v [ [$volume v] length ]
			set scale_volume_w [ [$volume w] length ]

			# Detach the image CS from the detector CS and
			# express it in terms of the world CS:
			$image change_reference_frame [$_detector current_coordinate_system] $::ctsimu::world

			# The image scale factors are derived from the lengths of
			# the basis vectors of the image CS.
			set scale_image_u [ [$image u] length ]
			set scale_image_v [ [$image v] length ]
			set scale_image_w [ [$image w] length ]

			# Save a source CS as seen from the detector CS. This is convenient to
			# later get the SDD, ufoc and vfoc:
			set source_from_image [ [$_source current_coordinate_system] get_copy]
			$source_from_image change_reference_frame $::ctsimu::world $image

			# Make the volume CS the new world CS:
			$source change_reference_frame $::ctsimu::world $volume
			$image  change_reference_frame $::ctsimu::world $volume
			$volume change_reference_frame $::ctsimu::world $volume

			# Translation vector from volume to source:
			set xfoc [[$source center] x]
			set yfoc [[$source center] y]
			set zfoc [[$source center] z]

			# Focus point on detector: principal, perpendicular ray.
			# In the detector coordinate system, ufoc and vfoc are the u and v coordinates
			# of the source center; SDD (perpendicular to detector plane) is source w coordinate.
			set ufoc [expr [ [$source_from_image center] x] / $scale_image_u]
			set vfoc [expr [ [$source_from_image center] y] / $scale_image_v]
			set SDD  [expr abs([ [$source_from_image center] z])]

			# Scale matrix: volume units -> world units
			set A [::ctsimu::matrix new 4 0]
			$A add_row [list $scale_volume_u 0 0 0]
			$A add_row [list 0 $scale_volume_v 0 0]
			$A add_row [list 0 0 $scale_volume_w 0]
			$A add_row [list 0 0 0 1]
			#puts "A:"
			#puts [$A print]

			# Move origin to source (the origin of the camera CS)
			set F [::ctsimu::matrix new 4 0]
			$F add_row [list 1 0 0 $xfoc]
			$F add_row [list 0 1 0 $yfoc]
			$F add_row [list 0 0 1 $zfoc]
			#puts "F:"
			#puts [$F print]

			# Rotations:
			set R [::ctsimu::basis_transform_matrix $volume $image]
			#puts "R:"
			#puts [$R print]

			# Projection onto detector and scaling (world units -> volume units):
			set S [::ctsimu::matrix new 3 0]
			$S add_row [list [expr -$SDD/$scale_image_u] 0 0]
			$S add_row [list 0 [expr -$SDD/$scale_image_v] 0]
			$S add_row [list 0 0 [expr -1.0/$scale_image_w]]
			#puts "S:"
			#puts [$S print]

			# Shift in detector CS: (ufoc and vfoc must be in scaled units)
			set T [::ctsimu::matrix new 3 0]
			$T add_row [list 1 0 $ufoc]
			$T add_row [list 0 1 $vfoc]
			$T add_row [list 0 0 1]
			#puts "T:"
			#puts [$T print]
			#puts "-----------"

			# Multiply matrices into projection matrix P:
			set FA   [$F multiply $A]
			set RFA  [$R multiply $FA]
			set SRFA [$S multiply $RFA]
			set P    [$T multiply $SRFA]

			$A destroy
			$F destroy
			$R destroy
			$S destroy
			$T destroy
			$FA destroy
			$RFA destroy
			$SRFA destroy

			$image destroy
			$volume destroy
			$source destroy
			$source_from_image destroy

			# Renormalize:
			set lower_right [$P element 3 2]
			if {$lower_right != 0} {
				$P scale [expr 1.0/$lower_right]
				$P set_element 3 2 1.0; # avoids rounding issues
			}

			#puts "P:"
			#puts [$P print]
			#puts "-----------"

			return $P
		}

		method set_up_CERA_RDabcuv { } {
			# Calculates all parameters for an ideal circular trajectory reconstruction
			# in CERA without projection matrices. These are added to the reconstruction
			# config file for CERA, just in case the user does not wish to use
			# projection matrices.
			my set_frame_for_recon 0

			set csSource   [ [$_source   current_coordinate_system] get_copy]
			set csStage    [ [$_stage    current_coordinate_system] get_copy]
			set csDetector [ [$_detector current_coordinate_system] get_copy]

			set nu  [$_detector get columns]
			set nv  [$_detector get rows]
			set psu [$_detector get pitch_u]
			set psv [$_detector get pitch_v]

			set startAngle [my get start_angle]

			# CERA's detector CS has its origin in the lower left corner instead of the center.
			# Let's move there:
			set uD [ [$csDetector u] get_copy]
			set vD [ [$csDetector v] get_copy]
			set halfWidth  [expr $psu*$nu / 2.0]
			set halfHeight [expr $psv*$nv / 2.0]

			$uD scale $halfWidth
			$vD scale $halfHeight

			[$csDetector center] subtract $uD
			[$csDetector center] add $vD

			$uD destroy
			$vD destroy

			# The v axis points up instead of down:
			$csDetector rotate_around_u 3.141592653589793

			# Construct the CERA world coordinate system:
			# z axis points in v direction of our detector CS:
			set cera_z [ [$csDetector v] get_copy]
			set z0 [$cera_z x]
			set z1 [$cera_z y]
			set z2 [$cera_z z]

			set O0 [ [$csStage center] x]
			set O1 [ [$csStage center] y]
			set O2 [ [$csStage center] z]

			set S0 [ [$csSource center] x]
			set S1 [ [$csSource center] y]
			set S2 [ [$csSource center] z]

			set w0 [ [$csStage w] x]
			set w1 [ [$csStage w] y]
			set w2 [ [$csStage w] z]

			# x axis points from source to stage (inverted), and perpendicular to cera_z (det v):
			set t [expr -($z0*($O0-$S0) + $z1*($O1-$S1) + $z2*($O2-$S2))/($z0*$w0 + $z1*$w1 + $z2*$w2)]
			set d [ [$csSource center] distance [$csStage center] ]
			set SOD [expr sqrt($d*$d - $t*$t)]

			if {$SOD > 0} {
				set x0 [expr -($O0 - $S0 + $t*$w0)/$SOD]
				set x1 [expr -($O1 - $S1 + $t*$w1)/$SOD]
				set x2 [expr -($O2 - $S2 + $t*$w2)/$SOD]
			} else {
				set x0 -1
				set x1 0
				set x2 0
			}

			set cera_x [::ctsimu::vector new [list $x0 $x1 $x2]]
			$cera_x to_unit_vector

			set csCERA [::ctsimu::coordinate_system new "CERA"]
			$csCERA set_center [ [$csSource center] get_copy ]
			$csCERA set_u_w [$cera_x get_copy] [$cera_z get_copy]
			$csCERA attach_to_stage 0

			$cera_x destroy
			$cera_z destroy

			set stageInCERA [$csStage get_copy]
			set detectorInCERA [$csDetector get_copy]
			set sourceInCERA [$csSource get_copy]

			$stageInCERA    change_reference_frame $::ctsimu::world $csCERA
			$detectorInCERA change_reference_frame $::ctsimu::world $csCERA
			$sourceInCERA   change_reference_frame $::ctsimu::world $csCERA

			# Source:
			set xS [ [$sourceInCERA center] x]
			set yS [ [$sourceInCERA center] y]
			set zS [ [$sourceInCERA center] z]

			# Stage:
			set xO [ [$stageInCERA center] x]
			set yO [ [$stageInCERA center] y]
			set zO [ [$stageInCERA center] z]
			set uO [ [$stageInCERA u] get_unit_vector]
			set vO [ [$stageInCERA v] get_unit_vector]
			set wO [ [$stageInCERA w] get_unit_vector]

			# Detector:
			set xD [ [$detectorInCERA center] x]
			set yD [ [$detectorInCERA center] y]
			set zD [ [$detectorInCERA center] z]
			set uD [ [$detectorInCERA u] get_unit_vector]
			set vD [ [$detectorInCERA v] get_unit_vector]
			set wD [ [$detectorInCERA w] get_unit_vector]
			# Detector normal:
			set nx [$wD x]
			set ny [$wD y]
			set nz [$wD z]

			# Intersection of CERA's x axis with the stage rotation axis = ceraVolumeMidpoint (new center of stage)
			set xaxis [::ctsimu::vector new [list $SOD 0 0]]
			set ceraVolumeMidpoint [ [$sourceInCERA center] get_copy]
			$ceraVolumeMidpoint subtract $xaxis
			$xaxis to_unit_vector

			set worldVolumeMidpoint [::ctsimu::change_reference_frame_of_point $ceraVolumeMidpoint $csCERA $::ctsimu::world ]

			set ceraVolumeRelativeMidpoint [$ceraVolumeMidpoint to [$stageInCERA center] ]
			set midpointX [$ceraVolumeRelativeMidpoint x]
			set midpointY [$ceraVolumeRelativeMidpoint y]
			set midpointZ [$ceraVolumeRelativeMidpoint z]

			set c [$uD x];   # x component of detector u vector is c-tilt
			set a [$wO x];   # x component of stage w vector is a-tilt
			set b [$wO y];   # y component of stage w vector is b-tilt

			# Intersection of x axis with detector (in px):
			set efoc_x [$xaxis x]; # 1
			set efoc_y [$xaxis y]; # 0
			set efoc_z [$xaxis z]; # 0

			set E [expr $nx*$xD + $ny*$yD + $nz*$zD]
			set dv [expr ($nx*$efoc_x + $ny*$efoc_y + $nz*$efoc_z)]
			if {$dv > 0} {
				set SDDcera [expr ($E - $xS*$nx - $yS*$ny - $zS*$nz)/$dv]
			} else {
				set SDDcera 1
			}
			set SDDcera [expr abs($SDDcera)]
			set SODcera [ [$sourceInCERA center] distance $ceraVolumeMidpoint]

			set SOD $SODcera
			set SDD $SDDcera
			if {$SDD != 0} {
				set voxelsizeU [expr {$psu * $SOD / $SDD}]
				set voxelsizeV [expr {$psv * $SOD / $SDD}]
			} else {
				set voxelsizeU 1
				set voxelsizeV 1
			}

			set detectorIntersectionPoint [$xaxis get_copy]
			$detectorIntersectionPoint scale [expr -$SDDcera]
			set stageOnDetector [ [$detectorInCERA center] to $detectorIntersectionPoint]

			set ufoc [$stageOnDetector dot $uD]
			set vfoc [$stageOnDetector dot $vD]
			set wfoc [$stageOnDetector dot $wD]

			if {$psu > 0} {
				set ufoc_px [expr $ufoc/$psu]
			}

			if {$psv > 0} {
				set vfoc_px [expr $vfoc/$psv]
			}

			set offu [expr $ufoc_px - 0.5]
			set offv [expr $vfoc_px - 0.5]

			set cera_x [::ctsimu::vector new [list 1 0 0] ]
			set cera_y [::ctsimu::vector new [list 0 1 0] ]

			$cera_x scale [$vO dot $cera_x]
			$cera_y scale [$vO dot $cera_y]

			set vInXYplane [$cera_x get_copy]
			$vInXYplane add $cera_y
			set rot [$vInXYplane angle $cera_y]

			# Add this start angle to the user-defined start angle:
			set startAngle [expr $startAngle + [expr 180 - $rot*180.0/3.1415926535897932384626433832795028841971]]

			my set cera_R $SOD
			my set cera_D $SDD
			my set cera_ODD [expr $SDD-$SOD]
			my set cera_a $a
			my set cera_b $b
			my set cera_c $c
			my set cera_u0 $offu
			my set cera_v0 $offv
			my set cera_startAngle $startAngle
			my set cera_volumeMidpointX $midpointX
			my set cera_volumeMidpointY $midpointY
			my set cera_volumeMidpointZ $midpointZ
			my set cera_voxelSizeU $voxelsizeU
			my set cera_voxelSizeV $voxelsizeV

			$csSource destroy
			$csStage destroy
			$csDetector destroy
			$csCERA destroy
			$stageInCERA destroy
			$detectorInCERA destroy
			$sourceInCERA destroy
			$uO destroy
			$vO destroy
			$wO destroy
			$uD destroy
			$vD destroy
			$wD destroy
			$xaxis destroy
			$ceraVolumeMidpoint destroy
			$worldVolumeMidpoint destroy
			$ceraVolumeRelativeMidpoint destroy
			$cera_x destroy
			$cera_y destroy
			$detectorIntersectionPoint destroy
			$stageOnDetector destroy
			$vInXYplane destroy
		}

		method save_clFDK_script { } {
			# Creates a .bat file that allows to reconstruct the scan using clFDK.
			set reconFolder [my get run_recon_folder]
			set outputBaseName [my get run_output_basename]

			set batFilename "$reconFolder/$outputBaseName"
			append batFilename "_recon_clFDK.bat"

			set batFileContent "CHCP 65001\n"
			set batFileContent "clfdk $outputBaseName"
			append batFileContent "_recon_openCT.json $outputBaseName"
			append batFileContent "_recon_openCT iformat json"

			fileutil::writeFile -encoding utf-8 $batFilename $batFileContent
		}

		method save_openCT_config_file { projectionFilenames projectionMatrices } {
			# Creates a reconstruction configuration file in the openCT file format.
			set reconFolder [my get run_recon_folder]
			set outputBaseName [my get run_output_basename]

			set configFilename "$reconFolder/$outputBaseName"
			append configFilename "_recon_openCT.json"

			set reconVolumeFilename "$outputBaseName"
			append reconVolumeFilename "_recon_openCT.img"

			set openCTvgifile "$reconFolder/${outputBaseName}_recon_openCT.vgi"
			set openCTvginame "${outputBaseName}_recon_openCT"

			# match voxel size with CERA
			set vsu [my get cera_voxelSizeU]
			set vsv [my get cera_voxelSizeV]
			my save_VGI $openCTvginame $openCTvgifile $reconVolumeFilename 0 $vsu $vsv

			set fileType "TIFF"
			if {[my get output_fileformat] == "raw"} {
				set fileType "RAW"
			}

			set dataType "UInt16"
			if {[my get output_datatype] == "32bit"} {
				set dataType "Float32"
			}

			set nProjections [llength $projectionFilenames]

			set startAngle [my get start_angle]
			set stopAngle  [my get stop_angle]
			set totalAngle [expr $stopAngle - $startAngle]

			set geomjson {
				{
					"version": {"major":1, "minor":0},
					"openCTJSON":     {
					    "versionMajor": 1,
					    "versionMinor": 0,
					    "revisionNumber": 0,
					    "variant": "FreeTrajectoryCBCTScan"
					},
					"units": {
					    "length": "Millimeter"
					},
					"volumeName": "",
					"projections": {
						"numProjections": 0,
						"intensityDomain": true,
						"images": {
							"directory": "",
							"dataType": "",
							"fileType": "",
							"files": []},
						"matrices": []
						},
					"geometry": {
						"totalAngle": null,
						"skipAngle": 0,
						"detectorPixel": [],
						"detectorSize": [],
						"mirrorDetectorAxis": "",
						"distanceSourceObject": null,
						"distanceObjectDetector": null,
						"objectBoundingBox": []
						},
					 "corrections":{
						"brightImages":{
						  "directory": "",
						  "dataType":"",
						  "fileType":"",
						  "files":[]
						},

						"darkImage":{
						  "file":"",
						  "dataType":"",
						  "fileType":""
						},

						"badPixelMask":{
						  "file":"",
						  "dataType":"",
						  "fileType":""
						},

						"intensities":[]
					  }
				}
			}

			::rl_json::json set geomjson volumeName [::rl_json::json new string $reconVolumeFilename]
			::rl_json::json set geomjson projections numProjections $nProjections

			::rl_json::json set geomjson projections images directory [::rl_json::json new string "."]
			::rl_json::json set geomjson projections images fileType [::rl_json::json new string $fileType]
			::rl_json::json set geomjson projections images dataType [::rl_json::json new string $dataType]

			foreach projectionFile $projectionFilenames {
				::rl_json::json set geomjson projections images files end+1 [::rl_json::json new string "[my get dots_to_root]/[my get ff_projection_short_path]/$projectionFile"]
			}

			foreach P $projectionMatrices {
				::rl_json::json set geomjson projections matrices end+1 [$P format_json]
			}

			foreach projectionFile $projectionFilenames {
				::rl_json::json set geomjson corrections intensities end+1 [::rl_json::json new number [$_detector get gv_max]]
			}

			::rl_json::json set geomjson geometry totalAngle $totalAngle

			::rl_json::json set geomjson geometry detectorSize end+1 [$_detector physical_width]
			::rl_json::json set geomjson geometry detectorSize end+1 [$_detector physical_height]

			::rl_json::json set geomjson geometry detectorPixel end+1 [$_detector get columns]
			::rl_json::json set geomjson geometry detectorPixel end+1 [$_detector get rows]

			set bbSizeXY [expr [$_detector get columns] * $vsu]
			set bbSizeZ  [expr [$_detector get rows] * $vsv]

			# Scale the unit cube to match the bounding box:
			set S [::ctsimu::matrix new 4 4]
			$S set_row 0 [list $bbSizeXY 0 0 0]
			$S set_row 1 [list 0 $bbSizeXY 0 0]
			$S set_row 2 [list 0 0 $bbSizeZ  0]
			$S set_row 3 [list 0 0 0 1]
			# Rotate the bounding box to the stage CS:
			set R [::ctsimu::basis_transform_matrix $::ctsimu::world [$_stage current_coordinate_system] 1]

			set RS [$R multiply $S]
			::rl_json::json set geomjson geometry objectBoundingBox [$RS format_json]

			::rl_json::json set geomjson geometry distanceSourceObject [my get cera_R]
			::rl_json::json set geomjson geometry distanceObjectDetector [my get cera_ODD]

			fileutil::writeFile -encoding utf-8 $configFilename [::rl_json::json pretty $geomjson]
		}

		method save_VGI { name filename volumeFilename zMirror voxelsizeU voxelsizeV } {
			# Prepares a VGI file for the reconstruction volume such that it can be loaded with VGSTUDIO.
			set vgiTemplate {\{volume1\}
[representation]
size = $nSizeX $nSizeY $nSizeZ
datatype = $ceradataTypeOutput
datarange = $datarangelow $datarangeupper
bitsperelement = $bits
[file1]
SkipHeader = 0
FileFormat = raw
Size = $nSizeX $nSizeY $nSizeZ
Name = $volumeFilename
Datatype = $ceradataTypeOutput
datarange = $datarangelow $datarangeupper
BitsPerElement = $bits
\{volumeprimitive12\}
[geometry]
resolution = $voxelsizeU $voxelsizeU $voxelsizeV
unit = mm
[volume]
volume = volume1
[description]
text = $name}
			if { [my get cera_output_datatype] == "uint16" } {
				set ceradataTypeOutput "unsigned integer"
				set bits "16"
				set datarangelow "0"
				set datarangeupper "-1"
			} else {
				set ceradataTypeOutput "float"
				set bits "32"
				set datarangelow "-1"
				set datarangeupper "1"
			}

			set nu [$_detector get columns]
			set nv [$_detector get rows]
			set psu [$_detector get pitch_u]
			set psv [$_detector get pitch_v]

			set nSizeX $nu
			set nSizeY $nu
			set nSizeZ $nv

			set roiEndX [expr $nSizeX-1]
			set roiEndY [expr $nSizeY-1]
			set roiEndZ [expr $nSizeZ-1]

			fileutil::writeFile $filename [subst -nocommands $vgiTemplate]
		}

		method save_CERA_config_file { projectionMatrices } {
			# Create a reconstruction config file for SIEMENS CERA.
			set reconFolder [my get run_recon_folder]
			set outputBaseName [my get run_output_basename]
			set ffProjShortPath [my get ff_projection_short_path]
			set dotsToRoot [my get dots_to_root]

			set projTableFilename $outputBaseName
			append projTableFilename "_recon_cera_projtable.txt"

			set configFilename $outputBaseName
			append configFilename "_recon_cera.config"

			set nProjections [llength $projectionMatrices]
			set configtemplate {#CERACONFIG

[Projections]
NumChannelsPerRow = $nu
NumRows = $nv
PixelSizeU = $psu
PixelSizeV = $psv
Rotation = None
FlipU = false
FlipV = true
Padding = 0
BigEndian = false
CropBorderRight = 0
CropBorderLeft = 0
CropBorderTop = 0
CropBorderBottom = 0
BinningFactor = None
SkipProjectionInterval = 1
ProjectionDataDomain = Intensity
RawHeaderSize = 0

[Volume]
SizeX = $nSizeX
SizeY = $nSizeY
SizeZ = $nSizeZ
# Midpoints are only necessary for reconstructions
# without projection matrices.
MidpointX = 0 # $midpointX
MidpointY = 0 # $midpointY
MidpointZ = 0 # $midpointZ
VoxelSizeX = $voxelsizeU
VoxelSizeY = $voxelsizeU
VoxelSizeZ = $voxelsizeV
# Datatype = $ceraOutputDataType
OutputDatatype = $ceraOutputDataType

[CustomKeys]
NumProjections = $N
ProjectionFileType = $ftype
VolumeOutputPath = $CERAoutfile
ProjectionStartNum = 0
ProjectionFilenameMask = $dotsToRoot/$ffProjShortPath/$CERAfnmask

[CustomKeys.ProjectionMatrices]
SourceObjectDistance = $SOD
SourceImageDistance = $SDD
DetectorOffsetU = $offu
DetectorOffsetV = $offv
StartAngle = $startAngle
ScanAngle = $totalAngle
AquisitionDirection = $scanDirection
a = $a
b = $b
c = $c
ProjectionMatrixFilename = $projectionMatrixFilename

[Backprojection]
ClearOutOfRegionVoxels = false
InterpolationMode = bilinear
FloatingPointPrecision = half
Enabled = true

[Filtering]
Enabled = true
Kernel = shepp

[I0Log]
Enabled = true
Epsilon = 1.0E-5
GlobalI0Value = $globalI0
}

			set nu  [$_detector get columns]
			set nv  [$_detector get rows]
			set psu [$_detector get pitch_u]
			set psv [$_detector get pitch_v]

			set globalI0 [$_detector get gv_max]

			# Flip scan direction:
			# we assume object scan direction, CERA assumes gantry scan direction.
			if { [my get scan_direction] == "CCW" } {
				set scanDirection "CW"
			} else {
				set scanDirection "CCW"
			}

			if { [my get cera_output_datatype] == "uint16" } {
				set ceraOutputDataType "uint16"
			} else {
				set ceraOutputDataType "float"
			}

			# Cropping doesn't work this way and might not even be necessary?
			# Going back to full volume for the moment...
			#set nSize [lmap x [vec3Div $size $voxelsize] {expr {int(ceil($x))}}]
			#lassign $nSize nSizeX nSizeY nSizeZ
			set nSizeX $nu
			set nSizeY $nu
			set nSizeZ $nv

			set N [my get n_projections]

			set projFilename "$outputBaseName"
			append projFilename "_"
			append projFilename [my get projection_counter_format]
			if {[my get output_fileformat] == "raw"} {
				if {[my get output_datatype] == "uint16"} {
					set ftype "raw_uint16"
				} else {
					set ftype "raw_float"
				}
				append projFilename ".raw"
			} else {
				set ftype "tiff"
				append projFilename ".tif"
			}

			set CERAoutfile "${outputBaseName}_recon_cera.raw"
			set CERAfnmask $projFilename

			set CERAvgifile "$reconFolder/${outputBaseName}_recon_cera.vgi"
			set CERAvginame "${outputBaseName}_recon_cera"
			set vsu [my get cera_voxelSizeU]
			set vsv [my get cera_voxelSizeV]
			my save_VGI $CERAvginame $CERAvgifile $CERAoutfile 0 $vsu $vsv

			set SOD  [my get cera_R]
			set SDD  [my get cera_D]
			set a    [my get cera_a]
			set b    [my get cera_b]
			set c    [my get cera_c]
			set offu [my get cera_u0]
			set offv [my get cera_v0]
			set midpointX  [my get cera_volumeMidpointX]
			set midpointY  [my get cera_volumeMidpointY]
			set midpointZ  [my get cera_volumeMidpointZ]
			set voxelsizeU [my get cera_voxelSizeU]
			set voxelsizeV [my get cera_voxelSizeV]

			set startAngle [my get start_angle]
			set stopAngle  [my get stop_angle]
			set totalAngle [expr $stopAngle - $startAngle]

			# In CERA, we compensate in-matrix rotations by providing a different start angle:
			set startAngle [my get cera_startAngle]

			# Projection Matrices
			set projectionMatrixFilename $projTableFilename

			set configFilePath "$reconFolder/$configFilename"
			fileutil::writeFile $configFilePath [subst -nocommands $configtemplate]


			set projTablePath "$reconFolder/$projTableFilename"
			set projt [open $projTablePath w]
			puts $projt "projtable.txt version 3"
			#to be changed to date
			puts $projt "[clock format [clock scan now] -format "%a %b %d %H:%M:%S %Y"]\n"
			# or: is this a fixed date? "Wed Dec 07 09:58:01 2005\n"
			puts $projt "# format: angle / entries of projection matrices"
			puts $projt $nProjections

			set step 0
			foreach matrix $projectionMatrices {
				# concat all numbers into one
				set matrixCERA [$matrix format_CERA]

				# Cera expects @Stepnumber to start at 1
				set ceraStep [expr $step+1]

				puts $projt "\@$ceraStep\n0.0 0.0"
				puts $projt "$matrixCERA\n"
				incr step
			}

			close $projt
		}
	}
}