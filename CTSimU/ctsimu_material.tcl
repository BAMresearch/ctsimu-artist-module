package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_part.tcl]

# A class for a material component: formula and mass fraction

namespace eval ::ctsimu {
	::oo::class create material_component {
		variable _formula
		variable _mass_fraction
		variable _parent_material_id
		variable _parent_material_name

		constructor { parent_material_id parent_material_name { formula "Fe" } { mass_fraction 1 } } {
			set _parent_material_id $parent_material_id
			set _parent_material_name $parent_material_name
			set _formula    [::ctsimu::parameter new "string" $formula]
			set _mass_fraction [::ctsimu::parameter new ""       $mass_fraction]
		}

		destructor {
			$_formula destroy
			$_mass_fraction destroy
		}

		# General
		# ----------

		method set_frame { frame nFrames { forced 0 } } {
			set value_changed [expr { [$_formula set_frame $frame $nFrames] || \
			                          [$_mass_fraction set_frame $frame $nFrames] }]

			return $value_changed
		}

		# Getters
		# ----------

		method formula { } {
			return [$_formula current_value]
		}

		method mass_fraction { } {
			return [$_mass_fraction current_value]
		}

		# Setters
		# ----------

		method set_from_json { jsonobj } {
			if { ![$_formula set_parameter_from_key $jsonobj {formula}] } {
				::ctsimu::fail "Error reading a formula for material $_parent_material_id ($_parent_material_name)."
			}

			if { ![$_mass_fraction set_parameter_from_key $jsonobj {mass_fraction}] } {
				::ctsimu::fail "Error reading a mass fraction for material $_parent_material_id ($_parent_material_name)."
			}

			my set_frame 0 1 1
		}

		method set_from_json_legacy { jsonobj } {
			# Legacy composition definition for file format version <=1.0.
			# The composition was simply a string value, no mass fraction was defined.
			if { ![$_formula set_parameter_from_key $jsonobj {composition}] } {
				::ctsimu::fail "Error reading a composition for material $_parent_material_id ($_parent_material_name)."
			}

			$_mass_fraction reset
			$_mass_fraction set_standard_value 1

			my set_frame 0 1 1
		}
	}


# A class for a sample material.
	::oo::class create material {
		variable _id
		variable _name
		variable _density
		variable _composition
		variable _aRTist_composition_string

		constructor { { id 0 } { name "New_Material" } } {
			my set_id $id
			my set_name $name
			set _aRTist_composition_string ""

			set _density [::ctsimu::parameter new "g/cm^3"]
			set _composition [list ]
		}

		destructor {
			$_density destroy
			foreach component $_composition {
				$component destroy
			}
		}

		method reset { } {
			set _aRTist_composition_string ""

			$_density reset
			$_density set_standard_value 0.0
			foreach component $_composition {
				$component destroy
			}
			set _composition [list ]
		}

		# General
		# ----------
		method add_to_aRTist { } {
			if { ([my aRTist_id] != "void") && ([my aRTist_id] != "none") } {
				set values [dict create]
				dict set values density [$_density current_value]
				dict set values composition [my aRTist_composition_string]
				dict set values comment [my name]

				if { [::ctsimu::aRTist_available] } {
					dict set ::Materials::MatList [my aRTist_id] $values
					::Engine::ClearMaterials
				}
			}
		}

		method set_frame { frame nFrames { forced 0 } } {
			# Return a bitwise OR of all return values.
			# If any of the values has changed, the result will be 1.
			set density_changed [$_density set_frame $frame $nFrames $forced]

			set composition_changed 0
			foreach component $_composition {
				set composition_changed [expr { $composition_changed || [$component set_frame $frame $nFrames $forced] }]
			}

			if { $composition_changed || $forced } {
				my generate_aRTist_composition_string
			}

			set value_changed [expr ($density_changed || $composition_changed)]

			# Update aRTist materials list if a value has changed:
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

		method aRTist_composition_string { } {
			return $_aRTist_composition_string
		}

		method generate_aRTist_composition_string { } {
			# Generate the composition string for aRTist.

			# Check if all mass fractions are equal. In this case, we can
			# omit mass fractions in the composition string.
			set mass_fractions_in_composition_string 0
			set mass_fraction_sum 0; # sum of all mass fractions
			if { [llength $_composition] > 1 } {
				# More than one component?

				# Remember mass fraction of first component and
				# compare it to other components.
				set first_mass_fraction [[lindex $_composition 0] mass_fraction]

				# Calculate sum of all mass fractions (for later normalization)
				# and check if all mass fractions are equal (in this case, we do not need them).
				foreach component $_composition {
					set mass_fraction_sum [expr $mass_fraction_sum + [$component mass_fraction]]
					if { [$component mass_fraction] != $first_mass_fraction } {
						set mass_fractions_in_composition_string 1
					}
				}
			}

			if { $mass_fraction_sum == 0 } {
				# Avoid division by zero
				set mass_fraction_sum 1
			}

			# Create a composition string for aRTist:
			set _aRTist_composition_string ""
			set i 0
			foreach component $_composition {
				if { $i > 0 } {
					append _aRTist_composition_string " "
				}

				append _aRTist_composition_string [$component formula]

				if { $mass_fractions_in_composition_string == 1 } {
					append _aRTist_composition_string " [expr double([$component mass_fraction]) / double($mass_fraction_sum)]"
				}

				incr i
			}

			return $_aRTist_composition_string
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

		method add_component { component } {
			lappend _composition $component
		}

		method set_from_json { jsonobj } {
			my reset

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

			if { [::ctsimu::json_exists_and_not_null $jsonobj {composition}] } {
				# The composition should be an array since file format version 1.1:
				if { [::ctsimu::json_type $jsonobj {composition}] == "array" } {
					set components [::ctsimu::json_extract $jsonobj {composition}]
					::rl_json::json foreach json_component $components {
						set new_component [::ctsimu::material_component new [my id] [my name]]
						$new_component set_from_json $json_component
						my add_component $new_component
					}
				} else {
					# Probably legacy definition: composition given as single string.
					set new_component [::ctsimu::material_component new [my id] [my name]]
					$new_component set_from_json_legacy $jsonobj
					my add_component $new_component
				}
			} else {
				::ctsimu::fail "Error reading composition of material [my id] ([my name])."
			}

			my set_frame 0 1 1
		}
	}
}