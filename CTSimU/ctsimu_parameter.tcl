package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_drift.tcl]

# A general class to handle the drift of an arbitrary value
# for a given number of frames, including interpolation.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create parameter {
		constructor { _unit { _standard 0 } } {
			my variable standard_value
			my variable unit
			my variable drifts

			my variable current_value

			my setStandardValue $_standard
			my setUnit          $_unit
			set drifts         [list]
		}

		destructor {
			# Delete all existing drifts:
			foreach drift $drifts {
				$drift destroy
			}
		}

		method reset { } {
			my variable current_value standard_value

			# Delete all existing drifts:
			foreach drift $drifts {
				$drift destroy
			}

			set current_value $standard_value
		}

		method unit { } {
			my variable unit
			return $unit
		}

		method standard_value { } {
			my variable standard_value
			return $standard_value
		}

		method current_value { } {
			my variable current_value
			return $current_value
		}

		method setUnit { _unit } {
			my variable unit
			set unit $_unit
		}

		method setStandardValue { _standard } {
			my variable standard_value
			set standard_value $_standard
		}

		method addDrift { jsonDrift } {

		}

		method set_from_JSON { jsonParameter } {
			my reset
			my variable current_value standard_value unit drifts

			set success 0

			if { [json exists $jsonParameter value] } {
				if { ![isNull_jsonObject $jsonParameter] } {
					set standard_value [::ctsimu::in_native_unit $unit $jsonParameter]
					set success 1
				} else {
					set success 0
				}
			}

			set current_value $standard_value

			if { [json exists $jsonParameter drift] } {
				if { ![json isnull $jsonParameter drift] } {
					set jsonDrifts [::ctsimu::extractJSONobject $jsonParameter drifts]
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