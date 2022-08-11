package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_matrix.tcl]

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	proc isNull_value { value } {
		if {$value == "null"} {
			return 1
		}

		return 0
	}

	proc isNullOrZero_value { value } {
		if {($value == 0) || ($value == 0.0) || ($value == "null")} {
			return 1
		}

		return 0
	}

	proc isNull_jsonObject { value } {
		if [json exists $value value] {
			if [json isnull $value value] {
				return 1
			}

			set value [json get $value value]
		} else {
			return 1
		}

		return [isNull_value $value]
	}

	proc isNullOrZero_jsonObject { value } {
		if [isNull_jsonObject $value] {
			return 1
		}

		return [isNullOrZero_value $value]
	}


	proc getValue { sceneDict keys } {
		if [json exists $sceneDict {*}$keys] {
			if { [json get $sceneDict {*}$keys] != "" } {
				return [json get $sceneDict {*}$keys]
			}
		}

		return "null"
	}

	proc extractJSONobject { sceneDict keys } {
		if [json exists $sceneDict {*}$keys] {
			return [json extract $sceneDict {*}$keys]
		}

		return "null"
	}

	proc in_mm { valueAndUnit } {
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

	proc in_rad { valueAndUnit } {
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

	proc in_deg { valueAndUnit } {
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

	proc in_s { valueAndUnit } {
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

	proc in_mA { valueAndUnit } {
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

	proc in_kV { valueAndUnit } {
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

	proc in_g_per_cm3 { valueAndUnit } {
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
		switch $value {
			true  {return 1}
			false {return 0}
		}

		return $value
	}

	proc convert_to_native_unit { givenUnit nativeUnit value }
		# Check what native unit is, convert JSON value accordingly.
		if { $nativeUnit == "" } {
			return $value
		} else {
			if { $nativeUnit == "mm" } {
				# internal lengths are always in mm
				return [::ctsimu::in_mm $value $unit]
			} elseif { $nativeUnit == "s" } {
				# internal time durations are always in s
				return [::ctsimu::in_s $value $unit]
			} elseif { $nativeUnit == "deg" } {
				return [::ctsimu::in_deg $value $unit]
			} elseif { $nativeUnit == "rad" } {
				return [::ctsimu::in_rad $value $unit]
			} elseif { $nativeUnit == "mA" } {
				# internal currents are always in mA
				return [::ctsimu::in_mA $value $unit]
			} elseif { $nativeUnit == "kV" } {
				# internal currents are always in mA
				return [::ctsimu::in_kV $value $unit]
			} elseif { $nativeUnit == "g/cm^3" } {
				# internal mass densities are always in g/cm^3
				return [::ctsimu::in_g_per_cm3 $value $unit]
			} elseif { $nativeUnit == "bool" } {
				return [::ctsimu::from_bool [::ctsimu::getValue $value $unit]]
			}
		}

		fail "Native unit $nativeUnit is incompatible with the given JSON value/unit pair."
		return 0
	}

	proc json_convert_to_native_unit { nativeUnit valueAndUnit } {
		if { $nativeUnit == "" } {
			return [::ctsimu::getValue $valueAndUnit value]
		}

		if { [json exists $valueAndUnit value] && [json exists $valueAndUnit unit] } {
			set value [json get $valueAndUnit value]
			set unit  [json get $valueAndUnit unit]

			return [::ctsimu::convert_to_native_unit $unit $nativeUnit $value]
		} else {
			fail "Trying to convert a value to $nativeUnit, but no value+unit pair is provided from JSON object."
		}
	}

	proc json_get { nativeUnit sceneDict keys } {
		set value_unit_pair [extractJSONobject $sceneDict $keys]
		if {![isNullOrZero_jsonObject $value_unit_pair]} {
			return [::ctsimu::json_convert_to_native_unit $nativeUnit $value_unit_pair]
		}

		return "null"
	}

	proc convertSNR_FWHM { snrOrFWHM intensity } {
		return [expr 2*sqrt(2*log(2))*$intensity/$snrOrFWHM ]
	}
}