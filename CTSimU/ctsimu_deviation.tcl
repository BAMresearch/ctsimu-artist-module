package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_parameter.tcl]

namespace eval ::ctsimu {
	namespace import ::rl_json::*
	
	set valid_axes [list z y x w v u t s r]
	set valid_axis_strings [list "r" "s" "t" "u" "v" "w" "x" "y" "z"]

	::oo::class create deviation {
		# A class for a geometrical deviation
		# of a coordinate system, i.e. a translation
		# or a rotation with respect to one of the
		# axes x, y, z (world), u, v, w (local),
		# or r, s, t (sample).
		#
		# Like any parameter, they can have drifts,
		# which means they can change over time.
		
		constructor { } {
			my variable _type;  # "rotation" or "translation"
			my variable _axis
			my variable _amount
			my variable _known_to_reconstruction
			
			set _amount [::ctsimu::parameter new]
		}

		destructor {
			my variable _amount
			$_amount destroy
		}

		method reset { } {
			# Delete all drifts and set the parameter's current value to the standard value.
			my variable _amount _type _axis
			$_amount destroy

			my set_type ""
			my set_axis ""
			my set_known_to_reconstruction 1
		}
		
		# Getters
		# -------------------------
		method type { } {
			# Get the transformation type ("rotation" or "translation").
			my variable _type
			return $_type
		}		

		method axis { } {
			# Get the transformation axis.
			my variable _axis
			return $_axis
		}
		
		method amount { } {
			# Amount of the deviation.
			my variable _amount
			return $_amount
		}
		
		method known_to_reconstruction { } {
			# Returns whether this deviation must be considered during a
			# reconstruction (1) or not (0). This parameter is used
			# when calculating projection matrices.
			my variable _known_to_reconstruction
			return $_known_to_reconstruction
		}

		# Setters
		# -------------------------
		method set_type { type } {
			# Sets the transformation type ("rotation" or "translation").
			my variable _type _amount
			
			if { ($type == "rotation") || ($type == "translation") } {
				set _type $type

				# Set the correct native unit for the amount:
				if { $type == "rotation" } {
					$_amount set_unit "rad"
				} elseif { $type == "translation" } {
					$_amount set_unit "mm"
				}
			} else {
				error "$type is not a valid deviation type. Valid types are: \"rotation\" and \"translation\"."
			}
		}

		method set_axis { axis } {
			# Sets the deviation's transformation axis.
			# Can be: "x", "y", "z", "u", "v", "w", "r", "s", "t"
			my variable _axis
			
			if { [lsearch -exact $::ctsimu::valid_axis_strings $axis] >= 0 } {
				set _axis $axis
			} else {
				error "$axis is not a valid axis designation. Possible designations are: {$::ctsimu::valid_axis_strings}."
			}
		}
		
		method set_known_to_reconstruction { known } {
			# Sets the "known to reconstruction" attribute to
			# true (known = 1) or false (known = 0).
			my variable _known_to_reconstruction
			set _known_to_reconstruction $known
		}
		
		method set_amount_from_json { json_obj } {
			# Set the deviation's amount from a JSON object, which
			# is a parameter with a value and potentially a drift.
			# 
			# This function is usually not called from the outside,
			# but used by `set_from_json`.
			my variable _amount
			$_amount set_from_json $json_obj
		}
		
		method set_from_json { json_obj } {
			# Set up the deviation from a JSON deviation structure.
			if { [json exists $json_obj type] } {
				my set_type [::ctsimu::get_value $json_obj type ""]
			} else {
				error "A deviation must provide a \"type\": either \"rotation\" or \"translation\"."
				return 0
			}
			
			if { [json exists $json_obj axis] } {
				my set_axis [::ctsimu::get_value $json_obj axis]
			} else {
				error "A deviation must provide an \"axis\": any of {$::ctsimu::valid_axis_strings}"
				return 0
			}
			
			my set_amount_from_json [::ctsimu::extract_json_object $json_obj amount]
			my set_known_to_reconstruction [::ctsimu::get_value_in_unit "bool" $json_obj known_to_reconstruction 1]
			
			return 1
		}
	}
}