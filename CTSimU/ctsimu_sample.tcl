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
			my set unit              "mm"     "string"
			my set scaling_factor_r  1.0      ""
			my set scaling_factor_s  1.0      ""
			my set scaling_factor_t  1.0      ""
			my set material_id       "Al"     ""
		}

		destructor {
			next
		}

		method reset { } {
			# Reset to standard settings.

			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part
		}

		method set_from_json { jobj  stageCS} {
			# Import the sample geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file
			# (at least the geometry section containing the stage definition).
			my reset

			set geometry [::ctsimu::json_extract $jobj {position}]
			my set_geometry $geometry $stageCS
		}
	}
}