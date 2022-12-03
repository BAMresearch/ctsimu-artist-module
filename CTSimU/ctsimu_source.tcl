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

		constructor { { name "CTSimU_Source" } { id "S" } } {
			next $name $id; # call constructor of parent class ::ctsimu::part
			set _filters [list ]
			set _window_filters [list ]
			set _previous_hash "0"

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
			my set target_thickness        0  "mm"
			my set target_angle_incidence 45  "deg"
			my set target_angle_emission  45  "deg"
			
			# Spot
			my set spot_size_u             0  "mm"
			my set spot_size_v             0  "mm"
			my set spot_size_w             0  "mm"
			my set spot_sigma_u            0  "mm"
			my set spot_sigma_v            0  "mm"
			my set spot_sigma_w            0  "mm"
			
			# Intensity map
			my set intensity_map_file     ""  "string"; # map file is parameter, can have drift file
			my set intensity_map_type     "float"  "string"
			my set intensity_map_dim_x     0  ""
			my set intensity_map_dim_y     0  ""
			my set intensity_map_dim_z     0  ""

			# Spectrum
			my set spectrum_monochromatic  0   "bool"
			my set spectrum_file           ""  "string"
			my set spectrum_resolution     1.0 ""; # keV
		}

		method hash { } {
			# Returns a hash of all properties that are
			# relevant for the generation of the spectrum.
			
			# Create a unique string:
			set us "source"
			append us "[my get voltage]"
			append us "[my get target_thickness]"
			append us "[my get target_angle_incidence]"
			append us "[my get target_angle_emission]"
			if { [my get target_material_id] != "null" } {
				append us "[ [$_material_manager get [my get target_material_id]] density ]"
				append us "[ [$_material_manager get [my get target_material_id]] composition ]"
			}			
			
			foreach filter $_filters {
				append us "[ $filter thickness]"
				if { [$filter material_id] != "null" } {
					append us "[ [$_material_manager get [$filter material_id]] density ]"
					append us "[ [$_material_manager get [$filter material_id]] composition ]"
				}
			}

			foreach filter $_window_filters {
				append us "[ $filter thickness]"
				if { [$filter material_id] != "null" } {
					append us "[ [$_material_manager get [$filter material_id]] density ]"
					append us "[ [$_material_manager get [$filter material_id]] composition ]"
				}
			}

			# Spectrum file:
			append us [my get spectrum_file]
			
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

			# Intensity map
			my set_parameter_from_key intensity_map_file  $sourceprops {spot intensity_map}
			my set_parameter_value    intensity_map_type  $sourceprops {spot intensity_map type}
			my set_parameter_value    intensity_map_dim_x $sourceprops {spot intensity_map dim_x}
			my set_parameter_value    intensity_map_dim_y $sourceprops {spot intensity_map dim_y}
			my set_parameter_value    intensity_map_dim_z $sourceprops {spot intensity_map dim_z}

			# Spectrum
			my set_parameter_from_key spectrum_monochromatic $sourceprops {spectrum monochromatic}
			my set_parameter_from_key spectrum_file          $sourceprops {spectrum file}
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
					set ::Xsource(Name) [my name]

					# Load spectrum from a file?
					if { [my get spectrum_file] != "" } {
						# TODO
					}

					# Generate the spectrum if source parameters have changed:
					if { [my get spectrum_monochromatic] == 1 } {
						# Monochromatic spectrum
						set ::Xsource(Tube) Mono
					} else {
						# Check if a temp file already exists:
						set spectrum_temp_file [my current_temp_file]
						
						if { ![file exists $spectrum_temp_file] } {
							# Spectrum file does not exist.
							# We generate one...
							set ::Xsource(Resolution) [my get spectrum_resolution]

							# Polychromatic spectrum.
							set ::Xsource(Tube) General

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
									set material_id [$_material_manager aRTist_id [$window material_id]]
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

							# TODO:
							#ComputeSpectrum $windowFilters $xraySourceFilters

							XSource::SaveSpectrum $spectrum_temp_file
						} else {
							FileIO::OpenAnyGUI $spectrum_temp_file
						}
					}
				}				
			}
		}
	}
}