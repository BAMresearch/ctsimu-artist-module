package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_materialmanager.tcl]

# A class for a filter (material id + thickness).

namespace eval ::ctsimu {
	::oo::class create filter {
		variable _material_id
		variable _thickness

		constructor { } {
			set _material_id "Fe"
			set _thickness [::ctsimu::parameter new "mm" 1.0]
		}

		destructor {
			$_thickness destroy
		}

		# General
		# ----------
		method set_frame { frame nFrames } {
			# If a value has changed, the return value will be 1.
			set value_changed [expr { [$_thickness set_frame $frame $nFrames] }]
			return $value_changed
		}

		# Getters
		# ----------
		method material_id { } {
			return $_material_id
		}
		
		method thickness { } {
			return [$_thickness current_value]
		}

		# Setters
		# ----------
		method set_material_id { mid } {
			set _material_id $mid
		}

		method set_thickness { thickness } {
			$_thickness reset
			$_thickness set_standard_value $thickness
		}

		method set_from_json { jsonobj } {
			my set_material_id [::ctsimu::get_value $jsonobj {material_id} "null"]
			if { [my material_id] == "null"} {
				::ctsimu::fail "Error setting up filter: missing material id."
			}

			if { ![$_thickness set_parameter_from_key $jsonobj {thickness}] } {
				::ctsimu::fail "Error setting up filter: thickness wrong or not specified."
			}

			puts "New filter: [my material_id], [my thickness] mm"

			my set_frame 0 1
		}
	}
}