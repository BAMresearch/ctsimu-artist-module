package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_drift.tcl]

# Class for a parameter value, includes handling of parameter drifts.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create parameter {
		constructor { { native_unit "" } { standard 0 } } {
			my variable _standard_value
			my variable _native_unit
			my variable _drifts

			my variable _current_value

			my set_standard_value $standard
			my set_native_unit    $native_unit
			set _drifts           [list]
		}

		destructor {
			# Delete all existing drifts:
			my variable _drifts
			foreach drift $_drifts {
				$drift destroy
			}
			
			set _drifts [list]
		}

		method reset { } {
			# Delete all drifts and set the parameter's current value to the standard value.
			my variable _current_value _standard_value _drifts

			# Delete all existing drifts:
			foreach drift $_drifts {
				$drift destroy
			}

			set _current_value $_standard_value
		}

		# Getters
		# -------------------------
		method native_unit { } {
			# Get the parameter's native unit.
			my variable _native_unit
			return $_native_unit
		}

		method standard_value { } {
			# Get the parameter's standard value (unaffected by drifts).
			my variable _standard_value
			return $_standard_value
		}

		method current_value { } {
			# Get the parameter's current value.
			# Should be used after `set_frame`.
			my variable _current_value
			return $_current_value
		}

		# Setters
		# -------------------------

		method set_native_unit { native_unit } {
			# Set the parameter's native unit.
			my variable _native_unit
			set _native_unit $native_unit
		}

		method set_standard_value { value } {
			# Set the parameter's standard value.
			my variable _standard_value
			set _standard_value $value
		}

		# General
		# -------------------------
		method get_value_for_frame { frame { nFrames 1 } { only_drifts_known_to_reconstruction 0 } } {
			# Set the new frame number, return current value
			my set_frame $frame $nFrames $only_drifts_known_to_reconstruction
			return [my current_value]
		}

		method get_total_drift_value_for_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } } {
			my variable _current_value _standard_value _drifts _native_unit
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
					set total_drift [expr $total_drift + [$d get_value_for_frame $frame $nFrames]]
				}
			}

			return $total_drift
		}

		method add_drift { json_drift_obj } {
			# Generates a ctsimu::drift object
			# (from a JSON object that defines a drift)
			# and adds it to its internal list of drifts to handle.
			my variable _native_unit _drifts
			set d [ctsimu::drift new $_native_unit]
			$d set_from_json $json_drift_obj
			lappend _drifts $d
		}

		method set_from_json { json_parameter_object } {
			# Set up this parameter from a JSON parameter object.
			# The proper `_native_unit` must be set up correctly before
			# running this function.
			my reset
			my variable _current_value _standard_value _native_unit _drifts

			set success 0

			# Value, automatically converted to parameter's native unit:
			if { [json exists $json_parameter_object value] } {
				if { ![object_value_is_null $json_parameter_object] } {
					my set_standard_value [::ctsimu::in_native_unit $_native_unit $json_parameter_object]
					set success 1
				} else {
					set success 0
				}
			}

			set _current_value $_standard_value

			# Drifts:
			if { [json exists $json_parameter_object drift] } {
				if { ![json isnull $json_parameter_object drift] } {
					set jsonDrifts [::ctsimu::extract_json_object $json_parameter_object drifts]
					set jsonType [json type $jsonDrifts]

					if {$jsonType == "array"} {
						# an array of drift objects
						json foreach jsonDriftObj $jsonDrifts {
							my add_drift $jsonDriftObj
						}
					} elseif {$jsonType == "object"} {
						# a single drift object (apparently)
						my add_drift $jsonDrifts
						warning "Warning: invalid drift syntax. A drift should always be defined as a JSON array. Trying to interpret this drift as a single drift object."
					}
				}
			}
	
			return $success
		}

		method set_from_key { json_object key_sequence } {
			if { [json exists $json_object $key_sequence] } {
				if { [my set_from_json [json extract $json_object $key_sequence]] } {
					return 1
				}
			}

			return 0
		}

		method set_from_possible_keys { json_object key_sequences } {
			# Searches the JSON object for each
			# key sequence in the given list of key_sequences.
			# The first sequence that matches is taken
			# for the parameter.
			foreach keyseq $key_sequences {
				if { [my set_from_key $json_object $keyseq] } {
					# Returned succesfully, so we can finish this...

					return 1
				}
			}

			return 0
		}

		method set_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } } {
			my variable _current_value _standard_value _native_unit
			set new_value $_standard_value

			set total_drift [my get_total_drift_value_for_frame $frame $nFrames $only_drifts_known_to_reconstruction]

			if { $_native_unit == "string" } {
				set new_value $total_drift
			} else {
				set new_value [expr $new_value + $total_drift]
			}

			# Check if the value has changed when compared to the previous value:
			set value_has_changed 0
			if { $_current_value != $new_value } {
				set value_has_changed 1
				set _current_value $new_value
			}

			# Return 1 if the parameter's value has changed, 0 if not:
			return $value_has_changed
		}
	}
}