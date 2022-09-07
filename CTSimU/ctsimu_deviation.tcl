package require TclOO
package require rl_json

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
	set valid_stage_axis_designations [list "u" "v" "w"]
	set valid_sample_axis_designations [list "r" "s" "t"]

	::oo::class create deviation {
		constructor { } {
			my variable _type;  # "rotation" or "translation"
			my variable _axis;  # rotation axis or translation direction
			my variable _pivot; # pivot point for rotations
			my variable _amount
			my variable _known_to_reconstruction
			
			# The axis and pivot point are ::ctsimu::scenevector
			# objects that can handle vector drifts and
			# conversion between coordinate systems:
			set _axis   [::ctsimu::scenevector new]
			set _pivot  [::ctsimu::scenevector new "mm"]
			
			# The transformation amount is a
			# ::ctsimu::parameter that can handle drifts.
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
		
		method pivot { } {
			# Get the pivot point.
			my variable _pivot
			return $_pivot
		}
		
		method amount { } {
			# Amount of the deviation.
			my variable _amount
			return $_amount
		}
		
		method native_unit { } {
			# Returns the native unit of the deviation's amount.
			my variable _amount
			return [$_amount native_unit]
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
					$_amount set_native_unit "rad"
				} elseif { $type == "translation" } {
					$_amount set_native_unit "mm"
				}
			} else {
				error "$type is not a valid deviation type. Valid types are: \"rotation\" and \"translation\"."
			}
		}

		method set_axis { axis } {
			# Sets the deviation's transformation axis.
			# Can be: "x", "y", "z", "u", "v", "w", "r", "s", "t"
			# or a ::ctsimu::scenevector.
			my variable _axis
			
			if { [lsearch -exact $::ctsimu::valid_world_axis_designations $axis] >= 0 } {
				# Given axis is "x", "y" or "z"
				# -> vector in world coordinate system
				$_axis set_reference "world"
				if { $axis == "x" } { $_axis set_simple 1 0 0 }
				if { $axis == "y" } { $_axis set_simple 0 1 0 }
				if { $axis == "z" } { $_axis set_simple 0 0 1 }
			} elseif { [lsearch -exact $::ctsimu::valid_stage_axis_designations $axis] >= 0 } {
				# Given axis is "u", "v" or "w"
				# -> vector in local coordinate system
				$_axis set_reference "local"
				if { $axis == "u" } { $_axis set_simple 1 0 0 }
				if { $axis == "v" } { $_axis set_simple 0 1 0 }
				if { $axis == "w" } { $_axis set_simple 0 0 1 }
			} elseif { [lsearch -exact $::ctsimu::valid_sample_axis_designations $axis] >= 0 } {
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
			my variable _pivot
			set _pivot pivot
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
			my variable _axis _pivot
			
			# Set up the deviation from a JSON deviation structure.
			if { [::ctsimu::json_exists $json_obj type] } {
				my set_type [::ctsimu::get_value $json_obj {type} ""]
			} else {
				error "A deviation must provide a \"type\": either \"rotation\" or \"translation\"."
				return 0
			}
			
			# Transformation axis:
			if { [::ctsimu::json_exists $json_obj axis] } {
				if { [::ctsimu::json_type $json_obj axis] == "string" } {
					set axis [::ctsimu::get_value $json_obj {axis}]
					if { [lsearch -exact $::ctsimu::valid_axis_strings $axis] >= 0 } {
						my set_axis $axis
					} else {
						error "The deviation \"axis\" string is incorrect: must be any of {$::ctsimu::valid_axis_strings} or a free vector definition."
						return 0
					}
				} elseif { [::ctsimu::json_type $json_obj axis] == "object" } {
					# free vector definition
					if { [$_axis set_from_json [::ctsimu::extract_json_object $json_obj {axis}]] } {
						# Success
					} else {
						error "Error setting up deviation axis from JSON file. Vector definition seems to be incorrect."
						return 0
					}
				} else {
					error "Error setting up deviation axis from JSON file."
					return 0
				}
			} else {
				error "A deviation must provide an \"axis\": any of {$::ctsimu::valid_axis_strings}"
				return 0
			}
			
			# Pivot point for rotations.
			# Set a standard pivot which refers to the object's center:
			$_pivot set_simple 0 0 0
			$_pivot set_reference [$_axis reference]
			if { [::ctsimu::json_exists $json_obj pivot] } {
				# If another pivot is defined in the
				# JSON file, take this one instead...
				if { [$_pivot set_from_json [::ctsimu::extract_json_object $json_obj {pivot}]] } {
					# Success
				} else {
					error "Error setting up deviation's pivot point from JSON file. Vector definition seems to be incorrect."
					return 0
				}
			}
			
			my set_amount_from_json [::ctsimu::extract_json_object $json_obj {amount}]
			my set_known_to_reconstruction [::ctsimu::get_value_in_unit "bool" $json_obj {known_to_reconstruction} 1]
			
			return 1
		}
	}
}