package require TclOO
package require fileutil
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_part.tcl]

# A class for the detector.

namespace eval ::ctsimu {
	::oo::class create detector {
		constructor { } {
			# The ::ctsimu::part that represents the detector:
			my variable _detector
			set _detector [::ctsimu::part new "Detector"]
			
			my reset
		}

		destructor {
			my variable _detector
			$_detector destroy
		}

		method reset { } {
			my variable _detector
			
			# Standard settings:
			
			$_detector reset
			$_detector attach_to_stage 0
			
			# General properties:
			$_detector set model            "" "string"
			$_detector set manufacturer     "" "string"
			$_detector set type             "ideal" "string"
			$_detector set columns          1000
			$_detector set rows             1000
			$_detector set pitch_u          0.1 "mm"
			$_detector set pitch_v          0.1 "mm"
			$_detector set bit_depth        16
			$_detector set integration_time 0.5 "s"
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
			my variable _detector
			
			# Import the geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the JSON file.
			set detectorGeometry [::ctsimu::extract_json_object $jobj {geometry detector}]

			$_detector set_geometry $detectorGeometry $world $stage
			
			
		}
	}
}