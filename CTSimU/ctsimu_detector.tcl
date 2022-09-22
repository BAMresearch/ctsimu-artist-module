package require TclOO
package require fileutil
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_part.tcl]

# A class for the detector.

namespace eval ::ctsimu {
	::oo::class create detector {
		variable _detector; # private detector as a ::ctsimu::part

		constructor { } {
			# The ::ctsimu::part that represents the detector:
			set _detector [::ctsimu::part new "Detector"]
			my reset
		}

		destructor {
			$_detector destroy
		}

		method reset { } {
			# Reset to standard settings.

			# Reset the 'part' that coordinates the coordinate system:
			$_detector reset
			$_detector attach_to_stage 0

			# Declare all detector parameters and theirs native units.
			# --------------------------------------------------------
			
			# General properties:
			$_detector set model            "" "string"
			$_detector set manufacturer     "" "string"
			$_detector set type             "ideal" "string"
			$_detector set columns          1000
			$_detector set rows             1000
			$_detector set pitch_u          0.1 "mm"
			$_detector set pitch_v          0.1 "mm"
			$_detector set bit_depth        16
			$_detector set integration_time 1.0 "s"
			$_detector set dead_time        0.0 "s"
			$_detector set image_lag        0.0
			
			# Properties for gray value reproduction:
			$_detector set gray_value_mode  "imin_imax" "string"
				# Valid gray value modes:
				# "imin_imax", "linear", "file"
			$_detector set imin             0
			$_detector set imax             60000
			$_detector set factor           3.0e15
			$_detector set offset           0
			$_detector set gv_characteristics_file "" "string"
			$_detector set efficiency       1.0
			$_detector set efficiency_characteristics_file "" "string"
			
			# Noise:
			$_detector set noise_mode       "off" "string"
				# Valid noise modes:
				# "off", "snr_at_imax", "file"
			$_detector set snr_at_imax      100
			$_detector set noise_characteristics_file "" "string"
			
			# Unsharpness:
			$_detector set unsharpness_mode "off" "string"
				# Valid unsharpness modes:
				# "off", "basic_spatial_resolution", "mtf10freq", "mtffile"
			$_detector set basic_spatial_resolution 0.1 "mm"
			$_detector set mtf10_freq       10.0 "lp/mm"
			$_detector set mtf_file         "" "string"
			
			# Bad pixel map
			$_detector set bad_pixel_map      "" "string"
			$_detector set bad_pixel_map_type "" "string"
			
			# Scintillator
			$_detector set scintillator_material_id "" "string"
		}

		method set_from_json { jobj world stage } {
			# Import the geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the JSON file.
			set detectorGeometry [::ctsimu::extract_json_object $jobj {geometry detector}]
			$_detector set_geometry $detectorGeometry $world $stage

			# Detector properties:
			set detprops [::ctsimu::extract_json_object $jobj {detector}]

			$_detector set model        [::ctsimu::get_value $detprops {model} ""]
			$_detector set manufacturer [::ctsimu::get_value $detprops {manufacturer} ""]

			if { ![$_detector set_property type $detprops {type} "ideal"] } {
				::ctsimu::warn "Detector type not found or invalid. Should be \"ideal\" or \"real\". Using standard value: \"ideal\"."
			} else {
				# Check if the detector type is valid:
				set value [[$_detector get type] standard_value]
				if { ![::ctsimu::is_valid $value {"ideal" "real"}] } {
					::ctsimu::warn "No valid detector type: $value. Should be \"ideal\" or \"real\". Using standard value: \"ideal\"."
					$_detector set type "ideal"
				}
			}
			
			if { ![$_detector set_from_key columns $detprops {columns} 100 ""] } {
				::ctsimu::warn "Number of detector columns not found or invalid. Using standard value."
			}

			if { ![$_detector set_from_key rows $detprops {rows} 100 ""] } {
				::ctsimu::warn "Number of detector rows not found or invalid. Using standard value."
			}

			if { ![$_detector set_from_key pitch_u   $detprops {pixel_pitch u} 0.1 "mm"] } {
				::ctsimu::warn "Pixel pitch in the u direction not found or invalid. Using standard value."
			}

			if { ![$_detector set_from_key pitch_v   $detprops {pixel_pitch v} 0.1 "mm"] } {
				::ctsimu::warn "Pixel pitch in the v direction not found or invalid. Using standard value."
			}
			
			if { ![$_detector set_from_key bit_depth $detprops {bit_depth} 16 ""] } {
				::ctsimu::warn "Detector bit depth not found or invalid. Using standard value."
			}

			if { ![$_detector set_from_key integration_time $detprops {integration_time} 1 "s"] } {
				::ctsimu::warn "Detector integration time not found or invalid. Using standard value (1 s)."
			}

			$_detector set_from_key dead_time $detprops {dead_time} 1 "s"
			$_detector set_from_key image_lag $detprops {image_lag} 0.0
			
			#$_detector set gray_value_mode  "imin_imax" "string"
				# Valid gray value modes:
				# "imin_imax", "linear", "file"

			$_detector set_from_possible_keys imin $detprops {{grey_value imin} {gray_value imin}} "null"
			$_detector set_from_possible_keys imax $detprops {{grey_value imax} {gray_value imax}} "null"
			$_detector set_from_possible_keys factor $detprops {{grey_value factor} {gray_value factor}} "null"
			$_detector set_from_possible_keys offset $detprops {{grey_value offset} {gray_value offset}} "null"

			$_detector set_from_possible_keys gv_characteristics_file $detprops {{grey_value intensity_characteristics_file} {gray_value intensity_characteristics_file}} "null"

			$_detector set_from_possible_keys efficiency  $detprops {{grey_value efficiency} {gray_value efficiency}} "null"
			$_detector set_from_possible_keys efficiency_characteristics_file $detprops {{grey_value efficiency_characteristics_file} {gray_value efficiency_characteristics_file}} "null"

			
			# Noise:
			#$_detector set noise_mode       "off" "string"
				# Valid noise modes:
				# "off", "snr_at_imax", "file"
			$_detector set_from_key snr_at_imax $detprops {noise snr_at_imax} "null"
			$_detector set_from_key noise_characteristics_file $detprops {noise noise_characteristics_file} "null"
			
			# Unsharpness:
			#$_detector set unsharpness_mode "off" "string"
				# Valid unsharpness modes:
				# "off", "basic_spatial_resolution", "mtf10freq", "mtffile"

			$_detector set_from_key basic_spatial_resolution $detprops {unsharpness basic_spatial_resolution} "null"
			$_detector set_from_key mtf10_freq $detprops {unsharpness mtf10_frequency} "null"
			$_detector set_from_key mtf_file $detprops {unsharpness mtf} "null"
			
			# Bad pixel map
			$_detector set_from_key bad_pixel_map $detprops {bad_pixel_map} "null"
			$_detector set_property bad_pixel_map_type $detprops {bad_pixel_map type} "null"
			
			# Scintillator
			$_detector set_property scintillator_material_id $detprops {scintillator material_id} "null"

			::ctsimu::message "Done reading detector parameters."
		}
	}
}