package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_sample.tcl]

# A class for the detector.

namespace eval ::ctsimu {
	::oo::class create detector {
		superclass ::ctsimu::part

		constructor { { name "CTSimU_Detector" } { id "D" } } {
			next $name $id; # call constructor of parent class ::ctsimu::part
			my reset
		}

		destructor {
			next
		}

		method reset { } {
			# Reset to standard settings.
			
			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part

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
			
			# Properties for gray value reproduction:
			my set gray_value_mode  "imin_imax" "string"
				# Valid gray value modes:
				# "imin_imax", "linear", "file"
			my set imin             0
			my set imax             60000
			my set factor           1.0
			my set offset           0.0
			my set gv_characteristics_file "" "string"
			my set efficiency       1.0
			my set efficiency_characteristics_file "" "string"
			
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
			#my set unsharpness_mode "off" "string"
				# Valid unsharpness modes:
				# "off", "basic_spatial_resolution", "mtf10freq", "mtffile"

			my set_from_key basic_spatial_resolution $detprops {unsharpness basic_spatial_resolution} "null"
			my set_from_key mtf10_freq $detprops {unsharpness mtf10_frequency} "null"
			my set_from_key mtf_file $detprops {unsharpness mtf} "null"
			
			# Bad pixel map
			my set_from_key bad_pixel_map $detprops {bad_pixel_map} "null"
			my set_property bad_pixel_map_type $detprops {bad_pixel_map type} "null"
			
			# Scintillator
			my set_property scintillator_material_id $detprops {scintillator material_id} "null"
			my set_from_key scintillator_thickness $detprops {scintillator thickness} 0

			# Frame averaging:
			my set_property frame_average $jobj {acquisition frame_average} 1

			::ctsimu::info "Done reading detector parameters."
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

				::XDetector::UpdateGeometry %W


			}
		}
	}
}