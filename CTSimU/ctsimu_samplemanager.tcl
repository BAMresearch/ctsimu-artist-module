package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_source.tcl]

# The sample manager keeps the samples of the scene together.

namespace eval ::ctsimu {
	::oo::class create samplemanager {
		variable _samples

		constructor { } {
			# An empty list to keep the parts:
			set _samples [list ]
		}

		destructor {
			my reset
		}

		method reset { } {
			# Delete all managed parts and empty the list:
			foreach s $_samples {
				$s destroy
			}
			set _samples [list ]
		}

		method add_sample { s } {
			# Give the new sample an id:
			$s set_id [expr [llength $_samples]+1]
			lappend _samples $s
		}

		method set_frame { stageCS frame nFrames } {
			# Set current frame number (propagates to samples).
			foreach s $_samples {
				$s set_frame $stageCS $frame $nFrames
			}
		}

		method update_scene { } {
			# Move objects in scene to match current frame number.
			::ctsimu::status_info "Placing objects..."
			foreach s $_samples {
				$s place_in_scene $stageCS
			}
		}

		method load_meshes { stageCS } {
			# Loads the mesh file of each part into aRTist.
			::ctsimu::status_info "Loading surface meshes..."
			
			if { [::ctsimu::aRTist_available] } {
				# Clear current part list: 
				::PartList::Clear
			}

			foreach s $_samples {
				if { [::ctsimu::aRTist_available] } {
					$s set_id [::PartList::LoadPart [$s get surface_mesh_file] "Fe" [$s name] yes]
				}

				$s place_in_scene $stageCS
			}
		}		
	}
}