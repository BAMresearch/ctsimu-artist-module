package require TclOO
package require fileutil
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_part.tcl]

# A class for the detector.

namespace eval ::ctsimu {
	::oo::class create detector {
		superclass ::ctsimu::part

		constructor { { name "Detector" } } {
			next $name; # call constructor of parent class ::ctsimu::part
			my reset
		}

		destructor {
			next
		}

		method reset { } {
			# Reset to standard settings.

			# Declare all detector parameters and theirs native units.
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

			# Reset the '::ctsimu::part' that coordinates the coordinate system:
			next; # call reset of parent class ::ctsimu::part
		}

		method set_from_json { jobj world stage } {
			# Import the detector definition and geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file (at least the geometry and detector sections).
			set detectorGeometry [::ctsimu::extract_json_object $jobj {geometry detector}]
			my set_geometry $detectorGeometry $world $stage

			# Detector properties:
			set detprops [::ctsimu::extract_json_object $jobj {detector}]

			my set model        [::ctsimu::get_value $detprops {model} ""]
			my set manufacturer [::ctsimu::get_value $detprops {manufacturer} ""]

			if { ![my set_property type $detprops {type} "ideal"] } {
				::ctsimu::warn "Detector type not found or invalid. Should be \"ideal\" or \"real\". Using standard value: \"ideal\"."
			} else {
				# Check if the detector type is valid:
				set value [[my get type] standard_value]
				if { ![::ctsimu::is_valid $value {"ideal" "real"}] } {
					::ctsimu::warn "No valid detector type: $value. Should be \"ideal\" or \"real\". Using standard value: \"ideal\"."
					my set type "ideal"
				}
			}
			
			if { ![my set_from_key columns $detprops {columns} 100 ""] } {
				::ctsimu::warn "Number of detector columns not found or invalid. Using standard value."
			}

			if { ![my set_from_key rows $detprops {rows} 100 ""] } {
				::ctsimu::warn "Number of detector rows not found or invalid. Using standard value."
			}

			if { ![my set_from_key pitch_u   $detprops {pixel_pitch u} 0.1 "mm"] } {
				::ctsimu::warn "Pixel pitch in the u direction not found or invalid. Using standard value."
			}

			if { ![my set_from_key pitch_v   $detprops {pixel_pitch v} 0.1 "mm"] } {
				::ctsimu::warn "Pixel pitch in the v direction not found or invalid. Using standard value."
			}
			
			if { ![my set_from_key bit_depth $detprops {bit_depth} 16 ""] } {
				::ctsimu::warn "Detector bit depth not found or invalid. Using standard value."
			}

			if { ![my set_from_key integration_time $detprops {integration_time} 1 "s"] } {
				::ctsimu::warn "Detector integration time not found or invalid. Using standard value (1 s)."
			}

			my set_from_key dead_time $detprops {dead_time} 1 "s"
			my set_from_key image_lag $detprops {image_lag} 0.0
			
			#my set gray_value_mode  "imin_imax" "string"
				# Valid gray value modes:
				# "imin_imax", "linear", "file"

			my set_from_possible_keys imin $detprops {{grey_value imin} {gray_value imin}} "null"
			my set_from_possible_keys imax $detprops {{grey_value imax} {gray_value imax}} "null"
			my set_from_possible_keys factor $detprops {{grey_value factor} {gray_value factor}} "null"
			my set_from_possible_keys offset $detprops {{grey_value offset} {gray_value offset}} "null"

			my set_from_possible_keys gv_characteristics_file $detprops {{grey_value intensity_characteristics_file} {gray_value intensity_characteristics_file}} "null"

			my set_from_possible_keys efficiency  $detprops {{grey_value efficiency} {gray_value efficiency}} "null"
			my set_from_possible_keys efficiency_characteristics_file $detprops {{grey_value efficiency_characteristics_file} {gray_value efficiency_characteristics_file}} "null"

			
			# Noise:
			#my set noise_mode       "off" "string"
				# Valid noise modes:
				# "off", "snr_at_imax", "file"
			my set_from_key snr_at_imax $detprops {noise snr_at_imax} "null"
			my set_from_key noise_characteristics_file $detprops {noise noise_characteristics_file} "null"
			
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

			::ctsimu::note "Done reading detector parameters."
		}
	}
}