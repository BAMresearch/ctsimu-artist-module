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

		method update_scene { stageCS } {
			# Move objects in scene to match current frame number.
			::ctsimu::status_info "Placing objects..."
			foreach s $_samples {
				$s place_in_scene $stageCS
				::ctsimu::info "CS [$s name]:"
				::ctsimu::info [[$s current_coordinate_system] print]
			}
		}

		method set_from_json { jsonscene stageCS } {
			::ctsimu::status_info "Reading sample information..."

			if { [::ctsimu::json_exists_and_not_null $jsonscene {samples}] } {
				if { [::ctsimu::json_type $jsonscene {samples}] == "array" } {
					set samples [::ctsimu::json_extract $jsonscene {samples}]
					::rl_json::json foreach json_sample $samples {
						if { ![::ctsimu::json_isnull $json_sample] } {
							set new_sample [::ctsimu::sample new]
							$new_sample set_from_json $json_sample $stageCS
							my add_sample $new_sample
						}
					}
				} else {
					::ctsimu::fail "The samples section in the JSON file is not an array."
				}
			} else {
				::ctsimu::fail "JSON file does not have a samples section."
			}
		}

		method load_meshes { stageCS jsondir material_manager } {
			# Loads the mesh file of each part into aRTist.
			::ctsimu::status_info "Loading surface meshes..."
			
			if { [::ctsimu::aRTist_available] } {
				# Clear current part list:
				::PartList::Clear

				# Samples must be centered at (0, 0, 0) after loading:
				set ::aRTist::LoadCentered 1
			}

			foreach s $_samples {
				set meshfile [$s get surface_mesh_file]
				::ctsimu::info "[$s name]: [$s get surface_mesh_file_path_is_absolute]"
				if { ![$s get surface_mesh_file_path_is_absolute] } {
					# If the surface mesh location is a relative path,
					# the location of the JSON file need to be appended
					# in front:
					set meshfile $jsondir
					append meshfile "/[$s get surface_mesh_file]"
					puts "Meshfile: $meshfile"
				}

				set material_id [ [ $material_manager get [$s get material_id] ] aRTist_id ]
				if { [::ctsimu::aRTist_available] } {
					$s set_id [::PartList::LoadPart $meshfile "$material_id" "[$s name]" yes]
				}

				$s place_in_scene $stageCS
			}
		}		
	}
}