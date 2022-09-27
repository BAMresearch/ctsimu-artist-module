package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_materialmanager.tcl]

# A class for a generic sample.

namespace eval ::ctsimu {
	::oo::class create sample {
		superclass ::ctsimu::part

		constructor { { name "Sample" } } {
			next $name; # call constructor of parent class ::ctsimu::part
			my reset

			my set surface_mesh_file ""       "string"
			# JSON files define relative paths to surface mesh files:
			my set surface_mesh_file_path_is_absolute 0 ""

			my set unit              "mm"     "string"
			my set scaling_factor_r  1.0      ""
			my set scaling_factor_s  1.0      ""
			my set scaling_factor_t  1.0      ""
			my set material_id       "Al"     "string"
		}

		destructor {
			next
		}

		method reset { } {
			# Reset to standard settings.

			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part
		}

		method set_from_json { jobj stageCS } {
			# Import the sample geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file
			# (at least the geometry section containing the stage definition).
			my reset

			my set_name [::ctsimu::get_value $jobj {name} "Sample"]

			# Surface mesh file:
			if { ![my set_from_key surface_mesh_file $jobj file ""] } {
				::ctsimu::fail "No surface mesh file defined for object \'[my name]\'."
			}
			if { ![my set_from_key unit $jobj unit "mm"] } {
				::ctsimu::warning "No unit of length provided for object \'[my name]\'. Using standard value: [my get unit]"
			}

			my set_from_key scaling_factor_r $jobj {scaling_factor r} 1.0
			my set_from_key scaling_factor_s $jobj {scaling_factor s} 1.0
			my set_from_key scaling_factor_t $jobj {scaling_factor t} 1.0

			if { ![my set_from_key material_id $jobj {material_id} "Fe"] } {
				::ctsimu::warning "No material id defined for object \'[my name]\'. Using standard value: [my get material_id]"
			}

			set geometry [::ctsimu::json_extract $jobj {position}]
			my set_geometry $geometry $stageCS
		}
	}
}