package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_drift.tcl]

# A general class to handle the drift of an arbitrary value
# for a given number of frames, including interpolation.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create parameter {
		constructor { unit { standard 0 } } {
			my variable _standard_value
			my variable _unit
			my variable _drifts

			my variable _current_value

			my set_standard_value $standard
			my set_unit           $unit
			set _drifts           [list]
		}

		destructor {
			# Delete all existing drifts:
			my variable _drifts
			foreach drift $_drifts {
				$drift destroy
			}
		}

		method reset { } {
			my variable _current_value _standard_value _drifts

			# Delete all existing drifts:
			foreach drift $_drifts {
				$drift destroy
			}

			set _current_value $_standard_value
		}

		method unit { } {
			my variable _unit
			return $_unit
		}

		method standard_value { } {
			my variable _standard_value
			return $_standard_value
		}

		method current_value { } {
			my variable _current_value
			return $_current_value
		}

		method set_unit { unit } {
			my variable _unit
			set _unit $unit
		}

		method set_standard_value { value } {
			my variable _standard_value
			set _standard_value $value
		}

		method add_drift { json_drift } {

		}

		method set_from_json { jsonParameter } {
			my reset
			my variable _current_value _standard_value _unit _drifts

			set success 0

			if { [json exists $jsonParameter value] } {
				if { ![object_value_is_null $jsonParameter] } {
					my set_standard_value [::ctsimu::in_native_unit $_unit $jsonParameter]
					set success 1
				} else {
					set success 0
				}
			}

			set _current_value $_standard_value

			if { [json exists $jsonParameter drift] } {
				if { ![json isnull $jsonParameter drift] } {
					set jsonDrifts [::ctsimu::extract_json_object $jsonParameter drifts]
					set jsonType [json type $jsonDrifts]

					if {$jsonType == "array"} {
						# an array of drift objects
						json foreach drift $jsonDrifts {
						}
					} elseif {$jsonType == "object"} {
						# a single drift object (apparently)
						warning "Warning: invalid drift syntax. A drift should always be defined as a JSON array. Trying to interpret this drift as a single drift object."
					}
				}
			}
	
			return $success
		}
	}
}