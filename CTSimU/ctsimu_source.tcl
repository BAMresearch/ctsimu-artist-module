package require TclOO
package require fileutil

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_stage.tcl]

# A class for the X-ray source.

namespace eval ::ctsimu {
	::oo::class create source {
		superclass ::ctsimu::part

		constructor { { name "Source" } { id "S" } } {
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
			my set model            "" "string"
			my set manufacturer     "" "string"		
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

			::ctsimu::note "Done reading source parameters."
		}
	}
}