package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_stage.tcl]

# A class for the X-ray source.

namespace eval ::ctsimu {
	::oo::class create source {
		superclass ::ctsimu::part
		variable _filters; # external filters in front of the tube
		variable _window_filters; # window part of the tube
		variable _material_manager
		variable _previous_hash
		variable _previous_hash_spot

		constructor { { name "CTSimU_Source" } { id "S" } } {
			next $name $id; # call constructor of parent class ::ctsimu::part
			set _filters [list ]
			set _window_filters [list ]
			set _previous_hash "0"
			set _previous_hash_spot "0"

			my reset
		}

		destructor {
			foreach filter $_filters {
				$filter destroy				
			}
			set _filters [list ]

			foreach filter $_window_filters {
				$filter destroy				
			}
			set _window_filters [list ]

			next
		}

		method initialize { material_manager } {
			# Necessary initialization after constructing, when the source object
			# shall be used fully (not just as a geometrical object).
			set _material_manager $material_manager
		}

		method reset { } {
			# Reset to standard settings.
			set _previous_hash "0"
			set _previous_hash_spot "0"

			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part

			# Empty filter lists:
			foreach filter $_filters {
				$filter destroy				
			}
			set _filters [list ]

			foreach filter $_window_filters {
				$filter destroy				
			}
			set _window_filters [list ]
			
			# The current timestamp, necessary for hashing.
			my set timestamp [clock seconds]

			# Declare all source parameters and their native units.
			# --------------------------------------------------------
			# General properties:
			my set model                  ""  "string"
			my set manufacturer           ""  "string"
			my set voltage                130 "kV"
			my set current                0.1 "mA"
			
			# Target
			my set target_material_id     "W" "string"
			my set target_type            "reflection" "string"
			my set target_thickness       10  "mm"
			my set target_angle_incidence 45  "deg"
			my set target_angle_emission  45  "deg"
			
			# Spot
			my set spot_size_u             0  "mm"
			my set spot_size_v             0  "mm"
			my set spot_size_w             0  "mm"
			my set spot_sigma_u            0  "mm"
			my set spot_sigma_v            0  "mm"
			my set spot_sigma_w            0  "mm"
			my set multisampling           "20"  "string"
			
			# Intensity map
			my set intensity_map_file       ""  "string"; # map file is parameter, can have drift file
			my set intensity_map_datatype   "float32"  "string"
			my set intensity_map_dim_x      0 ""
			my set intensity_map_dim_y      0 ""
			my set intensity_map_dim_z      0 ""
			my set intensity_map_headersize 0 ""
			my set intensity_map_endian     "little" "string"

			# Spectrum
			my set spectrum_monochromatic  0   "bool"
			my set spectrum_file           ""  "string"
			my set spectrum_resolution     1.0 ""; # keV
		}

		method hash { } {
			# Returns a hash of all properties that are
			# relevant for the generation of the spectrum.
			
			# Create a unique string:
			set us "source_[my get timestamp]"
			append us "_[my get voltage]"
			append us "_[my get target_thickness]"
			append us "_[my get target_angle_incidence]"
			append us "_[my get target_angle_emission]"
			if { [my get target_material_id] != "null" } {
				append us "_[$_material_manager density [my get target_material_id]]"
				append us "_[$_material_manager composition [my get target_material_id]]"
			}			
			
			foreach filter $_filters {
				append us "_[ $filter thickness]"
				if { [$filter material_id] != "null" } {
					append us "_[$_material_manager density [$filter material_id]]"
					append us "_[$_material_manager composition [$filter material_id]]"
				}
			}

			foreach filter $_window_filters {
				append us "_[ $filter thickness]"
				if { [$filter material_id] != "null" } {
					append us "_[$_material_manager density [$filter material_id]]"
					append us "_[$_material_manager composition [$filter material_id]]"
				}
			}

			# Spectrum file:
			append us [my get spectrum_file]
				
			return [md5::md5 -hex $us]
		}
		
		method hash_spot { } {
			# Returns a hash for the spot profile
			
			# Create a unique string:
			set us "source_spot_[my get timestamp]"
			append us "_[my get spot_size_u]"
			append us "_[my get spot_size_v]"
			append us "_[my get spot_size_w]"
			append us "_[my get spot_sigma_u]"
			append us "_[my get spot_sigma_v]"
			append us "_[my get spot_sigma_w]"
			append us "_[my get intensity_map_file]"
				
			return [md5::md5 -hex $us]
		}

		method current_temp_file { } {
			return [file join ${::TempFile::tempdir} "CTSimU_Spectrum_[my hash].xrs"]
		}

		method set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } } {
			# Update filter list:
			foreach filter $_filters {
				$filter set_frame $frame $nFrames				
			}

			foreach filter $_window_filters {
				$filter set_frame $frame $nFrames				
			}

			# Call set_frame of parent class '::ctsimu::part':
			next $stageCS $frame $nFrames $w_rotation_in_rad
		}

		method set_from_json { jobj stage } {
			# Import the source definition and geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file
			# (at least the geometry and source sections).
			# `stage` is the `::ctsimu::coordinate_system` that represents
			# the stage in the world coordinate system. Necessary because
			# the source could be attached to the stage coordinate system.
			my reset

			set sourceGeometry [::ctsimu::json_extract $jobj {geometry source}]
			my set_geometry $sourceGeometry $stage
			
			# Source properties:
			set sourceprops [::ctsimu::json_extract $jobj {source}]

			# Tube name:
			my set model        [::ctsimu::get_value $sourceprops {model} ""]
			my set manufacturer [::ctsimu::get_value $sourceprops {manufacturer} ""]
			my set_name "CTSimU_tube"
			if { ([my get model] != "") || ([my get model] != "")} {
				if { [my get model] == "" } {
					my set_name [my get manufacturer]
				} elseif { [my get manufacturer] == "" } {
					my set_name [my get model]
				} else {
					my set_name "[my get manufacturer] [my get model]"
				}
			}
			
			if { ![my set_parameter_from_key voltage $sourceprops {voltage}] } {
				::ctsimu::warning "No voltage provided for the X-ray source."
			}
			
			if { ![my set_parameter_from_key current $sourceprops {current}] } {
				::ctsimu::warning "No current provided for the X-ray source."
			}

			# Target
			my set_parameter_value    target_material_id     $sourceprops {target material_id}
			my set_parameter_from_key target_thickness       $sourceprops {target thickness}
			my set_parameter_value    target_type            $sourceprops {type}
			my set_parameter_from_key target_angle_incidence $sourceprops {target angle incidence}
			my set_parameter_from_key target_angle_emission  $sourceprops {target angle emission}

			# Spot
			my set_parameter_from_key spot_size_u  $sourceprops {spot size u}
			my set_parameter_from_key spot_size_v  $sourceprops {spot size v}
			my set_parameter_from_key spot_size_w  $sourceprops {spot size w}
			my set_parameter_from_key spot_sigma_u $sourceprops {spot sigma u}
			my set_parameter_from_key spot_sigma_v $sourceprops {spot sigma v}
			my set_parameter_from_key spot_sigma_w $sourceprops {spot sigma w}

			# If a finite spot size is provided but no Gaussian sigmas,
			# the Gaussian width is assumed to be the spot size.
			if { [my get spot_sigma_u] <= 0 } {
				my set spot_sigma_u [my get spot_size_u]
			}
			if { [my get spot_sigma_v] <= 0 } {
				my set spot_sigma_v [my get spot_size_v]
			}

			# Intensity map
			my set_parameter_from_key intensity_map_file      $sourceprops {spot intensity_map}
			my set_parameter_value    intensity_map_datatype  $sourceprops {spot intensity_map type} "float32"
			my set_parameter_value    intensity_map_dim_x     $sourceprops {spot intensity_map dim_x} 0
			my set_parameter_value    intensity_map_dim_y     $sourceprops {spot intensity_map dim_y} 0
			my set_parameter_value    intensity_map_dim_z     $sourceprops {spot intensity_map dim_z} 0
			my set_parameter_value    intensity_map_endian    $sourceprops {spot intensity_map endian} "little"
			my set_parameter_value    intensity_map_headersize  $sourceprops {spot intensity_map headersize} 0

			# Spectrum
			my set_parameter_from_key spectrum_monochromatic $sourceprops {spectrum monochromatic}
			my set_parameter_from_key spectrum_file          $sourceprops {spectrum file} ""
			my set_parameter_from_key spectrum_resolution    $jobj {simulation aRTist spectral_resolution} 1.0

			# Filters can be defined in "window" or "filters":
			set _window_filters [::ctsimu::add_filters_to_list $_window_filters $sourceprops {window}]
			set _filters        [::ctsimu::add_filters_to_list $_filters $sourceprops {filters}]

			::ctsimu::info "Done reading source parameters."
		}

		method set_in_aRTist { } {
			if { [::ctsimu::aRTist_available] } {
				set current_hash [my hash]
				if { $current_hash != $_previous_hash } {
					set _previous_hash $current_hash
					
					set ::Xsource(Name) [my name]
					
					# Current:
					set ::Xsource(Exposure) [my get current]
					
					# Voltage:
					set ::Xsource(Voltage) [my get voltage]

					# Generate the spectrum if source parameters have changed:
					if { [my get spectrum_monochromatic] == 1 } {
						# Monochromatic spectrum
						set ::Xsource(Tube) Mono
						my compute_spectrum
					} else {
						# Polychromatic spectrum.
						set ::Xsource(Tube) General
						set ::Xsource(Resolution) [my get spectrum_resolution]

						# Target type:
						if { [my get target_type] == "transmission" } {
							set ::Xsource(Transmission) 1
						} else {
							set ::Xsource(Transmission) 0
						}

						# Target:
						set ::Xsource(TargetMaterial) [$_material_manager aRTist_id [my get target_material_id]]
						set ::Xsource(TargetThickness) [my get target_thickness]
						set ::Xsource(AngleIn) [my get target_angle_incidence]
						set ::Xsource(TargetAngle) [my get target_angle_emission]

						# Tube window
						set ::Xsource(WindowThickness) 0
						set ::Xsource(WindowMaterial) "void"

						if { [llength $_window_filters] > 0 } {
							set i 0
							foreach window $_window_filters {
								if {$i == 0} {
									# Only accept the first defined window filter here.
									# aRTist does not support more than one; we'll deal
									# with the other ones later when re-filtering the spectrum
									# after it has been computed.
									set ::Xsource(WindowThickness) [$window thickness]
									set ::Xsource(WindowMaterial) [$_material_manager aRTist_id [$window material_id]]
								}
							}								
						}

						# External filters
						set ::Xsource(FilterThickness) 0
						set ::Xsource(FilterMaterial) "void"
						set ::Xsource(Filter2Thickness) 0
						set ::Xsource(Filter2Material) "void"
						set ::Xsource(Filter3Thickness) 0
						set ::Xsource(Filter3Material) "void"

						if { [llength $_filters] > 0 } {
							set i 0
							foreach filter $_filters {
								set thickness [$filter thickness]
								set material_id [$_material_manager aRTist_id [$filter material_id]]
								switch $i {
									0 {
										set ::Xsource(FilterThickness) $thickness
										set ::Xsource(FilterMaterial) $material_id
									}
									1 {
										set ::Xsource(Filter2Thickness) $thickness
										set ::Xsource(Filter2Material) $material_id
									}
									2 {
										set ::Xsource(Filter3Thickness) $thickness
										set ::Xsource(Filter3Material) $material_id
									}
								}
								incr i
							}								
						}
						
						# Load spectrum from a file?
						if { [my get spectrum_file] != "" } {
							set spectrum_file_absolute_path [::ctsimu::get_absolute_path [my get spectrum_file]]
							
							my load_spectrum $spectrum_file_absolute_path
						} else {
							# Check if a temp file already exists:
							set spectrum_temp_file [my current_temp_file]
							
							if { ![file exists $spectrum_temp_file] } {
								# Generate spectrum and save as
								# temp file:
								my compute_spectrum
								
								::ctsimu::info "Saving temporary spectrum file: $spectrum_temp_file"
								::XSource::SaveSpectrum $spectrum_temp_file
							} else {
								# Spectrum was already calculated. Load from temp file:
								FileIO::OpenAnyGUI $spectrum_temp_file
							}
						}
					}
				}
				
				# Spot size is not part of standard hash, treat it here
				# and check if it has changed since last frame:
				set current_hash_spot [my hash_spot]
				if { $current_hash_spot != $_previous_hash_spot } {
					set _previous_hash_spot $current_hash_spot
									 
					# aRTist only supports 2D spot profiles					
					set sigmaX    [my get spot_sigma_u]
					set sigmaY    [my get spot_sigma_v]
					set spotSizeX [my get spot_size_u]
					set spotSizeY [my get spot_size_v]
					
					::ctsimu::info "Spot size: x=$spotSizeX, y=$spotSizeY, sigma_x=$sigmaX, sigma_y=$sigmaY"

					if { ($sigmaX <= 0) || ($sigmaY <= 0) || ($spotSizeX <= 0) || ($spotSizeY <= 0) } {
						# Point source						
						set ::Xsource_private(SpotWidth) 0
						set ::Xsource_private(SpotHeight) 0
						set ::Xsetup_private(SGSx) 0
						set ::Xsetup_private(SGSy) 0
						set ::Xsetup(SourceSampling) point

						::XSource::SelectSpotType
					} else {
						set ::Xsource_private(SpotWidth) $spotSizeX
						set ::Xsource_private(SpotHeight) $spotSizeY
						set ::Xsetup_private(SGSx) $spotSizeX
						set ::Xsetup_private(SGSy) $spotSizeY
						set ::Xsetup(SourceSampling) [my get multisampling]
						::XSource::SelectSpotType
						::XSource::SourceSizeModified
						
						# 2D spot intensity profile
						if { [my get intensity_map_file] != "" } {
							# Load spot intensity map file:
							my load_spot_image
						} else {
							# Create Gaussian spot profile image
							my make_gaussian_spot_profile $sigmaX $sigmaY
						}
					}
				}
			}
		}
		
		method compute_spectrum { } {
			# Adaption of `proc ComputeSpectrum` from stuff/xsource.tcl.
			# Assumes that XSource properties are already set.
			global Xsource Xsource_private
			variable ComputedSpectra

			if { $Xsource(Tube) == "Mono" } {
				# generate monochromatic spectrum
				# 1 GBq at Voltage
				set description "Monochromatic $Xsource(Voltage) keV, 1 / (GBq * sr)"
				lappend spectrum "# $description"
				lappend spectrum "# Name: $Xsource(Tube)"
				lappend spectrum "$Xsource(Voltage) [expr {1e9 / (4 * $Math::Pi)}]"

			} else {

				# xray tube, use xraytools
				set AngleOut $Xsource(TargetAngle)
				if { [string is double -strict $Xsource(AngleIn)] } {
					set AngleIn $Xsource(AngleIn)
				} else {
					set AngleIn [expr {90 - $AngleOut}]
					set Xsource(AngleIn) $AngleIn
				}

				set compute true
				set mode [Preferences::Get Source ComputationMode]
				set keys [list \
					[expr { $Xsource(Transmission) ? "Transmission" : "Direct" }] \
					[Materials::get $Xsource(TargetMaterial) composition] \
					[expr { double([Materials::get $Xsource(TargetMaterial) density]) }] \
					[expr { double($Xsource(TargetThickness)) }] \
					[expr { double($AngleIn) }] \
					[expr { double($AngleOut) }] \
					[expr { double($Xsource(Voltage)) }] \
					[expr { double($Xsource(Resolution)) }] \
					$mode \
				]

				set persistent [Preferences::Get Source PersistentCache]
				if { $persistent } {

					variable SpectrumDir

					set path $SpectrumDir
					foreach key $keys { set path [file join $path [Utils::SanitizeFileName $key]] }
					append path .xrs

					if { [Utils::FileReadable $path] } { set cached $path }

				}

				aRTist::Verbose { "Computing spectrum" }

				set options {}
				switch -nocase -- $mode {
					Precise { lappend options --Interpolation false }
					Fast    { lappend options --BSModel XRTFast }
				}
				lappend options --Transmission [expr { $Xsource(Transmission) ? "true" : "false" }]
				lappend options --Thickness [expr { $Xsource(TargetThickness) / 10.0 }]
				lappend options --Angle-Out $AngleOut --Angle-In $AngleIn
				lappend options --kVp $Xsource(Voltage) --EBin $Xsource(Resolution)
				lappend options --Current 1 --Time 1

				# compute the spectrum
				Engine::UpdateMaterials $Xsource(TargetMaterial)
				xrEngine GenerateSpectrum $Xsource(TargetMaterial) [Engine::quotelist {*}$options]

				if { [catch {

					if { $persistent } {
						set cached $path
						file mkdir [file dirname $cached]
					} else {
						set cached [TempFile::mktmp .xrs]
					}

					aRTist::Verbose { "Caching computed spectrum: '$cached'" }
					::XSource::WriteXRS $cached [Engine::GetSpectrum]

					if { !$persistent } { dict set ComputedSpectra {*}$keys $cached }

				} err errdict] } {
					::ctsimu::info "Failed to cache computed spectrum: $err"
				}

				# build comments
				set description "X-ray tube ($Xsource(Tube)): $Xsource(TargetMaterial), $Xsource(Voltage) kV, $Xsource(TargetAngle)\u00B0"

				# Filter by window layers (JSON supports more than one window)
				foreach window $_window_filters {
					set thickness [$window thickness]
					set materialID [$window material_id]

					if { $thickness > 0 } {
						::ctsimu::info "Filtering with window: $thickness mm $materialID."
						Engine::UpdateMaterials $materialID
						# Thickness is in mm, XRayTools expects cm
						xrEngine FilterSpectrum $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]
						
						append description ", $thickness mm $materialID"
					}
				}

				# Filter by external filters (JSON supports more than one filter)
				foreach filter $_filters {
					set thickness [$filter thickness]
					set materialID [$filter material_id]
					
					if { $thickness > 0 } {
						::ctsimu::info "Filtering with external filter: $thickness mm $materialID."
						Engine::UpdateMaterials $materialID
						# Thickness is in mm, XRayTools expects cm
						xrEngine FilterSpectrum $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]
						
						append description ", $thickness mm $materialID"
					}
				}

				lappend spectrum "# $description"
				lappend spectrum "# Name: $Xsource(Tube)"
				foreach line [Engine::GetSpectrum] {
					if { ![regexp {^\s*#\s*Directory:} $line] } { lappend spectrum $line }
				}
			}

			::XSource::ClearOrigSpectrum
			set Xsource_private(Spectrum) $spectrum
			set Xsource_private(SpectrumName) $Xsource(Tube)
			set Xsource_private(SpectrumDescription) $description
			set Xsource(HalfLife) 0
			set Xsource(computed) 1
			::XSource::GeneratePreviewSpectrum

			set fname [TempFile::mktmp .xrs]
			::XSource::WriteXRS $fname
			::XRayProject::AddFile Source spectrum $fname .xrs
		}
		
		method engine_spectrum_string_to_XSource_list { engineString } {
			set spectrum {}
			foreach entry [split $engineString \n] {				
				if { ![regexp {^\s*#} $entry] } {
					set entries [split $entry]
					#puts "Entries: $entries"
					if {[llength $entries] > 1} {
						set energy [lindex $entries 0]
						set counts [lindex $entries 1]

						lappend spectrum [list $energy $counts]
					}
				}
			}

			return $spectrum
		}
		
		method load_spectrum { file } {
			# Filter the loaded spectrum by external filters, but not by windows.

			::ctsimu::info "Loading spectrum file: $file"

			global Xsource Xsource_private
			variable ComputedSpectra

			set spectrumString [::ctsimu::load_csv_into_tab_separated_string $file 1]	

			# build comments
			set description "X-ray tube ($Xsource(Tube)): $Xsource(TargetMaterial), $Xsource(Voltage) kV, $Xsource(TargetAngle)\u00B0"

			# Add window materials to description (JSON supports more than one window)
			foreach window $_window_filters {
				set thickness [$window thickness]
				set materialID [$window material_id]
				
				if { $thickness > 0 } {
					append description ", $thickness mm $materialID"
				}
			}
		
			# Filter by external filters (JSON supports more than one filter)
			foreach filter $_filters {
				set thickness [$window thickness]
				set materialID [$window material_id]
				
				if { $thickness > 0 } {
					aRTist::Info { "Filtering with external filter: $thickness mm $materialID."}
					Engine::UpdateMaterials $materialID
					# Thickness is in mm, XRayTools expect cm
					set spectrumString [xrEngine FilterSpectrum $spectrumString $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]]

					append description ", $thickness mm $materialID"
				}
			}

			set spectrum [ my engine_spectrum_string_to_XSource_list $spectrumString ]

			::XSource::ClearOrigSpectrum
			set Xsource_private(Spectrum) $spectrum
			set Xsource_private(SpectrumName) $Xsource(Tube)
			set Xsource_private(SpectrumDescription) $description
			set Xsource(HalfLife) 0
			set Xsource(computed) 1
			::XSource::GeneratePreviewSpectrum

			set fname [TempFile::mktmp .xrs]
			::XSource::WriteXRS $fname
			::XRayProject::AddFile Source spectrum $fname .xrs
		}

		method make_gaussian_spot_profile { sigmaX sigmaY } {
			global Xsource_private
			set Xsource_private(SpotRes) 301
			set Xsource_private(SpotLorentz) 0.0

			# Spot width and height are assumed to be FWHM of Gaussian profile.
			# Convert sigma to FWHM:
			set Xsource_private(SpotWidth) [expr 2.3548*$sigmaX]
			set Xsource_private(SpotHeight) [expr 2.3548*$sigmaY]

			::ctsimu::info "Setting Gaussian spot size. sigmaX=$sigmaX, sigmaY=$sigmaY."

			::XSource::SetSpotProfile
		}
		
		method load_spot_image { } {
			# adapted from xsource.tcl to allow read RAW images of arbitrary size
			set spot_image_file_absolute_path [::ctsimu::get_absolute_path [my get intensity_map_file]]
			
			::ctsimu::info "Loading spot image: $spot_image_file_absolute_path"
			
			set spotimg [::ctsimu::image new $spot_image_file_absolute_path]
			$spotimg set_width    [my get intensity_map_dim_x]
			$spotimg set_height   [my get intensity_map_dim_y]
			$spotimg set_depth    [my get intensity_map_dim_z]
			$spotimg set_datatype [my get intensity_map_datatype]
			$spotimg set_endian   [my get intensity_map_endian]
			$spotimg set_headersize [my get intensity_map_headersize]
			
			set img [$spotimg load_image]
			
			$spotimg destroy
			
			if { [catch {
				set tmp [Image::aRTistImage %AUTO%]
				$tmp ShallowCopy $img
				$img Delete
				set img $tmp
			} err errdict] } {
				catch { $img Delete }
				catch { $tmp Delete }
				::ctsimu::fail "Error loading spot image."
				return -options $errdict $err
			}

			::XSource::ClearSpot
			set ::Xsource_private(SpotProfile) $img
			::XRayProject::AddFile Source SpotProfile $spot_image_file_absolute_path

			set ::Xsource_private(SpotWidth)  [my get spot_size_u]
			set ::Xsource_private(SpotHeight) [my get spot_size_v]
			::XSource::SourceSizeModified

			$::XSource::widget(ClearButton) state !disabled
			$::XSource::widget(ShowButton) state !disabled
			catch { unset ::Xsource_private(SourceGrid) }

			::SceneView::RedrawRequest
			
			::ctsimu::info "Successfully loaded spot image."
		}
	}
}