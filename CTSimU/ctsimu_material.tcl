package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_part.tcl]

# A class for a sample material.

namespace eval ::ctsimu {
	::oo::class create material {
		variable _id
		variable _name
		variable _density
		variable _composition

		constructor { { id 0 } { name "New_Material" } } {
			my set_id $id
			my set_name $name

			set _density [::ctsimu::parameter new "g/cm^3"]
			set _composition [::ctsimu::parameter new "string" "Fe"]
		}

		destructor {
			$_density destroy
			$_composition destroy
		}

		# General
		# ----------
		method add_to_aRTist { } {
			if { ([my aRTist_id] != "void") && ([my aRTist_id] != "none") } {
				set values [dict create]
				dict set values density [$_density current_value]
				dict set values composition [$_composition current_value]
				dict set values comment [my name]

				if { [::ctsimu::aRTist_available] } {
					dict set ::Materials::MatList [my aRTist_id] $values
				}
			}
		}

		method set_frame { frame nFrames { forced 0 } } {
			# Return a bitwise OR of both return values.
			# If a value has changed, the return value will be 1.
			set value_changed [expr { [$_density set_frame $frame $nFrames] || \
			                          [$_composition set_frame $frame $nFrames] }]

			# Update aRTist materials list if value has changed:
			if { $value_changed || $forced } {
			    my add_to_aRTist
			}

			return $value_changed
		}

		# Getters
		# ----------
		method id { } {
			return $_id
		}

		method aRTist_id { } {
			# The material id for the aRTist material manager.
			# Add 'CTSimU' as prefix to avoid overwriting existing materials.

			if { ($_id != "void") && ($_id != "none") } {
				# Check density and return "void" if density is not >0:
				if { [[my density] current_value] <= 0} {
					return "void"
				}

				return "CTSimU_[my id]"
			}
			
			# Material is "void" or "none":
			return [my id]
		}

		method name { } {
			return $_name
		}

		method density { } {
			return $_density
		} 

		method composition { } {
			return $_composition
		}

		# Setters
		# ----------
		method set_id { id } {
			set _id $id
		}

		method set_name { name } {
			set _name $name
		}

		method set_density { density } {
			# Set simple numerical value for density.
			$_density reset
			$_density set_standard_value $density
		}

		method set_composition { composition } {
			# Set simple standard value for composition.
			$_composition reset
			$_composition set_standard_value $composition
		}

		method set_from_json { jsonobj } {
			my set_id [::ctsimu::get_value $jsonobj {id} "null"]
			if { [my id] == "null"} {
				::ctsimu::fail "Error reading material: missing id."
			}

			my set_name [::ctsimu::get_value $jsonobj {name} "null"]
			if { [my name] == "null"} {
				::ctsimu::fail "Error reading material: missing name."
			}

			if { ![$_density set_parameter_from_key $jsonobj {density}] } {
				::ctsimu::fail "Error reading density of material [my id] ([my name])."
			}

			if { ![$_composition set_parameter_from_key $jsonobj {composition}] } {
				::ctsimu::fail "Error reading composition of material [my id] ([my name])."
			}

			my set_frame 0 1 1
		}
	}
}