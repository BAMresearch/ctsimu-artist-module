package require TclOO
package require fileutil
package require md5
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_sample.tcl]

# A class for the detector.

namespace eval ::ctsimu {
	::oo::class create detector {
		superclass ::ctsimu::part
		variable _filters_front
		variable _material_manager
		variable _previous_hash
		variable _initial_SDD; # initial SDD at frame 0
		variable _initial_current; # initial X-ray source current at frame 0

		constructor { { name "CTSimU_Detector" } { id "D" } } {
			next $name $id; # call constructor of parent class ::ctsimu::part
			set _filters_front [list ]
			set _previous_hash "0"

			my reset
		}

		destructor {
			foreach filter $_filters_front {
				$filter destroy				
			}
			set _filters_front [list ]
			next
		}
		
		method initialize { material_manager SDD current } {
			set _material_manager $material_manager
			set _initial_SDD $SDD
			set _initial_current $current
		}

		method reset { } {
			# Reset to standard settings.
			
			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part

			# Empty filter list:
			foreach filter $_filters_front {
				$filter destroy				
			}
			set _filters_front [list ]

			# Declare all detector parameters and their native units.
			# --------------------------------------------------------
			
			# General properties:
			my set model            "" "string"
			my set manufacturer     "" "string"
			my set type             "ideal" "string"
			my set columns          1000
			my set rows             1000
			my set pitch_u          0.1 "mm"
			my set pitch_v          0.1 "mm"
			my set bit_depth        16
			my set integration_time 1.0 "s"
			my set dead_time        0.0 "s"
			my set image_lag        0.0
			my set frame_average    1
			my set multisampling    "3x3" "string"

			my set min_energy       0
			my set max_energy       1000

			# Properties for gray value reproduction:
			my set gray_value_mode  "imin_imax" "string"
				# Valid gray value modes:
				# "imin_imax", "linear", "file"
			my set primary_energy_mode 0 "bool"
			my set imin             0
			my set imax             60000
			my set factor           1.0
			my set offset           0.0
			my set gv_characteristics_file "" "string"
			my set efficiency       1.0
			my set efficiency_characteristics_file "" "string"
			my set gv_max           60000; # max. achievable gray value, set by the generate function
			my set ff_rescale_factor 1.0; # for flat field correction script
			
			# Noise:
			my set noise_mode       "off" "string"
				# Valid noise modes:
				# "off", "snr_at_imax", "file"
			my set snr_at_imax      100
			my set noise_characteristics_file "" "string"
			
			# Unsharpness:
			my set unsharpness_mode "off" "string"
				# Valid unsharpness modes:
				# "off", "basic_spatial_resolution", "mtf10freq", "mtffile"
			my set basic_spatial_resolution 0.1 "mm"
			my set mtf10_freq       10.0 "lp/mm"
			my set mtf_file         "" "string"
			my set long_range_unsharpness 0 "mm"
			my set long_range_ratio 0
			
			# Bad pixel map
			my set bad_pixel_map      "" "string"
			my set bad_pixel_map_type "" "string"
			
			# Scintillator
			my set scintillator_material_id "" "string"
			my set scintillator_thickness   0.1 "mm"
		}

		method physical_width { } {
			return [ expr [my get pitch_u] * [my get columns] ]
		}

		method physical_height { } {
			return [ expr [my get pitch_v] * [my get rows] ]
		}

		method max_gray_value { } {
			# The maximum grey value that can be stored
			# using the image bit depth.
			return [expr pow(2, [my get bit_depth])-1]
		}
		
		method hash { } {
			# Returns a hash of all properties that are
			# relevant for the generation of the detector.
			
			# Create a unique string:
			set us "detector"
			append us "[my get type]"
			append us "[my get integration_time]"
			append us "[my get imin]"
			append us "[my get imax]"
			append us "[my get factor]"
			append us "[my get offset]"
			append us "[my get gv_characteristics_file]"
			append us "[my get efficiency]"
			append us "[my get efficiency_characteristics_file]"
			append us "[my get snr_at_imax]"
			append us "[my get noise_characteristics_file]"
			append us "[my get basic_spatial_resolution]"
			append us "[my get mtf10_freq]"
			append us "[my get mtf_file]"
			append us "[my get scintillator_thickness]"
			if { [my get scintillator_material_id] != "null" } {
				append us "[ [$_material_manager get [my get scintillator_material_id]] density ]"
				append us "[ [$_material_manager get [my get scintillator_material_id]] composition ]"
			}			
			
			foreach filter $_filters_front {
				append us "[ $filter thickness]"
				if { [$filter material_id] != "null" } {
					append us "[ [$_material_manager get [$filter material_id]] density ]"
					append us "[ [$_material_manager get [$filter material_id]] composition ]"
				}
			}
			
			return [md5::md5 -hex $us]
		}
		
		method current_temp_file { } {
			return [file join ${::TempFile::tempdir} "CTSimU_Detector_[my hash].aRTdet"]
		}

		method set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } } {
			# Update filter list:
			foreach filter $_filters_front {
				$filter set_frame $frame $nFrames				
			}

			# Call set_frame of parent class '::ctsimu::part':
			next $stageCS $frame $nFrames $w_rotation_in_rad
		}

		method set_from_json { jobj stage } {
			# Import the detector definition and geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file
			# (at least the geometry and detector sections).
			# `stage` is the `::ctsimu::coordinate_system` that represents
			# the stage in the world coordinate system. Necessary because
			# the source could be attached to the stage coordinate system.
			my reset

			set detectorGeometry [::ctsimu::json_extract $jobj {geometry detector}]
			my set_geometry $detectorGeometry $stage

			# Detector properties:
			set detprops [::ctsimu::json_extract $jobj {detector}]

			my set model        [::ctsimu::get_value $detprops {model} ""]
			my set manufacturer [::ctsimu::get_value $detprops {manufacturer} ""]

			if { ![my set_property type $detprops {type} "ideal"] } {
				::ctsimu::warning "Detector type not found or invalid. Should be \"ideal\" or \"real\". Using standard value: \"ideal\"."
			} else {
				# Check if the detector type is valid:
				set value [my get type]
				if { ![::ctsimu::is_valid $value {"ideal" "real"}] } {
					::ctsimu::warning "No valid detector type: $value. Should be \"ideal\" or \"real\". Using standard value: \"ideal\"."
					my set type "ideal"
				}
			}
			
			if { ![my set_from_key columns $detprops {columns} 100 ""] } {
				::ctsimu::warning "Number of detector columns not found or invalid. Using standard value."
			}

			if { ![my set_from_key rows $detprops {rows} 100 ""] } {
				::ctsimu::warning "Number of detector rows not found or invalid. Using standard value."
			}

			if { ![my set_from_key pitch_u   $detprops {pixel_pitch u} 0.1 "mm"] } {
				::ctsimu::warning "Pixel pitch in the u direction not found or invalid. Using standard value."
			}

			if { ![my set_from_key pitch_v   $detprops {pixel_pitch v} 0.1 "mm"] } {
				::ctsimu::warning "Pixel pitch in the v direction not found or invalid. Using standard value."
			}
			
			if { ![my set_from_key bit_depth $detprops {bit_depth} 16 ""] } {
				::ctsimu::warning "Detector bit depth not found or invalid. Using standard value."
			}

			if { ![my set_from_key integration_time $detprops {integration_time} 1 "s"] } {
				::ctsimu::warning "Detector integration time not found or invalid. Using standard value (1 s)."
			}

			my set_from_key dead_time $detprops {dead_time} 1 "s"
			my set_from_key image_lag $detprops {image_lag} 0.0
			
			my set_from_possible_keys imin $detprops {{grey_value imin} {gray_value imin}} "null"
			my set_from_possible_keys imax $detprops {{grey_value imax} {gray_value imax}} "null"
			my set_from_possible_keys factor $detprops {{grey_value factor} {gray_value factor}} "null"
			my set_from_possible_keys offset $detprops {{grey_value offset} {gray_value offset}} "null"
			my set_from_possible_keys gv_characteristics_file $detprops {{grey_value intensity_characteristics_file} {gray_value intensity_characteristics_file}} "null"

			# Decide on gray value mode:
			if { [my get gv_characteristics_file] != "null" } {
				my set gray_value_mode "file"
				::ctsimu::info "Gray value mode: [my get gray_value_mode] ([my get gv_characteristics_file])"
			} elseif { [my get factor] != "null" && [my get offset] != "null" } {
				my set gray_value_mode "linear"
				::ctsimu::info "Gray value mode: [my get gray_value_mode] (Factor: [my get factor], Offset: [my get offset])"
			} else {
				my set gray_value_mode "imin_imax"
				::ctsimu::info "Gray value mode: [my get gray_value_mode] (imin: [my get imin], imax: [my get imax])"
			}
			
			my set_from_possible_keys efficiency  $detprops {{grey_value efficiency} {gray_value efficiency}} "null"
			my set_from_possible_keys efficiency_characteristics_file $detprops {{grey_value efficiency_characteristics_file} {gray_value efficiency_characteristics_file}} "null"

			
			# Noise:
			my set_from_key snr_at_imax $detprops {noise snr_at_imax} "null"
			my set_from_key noise_characteristics_file $detprops {noise noise_characteristics_file} "null"

			# Decide on noise mode:
			if { [my get noise_characteristics_file] != "null" } {
				my set noise_mode "file"
				::ctsimu::info "Noise mode: [my get noise_mode] ([my get noise_characteristics_file])"
			} elseif { [my get snr_at_imax] != "null" } {
				my set noise_mode "snr_at_imax"
				::ctsimu::info "Noise mode: [my get noise_mode] ([my get snr_at_imax])"
			} else {
				my set noise_mode "off"
				::ctsimu::info "Noise mode: [my get noise_mode]"
			}
						
			# Unsharpness:
			my set unsharpness_mode "off" "string"
				# Valid unsharpness modes:
				# "off", "basic_spatial_resolution", "mtf10freq", "mtffile"

			my set_from_key basic_spatial_resolution $detprops {unsharpness basic_spatial_resolution} 0			
			my set_from_key mtf10_freq $detprops {unsharpness mtf10_frequency} 0
			my set_from_key mtf_file $detprops {unsharpness mtf} "null"
			
			# Decide on unsharpness mode:
			if { [my get mtf_file] != "null" } {
				my set unsharpness_mode "mtffile"
				::ctsimu::info "Unsharpness mode: [my get unsharpness_mode] ([my get mtf_file])"
			} elseif { [my get mtf10_freq] != 0 } {
				my set unsharpness_mode "mtf10freq"
				::ctsimu::info "Unsharpness mode: [my get unsharpness_mode] ([my get mtf10_freq])"
			} elseif { [my get basic_spatial_resolution] > 0 } {
				my set unsharpness_mode "basic_spatial_resolution"
				::ctsimu::info "Unsharpness mode: [my get unsharpness_mode] ([my get basic_spatial_resolution])"
			} else {
				my set unsharpness_mode "off"
				::ctsimu::info "Unsharpness mode: [my get unsharpness_mode]"
			}

			# Long range unsharpness is software-specific JSON parameter:
			my set_from_key long_range_unsharpness $jobj {simulation aRTist long_range_unsharpness extension} 0
			my set_from_key long_range_ratio $jobj {simulation aRTist long_range_unsharpness ratio} 0
			
			# Bad pixel map
			my set_from_key bad_pixel_map $detprops {bad_pixel_map} "null"
			my set_property bad_pixel_map_type $detprops {bad_pixel_map type} "null"
			
			# Scintillator
			my set_property scintillator_material_id $detprops {scintillator material_id} "null"
			my set_from_key scintillator_thickness $detprops {scintillator thickness} 0

			# Filters
			if { [::ctsimu::json_exists_and_not_null $detprops {filters front}] } {
				if { [::ctsimu::json_type $detprops {filters front}] == "array" } {
					set filters [::ctsimu::json_extract $detprops {filters front}]
					::rl_json::json foreach filter_json $filters {
						set new_filter [::ctsimu::filter new]
						$new_filter set_from_json $filter_json
					}
					lappend _filters_front $new_filter
				}
			}			

			# Frame averaging:
			my set_property frame_average $jobj {acquisition frame_average} 1

			# Multisampling (software-specific)
			my set_from_key multisampling $jobj {simulation aRTist multisampling_detector} "3x3"

			::ctsimu::info "Done reading detector parameters."


			# Primary energy mode
			my set_from_key primary_energy_mode $jobj {simulation aRTist primary_energies}

			# Primary energy mode needs different settings:
			if { [ my get primary_energy_mode ] == 1 } {
				::ctsimu::info "Primary energy mode."
				my set gray_value_mode "linear"
				my set imin 0
				my set imax 60000; # doesn't matter in factor/offset mode
				my set factor 1.0
				my set offset 0.0
				
				my set noise_mode "off"
				my set SNR 100
				my set noise_characteristics_file ""

				my set unsharpness_mode "off"
				my set basic_spatial_resolution 1.0
				my set mtf10_freq 10.0
				my set mtf_file ""

				my set integration_time 1
				my set bit_depth 32

				my set type "real"
			}
		}

		method set_in_aRTist { { apply_to_scene 0 } } {
			if { [::ctsimu::aRTist_available] } {
				# Set the detector to auto-size mode.
				# We set the number of pixels and the pixel size,
				# and aRTist should automatically calculate the
				# detector size:
				Preferences::Set Detector AutoVar Size
				set ::Xsetup_private(DGauto) Size
				::XDetector::SelectAutoQuantity
				
				# Generate the detector if it has changed:
				set current_hash [my hash]
				if { $current_hash != $_previous_hash } {
					# Check if a temp file already exists:
					set detector_temp_file [my current_temp_file]
					
					if { ![file exists $detector_temp_file] } {
						# Detector file does not exist.
						# We generate one...
						set aRTist_detector [my generate $_initial_SDD $_initial_current]
						XDetector::write_aRTdet $detector_temp_file $aRTist_detector
					}
					
					FileIO::OpenAnyGUI $detector_temp_file
				}

				# Number of pixels:
				set ::Xsetup(DetectorPixelX) [expr int([my get columns])]
				set ::Xsetup(DetectorPixelY) [expr int([my get rows])]

				# Pixel size:
				# Check if pixel size square lock needs to be lifted:
				if { [my get pitch_u] == [my get pitch_v] } {
					set ::Xsetup(SquarePixel) 1
				} else {
					set ::Xsetup(SquarePixel) 0
				}

				set ::Xsetup_private(DGdx) [my get pitch_u]
				set ::Xsetup_private(DGdy) [my get pitch_v]

				# Integration Time:
				set ::Xdetector(AutoD) off
				set ::Xdetector(Scale) [my get integration_time]

				# Frame Averaging
				# Set frame averaging to 1 for now:
				set ::Xdetector(NrOfFrames) [expr int([my get frame_average])]

				# Pixel multisampling:
				set ::Xsetup(DetectorSampling) [my get multisampling]

				::XDetector::UpdateGeometry %W
			}
		}
		
		# From detectorCalc module:
		# parse spectrum with n columns into flat list
		# ignore superfluous columns, comments & blank lines
		method ParseSpectrum { spectrumtext n } {
			set NR 0
			set result {}
			foreach line [split $spectrumtext \n] {

				incr NR
				if { [regexp {^\s*#(.*)$} $line full cmt] } {
					aRTist::Debug { $line }
					continue
				}

				aRTist::Trace { $line }

				# playing AWK
				set lline [regexp -inline -all -- {\S+} $line]
				set NF [llength $lline]
				if { $NF == 0 } { continue }

				for { set i 1 } { $i <= $NF } { incr i } { set $i [lindex $lline [expr {$i-1}]] }
				# now we have $1, $2, ...

				if { $NF < $n } { error "Corrupt data: Expected at least $n columns, parsing line $NR\n$NR: $line" }

				set clist {}
				for { set i 1 } { $i <= $n } { incr i } {
					set val [set $i]
					if { ![string is double -strict $val] } { error "Corrupt data: Expected number on line $NR:$i\n$NR: $line" }
					lappend clist $val
				}
				lappend result {*}$clist

			}

			return $result
		}

		# Adaption of DetectorCalc's Compute function:
		method generate { SDD xray_source_current } {
			# Generate a detector dictionary for aRTist.
			# Input parameters:
			# - SDD: source-detector distance
			# - xray_source_current: source current

			set pixelSizeX [my get pitch_u]
			set pixelSizeY [my get pitch_v]
			set pixelCountX [my get columns]
			set pixelCountY [my get rows]
			set SRb [my get basic_spatial_resolution]
			set integrationTime [my get integration_time]
			set nFrames 1; # CTSimU parameters always refer to 1 frame without averaging.

			# Create a detector dictionary:
			dict set detector Global Name [my name]
			dict set detector Global UnitIn {J/m^2}
			dict set detector Global UnitOut {grey values}
			dict set detector Global Pixelsize $pixelSizeX
			set pcount [string trim "$pixelCountX $pixelCountY"]
			if { $pcount != "" } { dict set detector Global PixelCount $pcount }

			if { [ my get primary_energy_mode ] == 1 } {
				dict set detector Global UnitOut {primary energy (J)}
				set ::Xdetector(AutoD) off
				set ::Xdetector(Scale) [my get integration_time]
				set ::Xdetector(NrOfFrames) 1; # no need for averaging
			}

			# Unsharpness:
			dict set detector Unsharpness Resolution [expr {2.0 * [my get basic_spatial_resolution]}]
			dict set detector Unsharpness LRUnsharpness [my get long_range_unsharpness]
			dict set detector Unsharpness LRRatio [my get long_range_ratio]

			# Load currently used X-ray spectrum:
			set spectrumtext [join [XSource::GetFullSpectrum] \n]

			# Apply environment material "filter" to input spectrum:
			if { ![string match -nocase VOID $::Xsetup(SpaceMaterial)] } {
				aRTist::Verbose { "Filtering input spectrum by environment material $::Xsetup(SpaceMaterial), SDD: $SDD" }
				Engine::UpdateMaterials $::Xsetup(SpaceMaterial)
				set spectrumtext [xrEngine FilterSpectrum $spectrumtext $::Xsetup(SpaceMaterial) [Engine::quotelist --Thickness [expr {$SDD / 10.0}]]]
			}

			set spectrum [my ParseSpectrum $spectrumtext 2]
			set sensitivitytext ""

			if {([my get type] == "real") && ([my get primary_energy_mode] == 0)} {
				# Scintillator:
				set scintillatorMaterialID [$_material_manager aRTist_id [my get scintillator_material_id]]
				set density     [Materials::get $scintillatorMaterialID density]
				set composition [Materials::get $scintillatorMaterialID composition]
				set scintillatorSteps  2
				set keys        [list $composition $density [my get scintillator_thickness] $scintillatorSteps [my get min_energy] [my get max_energy]]

				ctsimu::info "Computing sensitivity..."

				set start [clock microseconds]
				set sensitivitytext {}
				set first 1
				set Emin 0

				Engine::UpdateMaterials $scintillatorMaterialID

				set i 0
				set steps 9

				foreach { dE Emax EBin } {
					  0.1    50 0.01
					  0.5   100 0.05
					  1     200 0.1
					  5     500 0.2
					 20     600 0.5
					 50    1000 1
					100   10000 2
					200   12000 5
					500   20000 10
				} {
					set percentage [expr round(100*$i/$steps)]
					::ctsimu::status_info "Calculating detector sensitivity: $percentage% ($Emin .. $Emax keV)"
					incr i

					aRTist::Verbose { "$Emin\t$dE\t$Emax\t$EBin" }
					set grid [seq [expr {$Emin + $dE}] $dE [expr {$Emax + $dE / 10.}]]
					set Emin [lindex $grid end]

					# compute sensitivity
					set options [Engine::quotelist \
						--Thickness [expr {[my get scintillator_thickness] / 10.0}] \
						--Steps $scintillatorSteps \
						--EBin $EBin \
						--Min-Energy $minEnergy \
						--Max-Energy $maxEnergy \
					]
					if {([my get scintillator_thickness] > 0) && ($scintillatorMaterialID != "void")} {
						set data [xrEngine GenerateDetectorSensitivity $scintillatorMaterialID $options [join $grid \n]]
					} else {
						::ctsimu::fail "A scintillator material of non-zero thickness must be defined for a \'real\' detector."
					}

					foreach line [split $data \n] {
						if { [regexp {^\s*$} $line] } { continue }
						if { [regexp {^\s*#(.*)$} $line full cmt] } {
							if { !$first } { continue }
							if { [regexp {^\s*Time:} $cmt] } { continue }
							if { [regexp {^\s*Norm:} $cmt] } { continue }
							if { [regexp {^\s*Area:} $cmt] } { continue }
							if { [regexp {^\s*Distance:} $cmt] } { continue }
						}

						lappend sensitivitytext $line
					}

					set first 0
				}
				::ctsimu::info [format "Computed sensitivity in %.3fs" [expr {([clock microseconds] - $start) / 1e6}]]

				::ctsimu::status_info "Calculating detector characteristics..."

				set sensitivitytext [join $sensitivitytext \n]

				if { [catch {
					set CacheFile [TempFile::mktmp .det]

					set fd [open $CacheFile w]
					fconfigure $fd -encoding utf-8 -translation auto
					puts $fd $sensitivitytext
					close $fd

					dict set ${::ctsimu::ctsimu_module_namespace}::CacheFiles {*}$keys $CacheFile

				} err] } {
					Utils::nohup { close $fd }
					::ctsimu::info $err
				}
			} else {
				# For an ideal detector, set the same "sensitivity" for all energies.
				# Filters will be applied in the next step.

				for { set kV 0 } { $kV <= 1000 } { incr kV} {
					append sensitivitytext "$kV 1 $kV\n"
				}
			}

			# Apply detector filters
			foreach filter $_filters_front {
				aRTist::Verbose { "Filtering by $materialID, Thickness: $thickness" }
				Engine::UpdateMaterials [$filter material_id]
				set sensitivitytext [xrEngine FilterSpectrum $sensitivitytext [$filter material_id] [Engine::quotelist --Thickness [expr {[$filter thickness] / 10.0}]]]
			}

			set sensitivity [my ParseSpectrum $sensitivitytext 3]

			# interpolate sensitivity to spectrum
			set P_interact {}
			set E_interact {}
			foreach { energy pi ei } $sensitivity {
				aRTist::Trace { "$energy: $pi $ei" }
				append P_interact "$energy $pi\n"
				append E_interact "$energy $ei\n"
			}
			aRTist::Trace { "Prob:\n$P_interact" }
			aRTist::Trace { "E:\n$E_interact" }
			aRTist::Verbose { "Rebinning sensitivity data..." }
			set P_interact [my ParseSpectrum [xrEngine Rebin $P_interact $spectrumtext] 2]
			set E_interact [my ParseSpectrum [xrEngine Rebin $E_interact $spectrumtext] 2]
			aRTist::Trace { "Prob: $P_interact\n" }
			aRTist::Trace { "E: $E_interact\n" }

			set keV 1.6021765e-16; # J
			# compute photon count, mean energy, quadratic mean energy
			set Esum 0.0
			set Esqusum 0.0
			set Nsum 0.0
			foreach { esp ni } $spectrum { eprob probability } $P_interact { eenerg e_inter } $E_interact {
				::ctsimu::debug "$esp $ni, $eprob $probability, $eenerg $e_inter"
				if { $esp != $eprob || $esp != $eenerg } {
					::ctsimu::warning "Grids differ: $esp $eprob $eenerg"
					if { $esp == "" } {
						::ctsimu::warning "Spectrum shorter than sensitivity"
						break
					}
				}
				set signal   [expr { $keV * $e_inter }]
				set Nphotons [expr { $ni * $probability }]
				set Nsum     [expr { $Nsum    + $Nphotons }]
				set Esum     [expr { $Esum    + $Nphotons * $signal }]
				set Esqusum  [expr { $Esqusum + $Nphotons * $signal**2 }]

				::ctsimu::status_info "Calculating signal statistics for $keV keV..."
			}
			::ctsimu::status_info "Calculating detector characteristics..."

			::ctsimu::info "Nsum: $Nsum"
			if { $Nsum > 0 } {
				set Emean    [expr {$Esum    / $Nsum}]
				set Esqumean [expr {$Esqusum / $Nsum}]

				# the swank factor determines the reduction of SNR by the polychromatic spectrum
				# for mono spectrum, swank==1
				# for poly spectrum, SNR = swank * sqrt(N), N=total photon count
				set swank [expr {$Emean / sqrt($Esqumean)}]

				# compute effective pixel area in units of m^2
				if { $SRb <= 0.0 } {
					set pixelarea [expr { $pixelSizeX * $pixelSizeY * 1e-6 }]
				} else {
					# estimate effective area from gaussian unsharpness
					package require math::special
					set FractionX [math::special::erf [expr { $pixelSizeX / $SRb / sqrt(2.0) }]]
					set FractionY [math::special::erf [expr { $pixelSizeY / $SRb / sqrt(2.0) }]]
					set pixelarea [expr { ($pixelSizeX / $FractionX) * ($pixelSizeY / $FractionY) * 1e-6 }]
				}

				# compute total photon count onto the effective area
				set expfak [expr {$xray_source_current * $integrationTime * $nFrames * $pixelarea / double($SDD / 1000.0)**2}]
				set Ntotal [expr {$Nsum * $expfak}]
				set Etotal [expr {$Esum * $expfak}]

				if { ($Ntotal > 0) && ($Etotal > 0)} {
					aRTist::Verbose { "Swank factor $swank, Photon count $Ntotal, Energy $Etotal J" }

					set energyPerPixel [expr double($Etotal) / double($pixelarea) / double($nFrames)]
					# should we handle photon counting differently?
					set amplification  [expr {[my max_gray_value] / $energyPerPixel }]
					set maxinput $energyPerPixel

					# Flat field correction rescale factor
					my set ff_rescale_factor 60000

					# If linear interpolation is used instead of GVmin and GVmax:
					set GVatMaxInput 0.0
					set GVatNoInput 0.0
					set physical_pixel_area [expr { $pixelSizeX * $pixelSizeY * 1e-6 }]
					
					if { [my get gray_value_mode] == "linear"} {
						# Factor / offset method for gray value reproduction.
						::ctsimu::info "Factor: $factor, Offset: $offset, maxInput: $maxinput"

						# The factor must be converted to describe
						# an energy density characteristics in aRTist:
						set factor [expr double([my get factor]) * double($physical_pixel_area)]

						if { $factor != 0 } {
							set offset [my get offset]
							set GVatMaxInput [expr double($factor) * double($maxinput) + double($offset)]
							set GVatNoInput [expr double($offset)]

							::ctsimu::info "New Factor (scaled by pixel area): $factor, pixel area: $physical_pixel_area"
							::ctsimu::info "GVatNoInput: $GVatNoInput"
							::ctsimu::info "GVatMaxInput: $GVatMaxInput"

							# generate linear amplification curve
							dict set detector Characteristic 0.0 $GVatNoInput
							dict set detector Characteristic $maxinput $GVatMaxInput
							dict set detector Exposure TargetValue $GVatMaxInput
						}

						my set gv_max $GVatMaxInput

					} elseif { [my get gray_value_mode] == "imin_imax" } {
						# Min / max method for gray value reproduction.
						set GVatMin [my get imin]
						set GVatMax [my get imax]

						set amplification  [expr {double($GVatMax) / double($energyPerPixel) }]
						set maxinput $energyPerPixel

						set GVatMaxInput $GVatMax

						# generate linear amplification curve
						dict set detector Characteristic 0.0 $GVatMin
						dict set detector Characteristic $maxinput $GVatMax

						::ctsimu::info "GV at Min: $GVatMin, GV at Max: $GVatMax, maxInput: $maxinput"

						dict set detector Exposure TargetValue $GVatMax
						my set gv_max $GVatMax
						
					} elseif { [my get gray_value_mode] == "file" } {
						set csvFilename [my get gv_characteristics_file]
						set values [::ctsimu::read_csv_file $csvFilename]
						set energies   [dict get $values 0]; # first column
						set grayvalues [dict get $values 1]; # second column

						# generate linear amplification curve
						set nEntries [expr min([llength $energies], [llength $grayvalues])]

						if { $nEntries > 0 } {
							set maxInput     [lindex $energies 0]
							set GVatMaxInput [lindex $grayvalues 0]

							for {set i 0} {$i < $nEntries} {incr i} {
								set inputEnergyDensity [expr [lindex $energies $i] / $physical_pixel_area]
								set grayValue [lindex $grayvalues $i]
								dict set detector Characteristic $inputEnergyDensity $grayValue

								if { $inputEnergyDensity < $maxInput } {
									set maxInput $inputEnergyDensity
									set GVatMaxInput $grayValue
								}
							}

							# Min / max method for gray value reproduction.
							set GVatMax $GVatMaxInput

							set amplification  [expr {double($GVatMax) / double($energyPerPixel) }]
							set maxinput $energyPerPixel

							dict set detector Exposure TargetValue $GVatMax
							my set gv_max $GVatMax
						} else {
							::ctsimu::fail "The gray value characteristics file does not contain any valid entries."
						}						
					}
					
					dict set detector Quantization ValueMin 0
					dict set detector Quantization ValueMax [my max_gray_value]
					dict set detector Quantization ValueQuantum 0

					dict set detector Sensitivity $sensitivitytext
					
					# Flat field rescale factor:
					my set ff_rescale_factor [my get gv_max]

					if { [my get noise_mode] == "snr_at_imax" } {
						set SNR [my get snr_at_imax]
						
						# compute maximum theoretical SNR
						set SNR_ideal   [expr {sqrt($Ntotal)}]
						set SNR_quantum [expr {$SNR_ideal * $swank}]
						::ctsimu::info "SNR_quantum $SNR_quantum"

						if { $SNR > $SNR_quantum } {
							::ctsimu::warning "SNR measured better than quantum noise (SNR_quantum=$SNR_quantum), ignoring theoretical swank factor (SNR_quantum=$SNR_ideal)"
							set SNR_quantum $SNR_ideal
						}

						if { $SNR > $SNR_quantum } {
							::ctsimu::warning "SNR measured better than quantum noise (SNR_quantum=$SNR_quantum), using measured value (SNR_quantum=$SNR)"
							set SNR_quantum $SNR
						}

						# structure noise model: NSR^2_total = NSR^2_quantum + NSR^2_structure, NSR^2_structure=const
						set NSR2_quantum   [expr {1.0 / $SNR_quantum**2}]
						set NSR2_total     [expr {1.0 / $SNR**2}]
						set NSR2_structure [expr {$NSR2_total - $NSR2_quantum}]

						# generate SNR curve, 500 log distributed steps
						set nsteps   500
						puts "Amplification: $amplification"
						set mininput [expr {1.0 / $amplification}]
						puts "MinInput: $mininput"
						set refinput [expr {($GVatMaxInput) / $amplification * $nFrames}]
						set maxFrames [max 100.0 $nFrames]
						set factor   [expr {(max(100.0, $maxFrames) * $maxinput / $mininput)**(1.0 / $nsteps)}]
						for { set step 0 } { $step <= $nsteps } { incr step } {
							set percentage [expr round(100*$step/$nsteps)]
							::ctsimu::status_info "Calculating SNR characteristics: $percentage%"

							set intensity    [expr {$mininput * double($factor)**$step}]
							set NSR2         [expr {$NSR2_structure + $NSR2_quantum * $refinput / $intensity}]
							set SNR          [expr {sqrt(1.0 / $NSR2)}]
							dict set detector Noise $intensity $SNR
							::ctsimu::debug "Noise: $intensity [expr {$intensity * $amplification}] $SNR"
						}
					}

					::ctsimu::status_info "Detector characteristics done."

					return $detector
				} else {
					::ctsimu::fail "Detector does not detect any photons. Please check your detector properties (sensitivity, etc.) and your source properties (spectrum, current, etc.) for mistakes."
				}
			} else {
				::ctsimu::fail "Detector does not detect any photons. Please check your detector properties (sensitivity, etc.) and your source properties (spectrum, current, etc.) for mistakes."
			}
		}
	}
}