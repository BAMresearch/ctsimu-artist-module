package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_material.tcl]

# A manager class for the materials of a CTSimU scenario.

namespace eval ::ctsimu {
	::oo::class create materialmanager {
		variable _materials
		variable _void

		constructor { } {
			set _materials [list]
		}

		destructor {
			foreach m $_materials {
				$m destroy
			}
		}

		method reset { } {
			# Delete all materials and reset manager to initial state.
			# The only remaining materials will be "void" and "none".
			foreach m $_materials {
				$m destroy
			}

			set _materials [list ]

			# Create a 'void' material because it is
			# the default environment material that has to
			# be available.
			set _void [::ctsimu::material new "void" "void"]
			my add_material $_void

			# Also create a 'none' material for the visual
			# stage object:
			set _none [::ctsimu::material new "none" "none"]
			my add_material $_none
		}

		method get { material_id } {
			# Get the ::ctsimu::material object that is
			# identified by the given material_id.
			foreach m $_materials {
				if { [$m id] == $material_id } {
					return $m
				}
			}

			::ctsimu::fail "Material not defined: $material_id"
		}

		method density { material_id } {
			# Get the current mass density of the material
			# that is identified by the given material_id.
			return [ [ [my get $material_id] density ] current_value ]
		}

		method composition { material_id } {
			# Get the aRTist composition string of the material
			# that is identified by the given material_id.
			return [ [my get $material_id] aRTist_composition_string ]
		}

		method aRTist_id { material_id } {
			# Get the aRTist ID for the material that is
			# identified by the given `material_id`.
			if {$material_id != "null" } {
				return [[my get $material_id] aRTist_id]
			} else {
				return "void"
			}
		}

		method add_material { m } {
			# Add a ::ctsimu::material object to the material manager.
			lappend _materials $m
		}

		method set_frame { frame nFrames } {
			# Set the current `frame` number, given a total of `nFrames`.
			# This will update all the materials listed in the material manager
			# to the given frame number and obey possible drifts.
			foreach m $_materials {
				$m set_frame $frame $nFrames
			}
		}

		method set_from_json { jsonscene } {
			# Fill the material manager from a given CTSimU scenario
			# JSON structure. The full scenario should be passed: the function
			# tries to find the `"materials"` section on its own and
			# gives an error if it cannot be found.
			my reset
			::ctsimu::status_info "Reading materials..."

			if { [::ctsimu::json_exists_and_not_null $jsonscene {materials}] } {
				if { [::ctsimu::json_type $jsonscene {materials}] == "array" } {
					set materials [::ctsimu::json_extract $jsonscene {materials}]
					::rl_json::json foreach json_material $materials {
						if { ![::ctsimu::json_isnull $json_material] } {
							set new_material [::ctsimu::material new]
							$new_material set_from_json $json_material
							my add_material $new_material
						}
					}
				} else {
					::ctsimu::warning "The materials section in the JSON file is not an array. No materials imported."
				}
			} else {
				::ctsimu::warning "JSON file does not have a materials section."
			}
		}
	}
}