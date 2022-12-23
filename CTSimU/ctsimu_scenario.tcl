package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_samplemanager.tcl]

# A class to manage and set up a complete CTSimU scenario,
# includes e.g. all coordinate systems, etc.

namespace eval ::ctsimu {
	::oo::class create scenario {
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
			my _set_json_load_status      0

			my set json_file             ""; # full path + name of JSON file
			my set json_file_name        ""; # JSON filename without path
			my set json_file_directory   ""; # Path to JSON file
			my set start_angle            0
			my set stop_angle           360
			my set n_projections       2000
			my set frame_average          1
			my set projection_counter_format "%04d"
			my set proj_nr                0
			my set include_final_angle    0
			my set start_proj_nr          0
			my set scan_direction     "CCW"

			# Number of dark and flat field images:
			my set n_darks                0
			my set n_darks_avg            1
			my set n_flats                1
			my set n_flats_avg           20
			my set dark_field_ideal       1; # 1=yes, 0=no
			my set flat_field_ideal       0; # 1=yes, 0=no
			my set ff_correction_on       0; # run a flat field correction in aRTist?

			my set current_frame          0
			my set n_frames            2000; # frame_average * n_projections

			my set environment_material "void"

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
		}

		method set_next_frame { { apply_to_scene 0 } } {
			my set_frame [expr [my get current_frame]+1] $apply_to_scene
		}

		method set_previous_frame { { apply_to_scene 0 } } {
			my set_frame [expr [my get current_frame]-1] $apply_to_scene
		}

