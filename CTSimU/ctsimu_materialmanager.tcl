package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_material.tcl]

# A class for a sample material.

namespace eval ::ctsimu {
	::oo::class create materialmanager {
		variable _materials
		variable _void

		constructor { { id 0 } { name "New_Material" } } {
			set _materials [list]
		}

		destructor {
			foreach m $_materials {
				$m destroy
			}
		}

		method reset { } {
			foreach m $_materials {
				$m destroy
			}

			set _materials [list ]

			# Create a 'void' material because it is
			# the default environment material that has to
			# be available.
			set _void [::ctsimu::material new "void" "void"]
			$_void set_density 0
			$_void set_composition {}
			my add_material $_void

			# Also create a 'none' material for the visual
			# stage object:
			set _none [::ctsimu::material new "none" "none"]
			$_none set_density 0
			$_none set_composition {}
			my add_material $_none
		}

		method get { material_id } {
			foreach m $_materials {
				if { [$m id] == $material_id } {
					return $m
				}
			}

			::ctsimu::fail "Material not defined: $material_id"
		}

		method aRTist_id { material_id } {
			return [[my get $material_id] aRTist_id]
		}

		method add_material { m } {
			lappend _materials $m
		}

		method set_frame { frame nFrames } {
			foreach m $_materials {
				$m set_frame $frame $nFrames
			}
		}

		method set_from_json { jsonscene } {
			my reset
			::ctsimu::status_info "Reading materials..."

			if { [::ctsimu::json_exists_and_not_null $jsonscene {materials}] } {
				if { [::ctsimu::json_type $jsonscene {materials}] == "array" } {
					set materials [::ctsimu::json_extract $jsonscene {materials}]
					::rl_json::json foreach json_material $materials {
						if { ![::ctsimu::json_isnull $json_material] } {
							set new_material [::ctsimu::material new]
							$new_material set_from_json $json_material
							#$new_material add_to_aRTist
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