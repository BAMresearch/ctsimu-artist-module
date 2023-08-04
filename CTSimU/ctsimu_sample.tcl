package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_filter.tcl]

# A class for a generic sample. Inherits from ::ctsimu::part.

namespace eval ::ctsimu {
	::oo::class create sample {
		superclass ::ctsimu::part

		constructor { { name "Sample" } } {
			next $name; # call constructor of parent class ::ctsimu::part
			my reset

			my set surface_mesh_file          ""       "string"
			my set currently_loaded_mesh_file "" "string"
			# JSON files define relative paths to surface mesh files:
			my set surface_mesh_file_path_is_absolute 0 ""

			my set unit              "mm"     "string"
			my set scaling_factor_r  1.0      ""
			my set scaling_factor_s  1.0      ""
			my set scaling_factor_t  1.0      ""
			my set material_id       "Al"     "string"

			# The original mesh sizes are set by the sample manager
			# after loading the surface mesh file:
			my set original_physical_size_r  0.0      "mm"
			my set original_physical_size_s  0.0      "mm"
			my set original_physical_size_t  0.0      "mm"
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
			# Import the sample geometry from the JSON sample object.
			# The `stageCS` must be given as a `::ctsimu::coordinate_system` object.
			# If this part is not attached to the stage,
			# the `$::ctsimu::world` coordinate system can be passed instead.
			my reset
			my set_name [::ctsimu::get_value $jobj {name} "Sample"]

			set geometry [::ctsimu::json_extract $jobj {position}]
			my set_geometry $geometry $stageCS

			# Surface mesh file:
			if { ![my set_parameter_from_key surface_mesh_file $jobj file ""] } {
				::ctsimu::fail "No surface mesh file defined for object \'[my name]\'."
			}
			if { ![my set_parameter_from_key unit $jobj unit "mm"] } {
				::ctsimu::warning "No unit of length provided for object \'[my name]\'. Using standard value: [my get unit]"
			}

			if { ![my set_parameter_from_key scaling_factor_r $jobj {scaling_factor r} 1.0 ""] } {
				::ctsimu::warning "Scaling factor r for sample [my name] not found or invalid. Using standard value."
			}

			if { ![my set_parameter_from_key scaling_factor_s $jobj {scaling_factor s} 1.0 ""] } {
				::ctsimu::warning "Scaling factor s for sample [my name] not found or invalid. Using standard value."
			}

			if { ![my set_parameter_from_key scaling_factor_t $jobj {scaling_factor t} 1.0 ""] } {
				::ctsimu::warning "Scaling factor t for sample [my name] not found or invalid. Using standard value."
			}

			if { ![my set_parameter_from_key material_id $jobj {material_id} "Fe"] } {
				::ctsimu::warning "No material id defined for object \'[my name]\'. Using standard value: [my get material_id]"
			}
		}

		method load_mesh_file { material_manager } {
			# Load the sample's mesh file into aRTist.
			# The scenario's ::ctsimu::materialmanager must be passed as an argument.
			set meshfile [my get surface_mesh_file]

			if { ![my get surface_mesh_file_path_is_absolute] } {
				# If the surface mesh location is a relative path,
				# the location of the JSON file needs to be appended
				# in front:
				set meshfile [::ctsimu::get_absolute_path [my get surface_mesh_file]]
			}

			set material_id [ [ $material_manager get [my get material_id] ] aRTist_id ]
			if { [::ctsimu::aRTist_available] } {
				my set_id [::PartList::LoadPart $meshfile "$material_id" "[my name]" yes]

				# Set the original object size:
				set objectSize [::PartList::Invoke [my id] GetSize]
				my set original_physical_size_r [lindex $objectSize 0]
				my set original_physical_size_s [lindex $objectSize 1]
				my set original_physical_size_t [lindex $objectSize 2]
			}

			my set currently_loaded_mesh_file [my get surface_mesh_file]
		}

		method update_mesh_file { material_manager } {
			# Check if the mesh file has changed (due to drifts) and update it if necessary.
			if { [my get currently_loaded_mesh_file] != [my get surface_mesh_file] } {
				if { [::ctsimu::aRTist_available] } {
					# Replace part by deleting it from the part list
					# and loading the new mesh file.
					# We cannot use ::PartList::ReplacePart because then
					# we couldn't get the original physical size of the new STL file.
					set objectSize [::PartList::Delete [my id]]
					my load_mesh_file $material_manager
				}
			}
		}

		method update_scaling_factor { } {
			# Update the sample size to match the current frame's
			# scaling factor for the object.
			set sizeR [expr [my get original_physical_size_r] * [my get scaling_factor_r]]
			set sizeS [expr [my get original_physical_size_s] * [my get scaling_factor_s]]
			set sizeT [expr [my get original_physical_size_t] * [my get scaling_factor_t]]

			# Additional resizing based on the unit of the mesh file.
			# aRTist assumes mm.
			set u [my get unit]
			set scaler 1
			if { $u == "mm" } {
				# Good. Do nothing.
			} elseif { $u == "m" } {
				set scaler 1000
			} elseif { $u == "dm" } {
				set scaler 100
			} elseif { $u == "cm" } {
				set scaler 10
			} elseif { $u == "um" } {
				set scaler 1e-3
			} elseif { $u == "nm" } {
				set scaler 1e-6
			}

			if { $scaler != 1 } {
				set sizeR [expr $sizeR * $scaler]
				set sizeS [expr $sizeS * $scaler]
				set sizeT [expr $sizeT * $scaler]
			}

			if { [::ctsimu::aRTist_available] } {
				::PartList::Invoke [my id] SetSize $sizeR $sizeS $sizeT
			}
		}
	}
}