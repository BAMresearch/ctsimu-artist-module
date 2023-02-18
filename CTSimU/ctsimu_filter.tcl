package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_materialmanager.tcl]

# A class for a filter (material id + thickness).

namespace eval ::ctsimu {
	::oo::class create filter {
		variable _material_id
		variable _thickness

		constructor { { material_id "Fe" } { thickness 1.0 } } {
			set _material_id $material_id
			set _thickness [::ctsimu::parameter new "mm" $thickness]
		}

		destructor {
			$_thickness destroy
		}

		# General
		# ----------
		method set_frame { frame nFrames } {
			# Prepares the thickness parameter for the given
			# `frame` number (out of a total of `nFrames`).
			# Handles possible drifts.

			# If a value has changed, the return value will be 1.
			set value_changed [expr { [$_thickness set_frame $frame $nFrames] }]
			return $value_changed
		}

		# Getters
		# ----------
		method material_id { } {
			# ID of the material for the filter, as referenced in the JSON file.
			return $_material_id
		}

		method thickness { } {
			# Current filter thickness in mm.
			return [$_thickness current_value]
		}

		# Setters
		# ----------
		method set_material_id { mat_id } {
			set _material_id $mat_id
		}

		method set_thickness { thickness } {
			$_thickness reset
			$_thickness set_standard_value $thickness
		}

		method set_from_json { jsonobj } {
			# Sets the filter properties from a given JSON filter object.

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