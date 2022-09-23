package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_detector.tcl]

# A class for the stage.

namespace eval ::ctsimu {
	::oo::class create stage {
		superclass ::ctsimu::part

		constructor { { name "Stage" } } {
			next $name; # call constructor of parent class ::ctsimu::part
			my reset
		}

		destructor {
			next
		}

		method reset { } {
			# Reset to standard settings.

			# Reset the '::ctsimu::part' that handles the coordinate system:
			next; # call reset of parent class ::ctsimu::part
		}

		method set_from_json { jobj } {
			# Import the stage geometry from the JSON object.
			# The JSON object should contain the complete content
			# from the scenario definition file
			# (at least the geometry section containing the stage definition).
			my reset

			set stageGeometry [::ctsimu::extract_json_object $jobj {geometry stage}]
			my set_geometry $stageGeometry $::ctsimu::world

			::ctsimu::note "Done reading stage parameters."
		}
	}
}