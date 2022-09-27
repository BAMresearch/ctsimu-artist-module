package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_scenevector.tcl]

# A class for a geometrical deviation
# of a coordinate system, i.e. a translation
# or a rotation with respect to one of the
# axes x, y, z (world), u, v, w (local),
# or r, s, t (sample) or any other arbitrary vector.
#
# Like any parameter, they can have drifts,
# which means they can change over time.

namespace eval ::ctsimu {
	set valid_axes [list z y x w v u t s r]
	set valid_axis_strings [list "r" "s" "t" "u" "v" "w" "x" "y" "z"]
	set valid_world_axis_designations [list "x" "y" "z"]
	set valid_local_axis_designations [list "u" "v" "w"]
	set valid_sample_axis_designations [list "r" "s" "t"]

	::oo::class create deviation {
		variable _type;  # "rotation" or "translation"
		variable _axis;  # rotation axis or translation direction
		variable _pivot; # pivot point for rotations
		variable _amount
		variable _known_to_reconstruction

		constructor { { native_unit "" } } {			
			# The axis and pivot point are ::ctsimu::scenevector
			# objects that can handle vector drifts and
			# conversion between coordinate systems:
			set _axis   [::ctsimu::scenevector new]
			set _pivot  [::ctsimu::scenevector new "mm"]
			$_pivot set_simple 0 0 0
			$_pivot set_reference "local"
			
			# The transformation amount is a
			# ::ctsimu::parameter that can handle drifts.
			set _amount [::ctsimu::parameter new $native_unit]
		}

		destructor {
			$_axis destroy
			$_pivot destroy
			$_amount destroy
		}

		method reset { } {
			# Delete all drifts and set the parameter's current value to the standard value.
			$_amount destroy

			my set_type ""
			my set_axis ""
			my set_known_to_reconstruction 1
		}
		
		# Getters
		# -------------------------
		method type { } {
			# Get the transformation type ("rotation" or "translation").
			return $_type
		}		

		method axis { } {
			# Get the transformation axis.
			return $_axis
		}
		
		method pivot { } {
			# Get the pivot point.
			return $_pivot
		}
		
		method amount { } {
			# Amount of the deviation.
			return $_amount
		}
		
		method native_unit { } {
			# Returns the native unit of the deviation's amount.
			return [$_amount native_unit]
		}
		
		method known_to_reconstruction { } {
			# Returns whether this deviation must be considered during a
			# reconstruction (1) or not (0). This parameter is used
			# when calculating projection matrices.
			return $_known_to_reconstruction
		}

		# Setters
		# -------------------------
		method set_type { type } {
			# Sets the transformation type ("rotation" or "translation").
			if { ($type == "rotation") || ($type == "translation") } {
				set _type $type

				# Set the correct native unit for the amount:
				if { $type == "rotation" } {
					::ctsimu::info "Setting deviation amount native unit to rad."
					$_amount set_native_unit "rad"
				} elseif { $type == "translation" } {
					::ctsimu::info "Setting deviation amount native unit to mm."
					$_amount set_native_unit "mm"
				}
			} else {
				::ctsimu::fail "$type is not a valid deviation type. Valid types are: \"rotation\" and \"translation\"."
			}
		}

		method set_axis { axis } {
			# Sets the deviation's transformation axis.
			# Can be: "x", "y", "z", "u", "v", "w", "r", "s", "t"
			# or a ::ctsimu::scenevector.
			if { [::ctsimu::is_valid $axis $::ctsimu::valid_world_axis_designations] == 1 } {
				# Given axis is "x", "y" or "z"
				# -> vector in world coordinate system
				$_axis set_reference "world"
				if { $axis == "x" } { $_axis set_simple 1 0 0 }
				if { $axis == "y" } { $_axis set_simple 0 1 0 }
				if { $axis == "z" } { $_axis set_simple 0 0 1 }
			} elseif { [::ctsimu::is_valid $axis $::ctsimu::valid_local_axis_designations] == 1 } {
				# Given axis is "u", "v" or "w"
				# -> vector in local coordinate system
				$_axis set_reference "local"
				if { $axis == "u" } { $_axis set_simple 1 0 0 }
				if { $axis == "v" } { $_axis set_simple 0 1 0 }
				if { $axis == "w" } { $_axis set_simple 0 0 1 }
			} elseif { [::ctsimu::is_valid $axis $::ctsimu::valid_sample_axis_designations] == 1 } {
				# Given axis is "r", "s" or "t"
				# -> vector in sample coordinate system
				$_axis set_reference "sample"
				if { $axis == "r" } { $_axis set_simple 1 0 0 }
				if { $axis == "s" } { $_axis set_simple 0 1 0 }
				if { $axis == "t" } { $_axis set_simple 0 0 1 }
			} else {
				# Axis object should be a ::ctsimu::scenevector
				set _axis $axis
			}
		}
		
		method set_pivot { pivot } {
			# Set the pivot point for rotations.
			# Expects a ::ctsimu::scenevector.
			$_pivot destroy
			set _pivot pivot
		}
		
		method set_known_to_reconstruction { known } {
			# Sets the "known to reconstruction" attribute to
			# true (known = 1) or false (known = 0).
			set _known_to_reconstruction $known
		}
		
		method set_amount_from_json { json_obj } {
			# Set the deviation's amount from a JSON object, which
			# is a parameter with a value and potentially a drift.
			# 
			# This function is usually not called from the outside,
			# but used by `set_from_json`.
			$_amount set_from_json $json_obj
		}
		
		method set_from_json { json_obj } {
			# Set up the deviation from a JSON deviation structure.
			if { [::ctsimu::json_exists_and_not_null $json_obj type] } {
				my set_type [::ctsimu::get_value $json_obj {type} ""]

				if { [my type] == "translation" } {
					$_amount set_native_unit "mm"
				} elseif { [my type] == "rotation" } {
					$_amount set_native_unit "rad"
				} else {
					::ctsimu::fail "Invalid deviation type: [my type]. Must be \"rotation\" or \"translation\"."
				}
			} else {
				::ctsimu::fail "A deviation must provide a \"type\": either \"rotation\" or \"translation\"."
				return 0
			}
			
			# Transformation axis:
			if { [::ctsimu::json_exists_and_not_null $json_obj axis] } {
				if { [::ctsimu::json_type $json_obj axis] == "string" } {
					set axis [::ctsimu::get_value $json_obj {axis}]
					if { [::ctsimu::is_valid $axis $::ctsimu::valid_axis_strings] == 1 } {
						my set_axis $axis
					} else {
						::ctsimu::fail "The deviation \"axis\" string is incorrect: must be any of {$::ctsimu::valid_axis_strings} or a free vector definition."
						return 0
					}
				} elseif { [::ctsimu::json_type $json_obj axis] == "object" } {
					# free vector definition
					if { [$_axis set_from_json [::ctsimu::json_extract $json_obj {axis}]] } {
						# Success
					} else {
						::ctsimu::fail "::ctsimu::fail setting up deviation axis from JSON file. Vector definition seems to be incorrect."
						return 0
					}
				} else {
					::ctsimu::fail "::ctsimu::fail setting up deviation axis from JSON file."
					return 0
				}
			} else {
				::ctsimu::fail "A deviation must provide an \"axis\": any of {$::ctsimu::valid_axis_strings}"
				return 0
			}
			
			# Pivot point for rotations.
			# Set a standard pivot which refers to the object's center:
			$_pivot set_simple 0 0 0
			$_pivot set_reference [$_axis reference]
			if { [::ctsimu::json_exists_and_not_null $json_obj pivot] } {
				# If another pivot is defined in the
				# JSON file, take this one instead...
				if { [$_pivot set_from_json [::ctsimu::json_extract $json_obj {pivot}]] } {
					# Success
				} else {
					::ctsimu::fail "::ctsimu::fail setting up deviation's pivot point from JSON file. Vector definition seems to be incorrect."
					return 0
				}
			}
			
			my set_amount_from_json [::ctsimu::json_extract $json_obj {amount}]
			my set_known_to_reconstruction [::ctsimu::get_value_in_unit "bool" $json_obj {known_to_reconstruction} 1]
			
			return 1
		}
	}
}