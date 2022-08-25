package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_matrix.tcl]

namespace eval ::ctsimu {
	namespace import ::rl_json::*
	
	# Checkers for valid JSON data
	# -----------------------------

	proc value_is_null { value } {
		# Checks if a specific value is set to `null`.
		if {$value == "null"} {
			return 1
		}

		return 0
	}

	proc value_is_null_or_zero { value } {
		# Checks if a specific value is set to `null` or zero.
		if {($value == 0) || ($value == 0.0) || ($value == "null")} {
			return 1
		}

		return 0
	}

	proc object_value_is_null { json_obj } {
		# Checks if a JSON object has a `value` parameter
		# and if this parameter is set to `null` or the string "null".
		if [json exists $json_obj value] {
			if [json isnull $json_obj value] {
				return 1
			}

			# If the value is not set to `null`,
			# still check if it is set to the string "null":
			set value [json get $json_obj value]
			return [value_is_null $value]
		}
		
		return 1
	}

	proc object_value_is_null_or_zero { json_obj } {
		# Checks if a JSON object has a `value` parameter
		# and if this parameter is set to `null` or zero.
		if [object_value_is_null $json_obj] {
			return 1
		}

		# At this point the value exists and it is not `null`.
		# Check if it is 0:
		set value [json get $json_obj value]
		return [value_is_null_or_zero $value]
	}

	# Getters
	# -----------------------------

	proc get_value { sceneDict keys } {
		# Get the specific value of the parameter that is located
		# at the given sequence of `keys` in the JSON dictionary.
		if [json exists $sceneDict {*}$keys] {
			if { [json get $sceneDict {*}$keys] != "" } {
				return [json get $sceneDict {*}$keys]
			}
		}

		return "null"
	}

	proc extract_json_object { sceneDict keys } {
		# Get the JSON sub-object that is located
		# by a given sequence of `keys` in the JSON dictionary.
		if [json exists $sceneDict {*}$keys] {
			return [json extract $sceneDict {*}$keys]
		}

		return "null"
	}

	# Unit Conversion
	# -----------------------------
	# Unit conversion functions take a JSON object that must
	# contain a `value` and a `unit`. Each function supports
	# the allowed units from the CTSimU file format specification.

	proc in_mm { value unit } {
		# Converts a length to mm.
		if {$value != "null"} {
			switch $unit {
				"nm" {return [expr $value * 1e-6]}
				"um" {return [expr $value * 1e-3]}
				"mm" {return $value}
				"cm" {return [expr $value * 10]}
				"dm" {return [expr $value * 100]}
				"m"  {return [expr $value * 1000]}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit of length: \'$unit\'"
	}

	proc in_rad { value unit } {
		# Converts an angle to radians.
		if {$value != "null"} {
			switch $unit {
				"deg" {return [::Math::DegToRad $value]}
				"rad" {return $value}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit for an angle: \'$unit\'"
	}

	proc in_deg { value unit } {
		# Converts an angle to degrees.
		if {$value != "null"} {
			switch $unit {
				"deg" {return $value}
				"rad" {return [::Math::RadToDeg $value]}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit for an angle: \'$unit\'"
	}

	proc in_s { value unit } {
		# Converts a time to seconds.
		if {$value != "null"} {
			switch $unit {
				"ms"  {return [expr $value * 1e-3]}
				"s"   {return $value}
				"min" {return [expr $value * 60]}
				"h"   {return [expr $value * 3600]}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit of time: \'$unit\'"
	}

	proc in_mA { value unit } {
		# Converts a current to mA.
		if {$value != "null"} {
			switch $unit {
				"uA" {return [expr $value * 1e-3]}
				"mA" {return $value}
				"A"  {return [expr $value * 1000]}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit of current: \'$unit\'"
	}

	proc in_kV { value unit } {
		# Converts a voltage to kV.
		if {$value != "null"} {
			switch $unit {
				"V"  {return [expr $value * 1e-3]}
				"kV" {return $value}
				"MV" {return [expr $value * 1000]}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit of voltage: \'$unit\'"
	}

	proc in_g_per_cm3 { value unit } {
		# Converts a mass density to g/cm³.
		if {$value != "null"} {
			switch $unit {
				"kg/m^3" {return [expr $value * 1e-3]}
				"g/cm^3" {return $value}
			}
		} else {
			return "null"
		}

		fail "Not a valid unit of density: \'$unit\'"
	}

	proc from_bool { value } {
		# Converts true to 1 and false to 0.
		switch $value {
			true  {return 1}
			false {return 0}
		}

		return $value
	}

	proc convert_SNR_FWHM { SNR_or_FWHM intensity } {
		# Converts between SNR and Gaussian FWHM for a given intensity
		# (i.e., more generally, the given distribution's mean value).
		return [expr 2.0*sqrt(2.0*log(2.0))*double($intensity)/double($SNR_or_FWHM) ]
	}

	proc convert_to_native_unit { given_unit native_unit value } {
		# Check which native unit is requested, convert value accordingly.
		if { $native_unit == "" } {
			return $value
		} elseif { $native_unit == "string" } {
			return $value; # this is a string in this case, e.g. spectrum file
		} else {
			if { $native_unit == "mm" } {
				# internal lengths are always in mm
				return [::ctsimu::in_mm $value $unit]
			} elseif { $native_unit == "s" } {
				# internal time durations are always in s
				return [::ctsimu::in_s $value $unit]
			} elseif { $native_unit == "deg" } {
				return [::ctsimu::in_deg $value $unit]
			} elseif { $native_unit == "rad" } {
				return [::ctsimu::in_rad $value $unit]
			} elseif { $native_unit == "mA" } {
				# internal currents are always in mA
				return [::ctsimu::in_mA $value $unit]
			} elseif { $native_unit == "kV" } {
				# internal voltages are always in kV
				return [::ctsimu::in_kV $value $unit]
			} elseif { $native_unit == "g/cm^3" } {
				# internal mass densities are always in g/cm^3
				return [::ctsimu::in_g_per_cm3 $value $unit]
			} elseif { $native_unit == "bool" } {
				return [::ctsimu::from_bool $value]
			}
		}

		fail "Native unit $native_unit is incompatible with the given unit $given_unit."
		return 0
	}

	proc json_convert_to_native_unit { native_unit value_and_unit } {
		# Like the previous function `convert_to_native_unit`, but takes
		# a JSON object `value_and_unit` that must contain a `value` and
		# an associated `unit`.
		# Checks which native unit is requested, converts
		# JSON `value` accordingly.
		if { $native_unit == "" } {
			return [::ctsimu::get_value $value_and_unit value]
		}

		if { [json exists $value_and_unit value] && [json exists $value_and_unit unit] } {
			set value [json get $value_and_unit value]
			set unit  [json get $value_and_unit unit]

			return [::ctsimu::convert_to_native_unit $unit $native_unit $value]
		} else {
			fail "Trying to convert a value to $native_unit, but no value+unit pair is provided from JSON object."
		}
	}

	proc json_get { native_unit sceneDict keys } {
		# Takes a sequence of JSON keys from the given dictionary where
		# a JSON object with a value/unit pair must be located.
		# Returns the value of this JSON object in the requested native_unit.
		set value_unit_pair [extract_json_object $sceneDict $keys]
		if {![object_value_is_null_or_zero $value_unit_pair]} {
			return [::ctsimu::json_convert_to_native_unit $native_unit $value_unit_pair]
		}

		return "null"
	}
}