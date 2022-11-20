package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_stage.tcl]

# A class for the X-ray source.

namespace eval ::ctsimu {
	::oo::class create source {
		superclass ::ctsimu::part

		constructor { { name "CTSimU_Source" } { id "S" } } {
			next $name $id; # call constructor of parent class ::ctsimu::part
			my reset
		}

		destructor {
			next
		}

		method reset { } {
			# Reset to standard settings.

			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part

			# Declare all source parameters and their native units.
			# --------------------------------------------------------
			# General properties:
			my set model               ""  "string"
			my set manufacturer        ""  "string"
			my set voltage             130 "kV"
			my set current             0.1 "mA"
			#my set target_material_id  "W" "string"
			#my set type                "reflection" "string"
			#my set thickness           0   "mm"
			#my set angle_incidence     45  "deg"
			#my set angle_emission      45  "deg"			
		}

		method set_from_json { jobj stage } {
			# Import the source definition and geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file
			# (at least the geometry and source sections).
			# `stage` is the `::ctsimu::coordinate_system` that represents
			# the stage in the world coordinate system. Necessary because
			# the source could be attached to the stage coordinate system.
			my reset

			set sourceGeometry [::ctsimu::json_extract $jobj {geometry source}]
			my set_geometry $sourceGeometry $stage
			
			# Source properties:
			set sourceprops [::ctsimu::json_extract $jobj {source}]

			my set model        [::ctsimu::get_value $sourceprops {model} ""]
			my set manufacturer [::ctsimu::get_value $sourceprops {manufacturer} ""]
			
			if { ![my set_from_key voltage $sourceprops {voltage} 130] } {
				::ctsimu::warning "No voltage provided for the X-ray source. Using standard value: 130 kV."
			}
			
			if { ![my set_from_key current $sourceprops {current} 0.1] } {
				::ctsimu::warning "No current provided for the X-ray source. Using standard value: 0.1 mA."
			}

			::ctsimu::info "Done reading source parameters."
		}
	}
}