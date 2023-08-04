package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_drift.tcl]

# Class for a parameter value, includes handling of parameter drifts.

namespace eval ::ctsimu {
	::oo::class create parameter {
		variable _standard_value; # value without drifts
		variable _native_unit
		variable _drifts;         # list of drift objects
		variable _current_value;  # value at current frame (obeying drifts)
		variable _value_has_changed; # parameter value changed since last frame?

		constructor { { native_unit "" } { standard 0 } } {
			# When a parameter object is constructed, it must be assigned
			# a valid native_unit to enable the JSON parser to convert the
			# drift values from the JSON file, if necessary.
			# See the documentation on native units for a
			# complete list of valid strings.
			#
			# Optionally, a standard value can be passed to the constructor.
			# The standard value is the "actual" value defined for this
			# parameter in the JSON file. If a JSON object is used to set up
			# this parameter, the standard value provided in the constructor
			# is overwritten by the value given in the JSON file.
			my set_standard_value $standard
			my set_native_unit    $native_unit
			set _drifts           [list]
			set _value_has_changed 1
		}

		destructor {
			# Delete all existing drifts:
			foreach drift $_drifts {
				$drift destroy
			}

			set _drifts [list]
		}

		method reset { } {
			# Delete all drifts and set the parameter's current value
			# to the standard value.
			foreach drift $_drifts {
				$drift destroy
			}
			set _drifts [list]

			set _value_has_changed 1
			set _current_value $_standard_value
		}

		method print { frame nFrames } {
			# Returns a human-readable string that gives information
			# about the parameter's value for the given `frame` number
			# (out of a total of `nFrames`).
			set s "Standard value: $_standard_value, Current value: $_current_value, Native unit: $_native_unit, nDrifts: [llength $_drifts]"
			foreach d $_drifts {
				append s "\n  Drift at frame $frame: [$d get_value_for_frame $frame $nFrames]"
			}

			return $s
		}

		# Getters
		# -------------------------
		method native_unit { } {
			# Get the parameter's native unit.
			return $_native_unit
		}

		method standard_value { } {
			# Get the parameter's standard value (unaffected by drifts).
			return $_standard_value
		}

		method current_value { } {
			# Get the parameter's current value.
			# Should be used after `set_frame`.
			return $_current_value
		}

		method maximum_value { nFrames { only_drifts_known_to_reconstruction 0 } } {
			# Get the maximum value during the evolution of `nFrames`,
			# given drifts.
			if { [my has_drifts] == 1 } {
				if { ($_native_unit != "string") && ($_standard_value != "null") } {
					set total_drift_max [my get_total_drift_value_for_frame 0 $nFrames $only_drifts_known_to_reconstruction]
					for {set f 1} {$f < $nFrames} {incr f} {
						set total_drift_for_frame [my get_total_drift_value_for_frame $f $nFrames $only_drifts_known_to_reconstruction]
						if { $total_drift_for_frame > $total_drift_max } {
							set total_drift_max $total_drift_for_frame
						}
					}

					return [expr $_standard_value + $total_drift_max]
				}
			}

			return $_standard_value
		}

		method minimum_value { nFrames { only_drifts_known_to_reconstruction 0 } } {
			# Get the minimum value during the evolution of `nFrames`,
			# given drifts.
			if { [my has_drifts] == 1 } {
				if { ($_native_unit != "string") && ($_standard_value != "null") } {
					set total_drift_min [my get_total_drift_value_for_frame 0 $nFrames $only_drifts_known_to_reconstruction]
					for {set f 1} {$f < $nFrames} {incr f} {
						set total_drift_for_frame [my get_total_drift_value_for_frame $f $nFrames $only_drifts_known_to_reconstruction]
						if { $total_drift_for_frame < $total_drift_min } {
							set total_drift_min $total_drift_for_frame
						}
					}

					return [expr $_standard_value + $total_drift_min]
				}
			}

			return $_standard_value
		}

		method changed { } {
			# Has the parameter changed since the last acknowledged change?
			# (See setter function `acknowledge_change`).
			# Returns `1` if true, `0` if not.
			return $_value_has_changed
		}

		method has_drifts { } {
			# Does the parameter drift? Returns `1` if yes, `0` if not.
			if { [llength $_drifts] == 0 } {
				return 0
			}

			return 1
		}

		# Setters
		# -------------------------

		method set_native_unit { native_unit } {
			# Set the parameter's native unit.
			set _native_unit $native_unit
		}

		method set_standard_value { value } {
			# Set the parameter's standard value.
			# Automatically sets the current value to the standard value.
			set _standard_value $value
			set _current_value $value
		}

		method acknowledge_change { { new_change_state 0} } {
			# Acknowledge a change of the parameter due to a drift.
			# After the acknowledgment, the function `changed`
			# will return the `new_change_state` value (standard: `0`).
			set _value_has_changed $new_change_state
		}

		# General
		# -------------------------
		method set_frame_and_get_value { frame { nFrames 1 } { only_drifts_known_to_reconstruction 0 } } {
			# Set the new frame number, return the new current value
			my set_frame $frame $nFrames $only_drifts_known_to_reconstruction
			return [my current_value]
		}

		method get_total_drift_value_for_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } } {
			# Calculates the total drift value from all drift components,
			# for the given `frame` out of a total of `nFrames`,
			# depending on whether all drifts are applied or only
			# drifts known to the reconstruction software.
			set total_drift 0

			if { $_native_unit == "string" } {
				# A string-type parameter can only be one string,
				# nothing is added, and the _drifts array should only
				# contain one element. Otherwise, the last drift is the
				# one that has precedence.
				foreach d $_drifts {
					if { $only_drifts_known_to_reconstruction == 1 } {
						if { [$d known_to_reconstruction] == 0 } {
							# Skip this drift if it is unknown to the reconstruction,
							# but we only want to obey drifts that are actually known
							# to the reconstruction...
							continue
						}
					}

					set total_drift [$d get_value_for_frame $frame $nFrames]
				}
			} else {
				# The parameter is a number-type (unitless or a valid physical unit).
				foreach d $_drifts {
					if { $only_drifts_known_to_reconstruction == 1 } {
						if { [$d known_to_reconstruction] == 0 } {
							# Skip this drift if it is unknown to the reconstruction,
							# but we only want to obey drifts that are actually known
							# to the reconstruction...
							continue
						}
					}

					# Add up all drift values for requested frame:
					set total_drift [expr { $total_drift + [$d get_value_for_frame $frame $nFrames] } ]
				}
			}

			return $total_drift
		}

		method add_drift { json_drift_obj } {
			# Generates a ctsimu::drift object
			# (from a JSON object that defines a drift)
			# and adds it to the parameter's internal list of drifts to handle.
			set d [ctsimu::drift new $_native_unit]
			$d set_from_json $json_drift_obj
			lappend _drifts $d
		}

		method set_from_json { json_parameter_object } {
			# Set up this parameter from a JSON parameter object.
			# The proper `_native_unit` must be set up correctly before
			# running this function.
			my reset
			set success 0

			if { [::ctsimu::json_type $json_parameter_object] == "number" } {
				# Parameter is given as a single number, not as a
				# parameter object (with value, unit, drift, uncertainty)
				if { [my native_unit] != "string" } {
					my set_standard_value [::ctsimu::get_value $json_parameter_object]
					set success 1
				}
			} elseif { [::ctsimu::json_type $json_parameter_object] == "string" } {
				# Parameter is given as a single string, not as a
				# parameter object (with value, unit, drift, uncertainty)
				if { [my native_unit] == "string"} {
					my set_standard_value [::ctsimu::get_value $json_parameter_object]
					set success 1
				}
			} elseif { [::ctsimu::json_type $json_parameter_object] == "boolean" } {
				# Parameter is given as a boolean. Convert to 0 or 1.
				if { [my native_unit] == "bool"} {
					my set_standard_value [::ctsimu::json_convert_to_native_unit [my native_unit] $json_parameter_object]
					set success 1
				}
			} elseif { [::ctsimu::json_type $json_parameter_object] == "object" } {
				# Parameter is hopefully a valid parameter object...

				# Value, automatically converted to parameter's native unit:
				if { [::ctsimu::json_exists_and_not_null $json_parameter_object value] } {
					if { ![::ctsimu::object_value_is_null $json_parameter_object] } {
						my set_standard_value [::ctsimu::json_convert_to_native_unit $_native_unit $json_parameter_object]
						set success 1
					} else {
						set success 0
					}
				}

				set _current_value $_standard_value

				# Drifts:
				if { [::ctsimu::json_exists_and_not_null $json_parameter_object drifts] } {
					set jsonDrifts [::ctsimu::json_extract $json_parameter_object drifts]
					set jsonType [::ctsimu::json_type $jsonDrifts]

					if {$jsonType == "array"} {
						# an array of drift objects
						::rl_json::json foreach jsonDriftObj $jsonDrifts {
							my add_drift $jsonDriftObj
						}
					} elseif {$jsonType == "object"} {
						# a single drift object (apparently)
						my add_drift $jsonDrifts
						::ctsimu::warning "Warning: invalid drift syntax. A drift should always be defined as a JSON array. Trying to interpret this drift as a single drift object."
					}
				}
			}

			return $success
		}

		method set_parameter_from_key { json_object key_sequence } {
			# Tries to find a valid parameter object at the given
			# `key_sequence` in the given `json_object`. Sets the parameter
			# if possible and returns `1` on success, `0` otherwise.
			if { [::ctsimu::json_exists_and_not_null $json_object $key_sequence] } {
				if { [my set_from_json [::ctsimu::json_extract $json_object $key_sequence]] } {
					return 1
				}
			}

			return 0
		}

		method set_parameter_from_possible_keys { json_object key_sequences } {
			# Searches the JSON object for each
			# key sequence in the given list of key_sequences.
			# The first sequence that can be found is taken
			# to set up the parameter.
			foreach keyseq $key_sequences {
				if { [my set_parameter_from_key $json_object $keyseq] } {
					# Returned succesfully, so we are done here.

					return 1
				}
			}

			return 0
		}

		method set_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } } {
			# Prepares the `current_value` for the given `frame` number
			# (assuming a total of `nFrames`). This takes into account all drifts
			# (or only the ones known to reconstruction).
			set new_value $_standard_value

			set total_drift [my get_total_drift_value_for_frame $frame $nFrames $only_drifts_known_to_reconstruction]

			if { $_native_unit == "string" } {
				if { $total_drift != 0 } {
					set new_value $total_drift
				}
			} else {
				if { $_standard_value != "null" } {
					set new_value [expr $_standard_value + $total_drift]
				}
			}

			# Check if the value has changed when compared to the previous value:
			set _value_has_changed 0
			if { $_current_value != $new_value } {
				set _value_has_changed 1
				set _current_value $new_value
			}

			# Return 1 if the parameter's value has changed, 0 if not:
			return $_value_has_changed
		}
	}
}