		method load_json_scene { json_filename { apply_to_scene 0 } } {
			::ctsimu::status_info "Reading JSON file..."

			my reset
			my set json_file $json_filename
			my set json_file_name [file tail "$json_filename"]
			my set json_file_directory [file dirname "$json_filename"]
			::ctsimu::set_json_path [my get json_file_directory]

			set jsonstring [::ctsimu::read_json_file $json_filename]

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
			my set start_angle [::ctsimu::get_value_in_unit "deg" $jsonstring {acquisition start_angle} 0]
			my set stop_angle [::ctsimu::get_value_in_unit "deg" $jsonstring {acquisition stop_angle} 360]

			my set n_projections [::ctsimu::get_value $jsonstring {acquisition number_of_projections} 1]
			my set frame_average [::ctsimu::get_value $jsonstring {acquisition frame_average} 1]

			my set include_final_angle [::ctsimu::get_value_in_unit "bool" $jsonstring {acquisition include_final_angle} 0]
			my set scan_direction [::ctsimu::get_value $jsonstring {acquisition direction} "CCW"]

			# Dark and flat field correction settings
			# ------------------------------------------

			my set n_darks [::ctsimu::get_value $jsonstring {acquisition dark_field number} 0]
			# aRTist can currently only take ideal dark field images.
			# Averaging=1 and ideal mode are therefore currently forced.
			#my set n_darks_avg [::ctsimu::get_value $jsonstring {acquisition dark_field frame_average} 1]
			# my set dark_field_ideal [::ctsimu::get_value_in_unit "bool" $jsonstring {acquisition dark_field ideal} 0]
			if { [my get n_darks] > 0 } {
				# In (currently forced) ideal mode, one dark image is enough.
				my set n_darks 1
			}

			my set n_flats [::ctsimu::get_value $jsonstring {acquisition flat_field number} 0]
			my set n_flats_avg [::ctsimu::get_value $jsonstring {acquisition flat_field frame_average} 1]
			my set flat_field_ideal [::ctsimu::get_value_in_unit "bool" $jsonstring {acquisition flat_field ideal} 0]


			my set ff_correction_on [::ctsimu::get_value_in_unit "bool" $jsonstring {acquisition flat_field correction} 0]

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
			
			# Detector
			# -------------
			::ctsimu::status_info "Reading detector source parameters..."
			$_detector set_from_json $jsonstring [$_stage current_coordinate_system]
			::ctsimu::info "Detector hash: [$_detector hash]"

			# Place objects in scene
			# ------------------------
			set stageCS [$_stage current_coordinate_system]

			$_source set_frame $stageCS [my get current_frame] [my get n_frames] 1
			set _initial_source_Xray_current [$_source get current]
			
			$_detector set_frame $stageCS [my get current_frame] [my get n_frames] 1
			
			my update
			set _initial_SDD $_SDD
			set _initial_SOD $_SOD
			set _initial_ODD $_ODD
			
			$_source initialize $_material_manager
			$_detector initialize $_material_manager $_initial_SDD $_initial_source_Xray_current
			
			if { $apply_to_scene == 1} {
				$_detector place_in_scene $stageCS
				$_source place_in_scene $stageCS
			}
			
			# Add the stage as a sample to the sample manager
			# so that it can be shown in the scene:
			if { [my get show_stage] } {
				# Calculate a scaling factor for the stage object,
				# such that is matches the detector height. The size
				# of the original stage STL is 52 mm in each direction.
				set stage_scaling_factor [expr [$_detector physical_height]/52.0 ]

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

			if { $apply_to_scene == 1} {
				$_sample_manager load_meshes $stageCS $_material_manager
			}
			
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
			
			::ctsimu::status_info "Scenario loaded."
			my _set_json_load_status 1
			return 1
		}

		method set_frame { frame { apply_to_scene 0 } } {
			my set current_frame $frame

			set stage_rotation_angle_in_rad [::ctsimu::in_rad [my get_current_stage_rotation_angle]]
			$_stage set_frame $::ctsimu::world $frame [my get n_frames] $stage_rotation_angle_in_rad

			set stageCS [$_stage current_coordinate_system]

			$_material_manager set_frame $frame [my get n_frames]
			$_sample_manager set_frame $stageCS $frame [my get n_frames]
			$_source set_frame $stageCS $frame [my get n_frames]
			$_detector set_frame $stageCS $frame [my get n_frames]
			
			if { $apply_to_scene } {
				$_sample_manager update_scene $stageCS
				$_detector place_in_scene $stageCS
				$_source place_in_scene $stageCS

				if { [::ctsimu::aRTist_available] } {
					# We have to ask the material manager for the
					# aRTist id of the environment material in each frame,
					# just in case it has changed from vacuum (void) to
					# a higher-density material:
					set ::Xsetup(SpaceMaterial) [ [$_material_manager get [my get environment_material]] aRTist_id ]

					$_source set_in_aRTist
					$_detector set_in_aRTist

					${::ctsimu::ctsimu_module_namespace}::setFrameNumber $frame
					Engine::RenderPreview
				}
			}

			#::ctsimu::status_info "Done setting frame $frame."
		}
		
		method update { } {
			# Calculate some geometry parameters (SDD, SOD, ODD)
			# for current frame.
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
			my _set_run_status 0
			if { $noMessage == 0 } {
				::ctsimu::status_info "Stopped."
			}
		}

		method start_scan { { run 1 } { nruns 1 } } {
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
			my prepare_postprocessing_configs $run $nruns
			
			my _set_run_status 1

			if { [my is_running] } {
				# Create flat field and dark field images.
				my generate_flats_and_darks
			}

			if { [my is_running] } {
				# Run actual scan.
				set nProjections [my get n_projections]
				set projCtrFmt [my get projection_counter_format]

				if {$nProjections > 0} {
					#aRTist::InitProgress
					#aRTist::ProgressQuantum $nProjections

					for {set projNr [my get start_proj_nr]} {$projNr < $nProjections} {incr projNr} {
						my set_frame $projNr 1

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

		method prepare_postprocessing_configs { { run 1 } { nruns 1 } } {
			# Flat field correction Python file, config files for
			# various reconstruction softwares.

			# Make projection folder and metadata file:
			file mkdir [my get run_projection_folder]
			file mkdir [my get run_recon_folder]

			# Create metadata file:
			::ctsimu::create_metadata_file [self] $run $nruns

			#my _set_run_status 1
		}

		method save_projection_image { projNr fileNameSuffix } {
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

				puts "Saving $currFile"
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
			if { [::ctsimu::aRTist_available] } {
				SceneView::SetInteractive 1
				set imglist {}

				if { [my get n_darks] > 0 } {
					if {[my is_running] == 0} {return}
					::ctsimu::status_info "Taking ideal dark field."

					# Take dark field image(s):
					set savedXrayCurrent   $::Xsource(Exposure)
					set savedNoiseFactorOn $::Xdetector(NoiseFactorOn)
					set savedNoiseFactor   $::Xdetector(NoiseFactor)
					set savedNFrames       $::Xdetector(NrOfFrames)
					set savedScatter       $::Xscattering(Mode)
					
					# Take ideal dark image at 0 current and 0 noise:
					set ::Xsource(Exposure) 0
					set ::Xdetector(NoiseFactorOn) 1
					set ::Xdetector(NoiseFactor) 0
					set ::Xdetector(NrOfFrames) 1
					set ::Xscattering(Mode) off
					
					my save_projection_image 0 "dark"

					set ::Xsource(Exposure) $savedXrayCurrent
					set ::Xdetector(NoiseFactorOn) $savedNoiseFactorOn
					set ::Xdetector(NoiseFactor) $savedNoiseFactor
					set ::Xdetector(NrOfFrames) $savedNFrames
					set ::Xscattering(Mode) $savedScatter
				}

				if { [my get n_flats] } {
					if {[my is_running] == 0} {return}
					::ctsimu::status_info "Taking flat field."

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
	}
}