package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_detector.tcl]

# A class for the stage.

namespace eval ::ctsimu {
	::oo::class create stage {
		superclass ::ctsimu::part

		constructor { { name "CTSimU_Stage" } } {
			next $name; # call constructor of parent class ::ctsimu::part
			my reset

			# Set the mesh file for the stage
			# from the script location and the stage.stl file:
			set meshfile "$::ctsimu::module_directory/stage.stl"
			my set surface_mesh_file $meshfile "string"

			::ctsimu::debug "Stage surface mesh file: $meshfile"
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

			set stageGeometry [::ctsimu::json_extract $jobj {geometry stage}]
			my set_geometry $stageGeometry $::ctsimu::world

			::ctsimu::info "Done reading stage parameters."
		}

		method get_sample_copy { } {
			# Create a sample object from this stage
			# for the sample manager, to show it as
			# an object in aRTist's virtual scene.

			set stage_as_sample [::ctsimu::sample new "Stage"]
			$stage_as_sample attach_to_stage 1
			
			# Prepare scene vectors for the stage sample.
			# As it is attached to the stage, we simply need to
			# create standard basis vectors:
			set center [::ctsimu::scenevector new "mm"]
			set u      [::ctsimu::scenevector new]
			set w      [::ctsimu::scenevector new]
			$center set_reference "local"
			$u set_reference "local"
			$w set_reference "local"

			$center set_simple 0 0 0
			$u set_simple 1 0 0
			$w set_simple 0 0 1

			$stage_as_sample set_center $center
			$stage_as_sample set_u $u
			$stage_as_sample set_w $w

			$stage_as_sample set material_id "none"
			$stage_as_sample set surface_mesh_file [my get surface_mesh_file]
			$stage_as_sample set surface_mesh_file_path_is_absolute 1

			return $stage_as_sample
		}
	}
}