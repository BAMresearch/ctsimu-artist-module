package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	set pi 3.1415926535897931
	set ctsimu_module_namespace 0

	proc module_directory { } {
		# Returns the script directory
		return [ file dirname [ file normalize [ info script ] ] ]
	}

	proc aRTist_available { } {
		return [namespace exists ::aRTist]
	}

	proc set_module_namespace { ns } {
		# Store reference to aRTist module namespace
		# in ctsimu namespace, so that the modulemain.tcl
		# can be accessed (used to show GUI status messages).
		set ::ctsimu::ctsimu_module_namespace $ns
	}

	proc status_info {  message } {
		# Shows a status message in the GUI of the aRTist module
		if { [::ctsimu::aRTist_available] } {
			if { $::ctsimu::ctsimu_module_namespace != 0} {
				${::ctsimu::ctsimu_module_namespace}::showInfo $message
				::ctsimu::note $message
			} else {
				::ctsimu::warn "aRTist module namespace not available."
			}
		}
	}

	proc fail { message } {
		# Handles error messages.
		if { [::ctsimu::aRTist_available] } {
			::aRTist::Error { $message }
		}

		error $message
	}

	proc warn { message } {
		# Handles warning messages.
		if { [::ctsimu::aRTist_available] } {
			::aRTist::Warning { $message }
		} else  {
			puts "Warning: $message"
		}
	}

	proc note { message } {
		# Handles information messages.
		if { [::ctsimu::aRTist_available] } {
			::aRTist::Info { $message }
		} else {
			puts "$message"
		}
	}

	proc debug { message } {
		# Handles debug messages.
		if { [::ctsimu::aRTist_available] } {
			::aRTist::Debug { $message }
		} else {
			puts "$message"
		}
	}

	proc is_valid { value valid_list } {
		# Checks if `value` is an item in the list
		# of valid values: `valid_list`.
		if { [lsearch -exact $valid_list $value] >= 0 } {
			return 1
		}

		return 0
	}
	
	proc read_json_file { filename } {
		# Read JSON file, check its validity.

		# Newer version of rl_json supports decoding
		# and validity check:
		if { [catch {
			# Open file in byte mode, use rl_json to decode using utf-8:
			set jf [open $filename rb]
			try {
				set jsonstring [json decode [read $jf] utf-8]
			} finally {
				close $jf
			}
		} err ] } {
			# [json decode] probably doesn't exist.
			# Use old import method and skip validity check
			# (it doesn't exist as well).
			set jf [open $filename r]
			try {
				fconfigure $jf -encoding utf-8
				set jsonstring [read $jf]
			} finally {
				close $jf
			}

			::ctsimu::debug "Old JSON import method."
			return $jsonstring
		}

		# Check for syntax errors, find error position.
		if { [json valid -details errordetails $jsonstring] != 1 } {
			# Get error line number:
			set errpos [dict get $errordetails char_ofs]
			set char_counter 0
			set line_counter 0
			set errline 0
			foreach line [split $jsonstring "\n"] {
				incr line_counter
				set char_counter [expr $char_counter + [string length $line] + 1]
				if { $char_counter >= $errpos} {
					set errline $line_counter
					break
				}
			}

			::ctsimu::fail "Syntax Error in JSON file at character position $errpos (around line $errline). [dict get $errordetails errmsg]. Try opening the JSON file in Firefox to find the mistake. Maybe a comma too much? File: $filename"
		}

		::ctsimu::debug "New JSON import method."
		return $jsonstring
	}

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
	proc get_value { dictionary keys {fail_value 0} } {
		# Get the specific value of the parameter that is located
		# at the given sequence of `keys` in the JSON dictionary.
		if [json exists $dictionary {*}$keys] {
			if { [json get $dictionary {*}$keys] != "" } {
				return [json get $dictionary {*}$keys]
			}
		}

		return $fail_value
	}
	
	proc json_exists { dictionary keys } {
		return [json exists $dictionary {*}$keys]
	}
	
	proc json_type { dictionary { keys {} } } {
		return [json type [json extract $dictionary {*}$keys]]
	}
	
	proc json_isnull { dictionary keys } {
		return [json isnull $dictionary {*}$keys]
	}

	proc json_extract { dictionary keys } {
		# Get the JSON sub-object that is located
		# by a given sequence of `keys` in the JSON dictionary.
		if [json exists $dictionary {*}$keys] {
			return [json extract $dictionary {*}$keys]
		}

		return "null"
	}
	
	proc json_extract_from_possible_keys { dictionary key_sequences } {
		# Searches the JSON object for each
		# key sequence in the given list of key_sequences.
		# The first sequence that exists will
		# return an extracted JSON object.
		foreach keys $key_sequences {
			if [json exists $dictionary {*}$keys] {
				return [json extract $dictionary {*}$keys]
			}
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

		::ctsimu::fail "Not a valid unit of length: \'$unit\'"
	}

	proc in_rad { value { unit "deg" } } {
		# Converts an angle to radians.
		if {$value != "null"} {
			switch $unit {
				"deg" {return [expr double($value) * $::ctsimu::pi / 180.0]}
				"rad" {return $value}
			}
		} else {
			return "null"
		}

		::ctsimu::fail "Not a valid unit for an angle: \'$unit\'"
	}

	proc in_deg { value { unit "rad" } } {
		# Converts an angle to degrees.
		if {$value != "null"} {
			switch $unit {
				"deg" {return $value}
				"rad" {return [expr double($value) * 180.0 / $::ctsimu::pi]}
			}
		} else {
			return "null"
		}

		::ctsimu::fail "Not a valid unit for an angle: \'$unit\'"
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

		::ctsimu::fail "Not a valid unit of time: \'$unit\'"
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

		::ctsimu::fail "Not a valid unit of current: \'$unit\'"
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

		::ctsimu::fail "Not a valid unit of voltage: \'$unit\'"
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

		::ctsimu::fail "Not a valid unit of density: \'$unit\'"
	}
	
	proc in_lp_per_mm { value unit } {
		# Converts a resolution to line pairs per millimeter.
		if {$value != "null"} {
			switch $unit {
				"lp/mm" {return $value}
				"lp/cm" {return [expr $value * 0.1]}
				"lp/dm" {return [expr $value * 0.01]}
				"lp/m"  {return [expr $value * 0.001]}
			}
		} else {
			return "null"
		}

		::ctsimu::fail "Not a valid unit for resolution: \'$unit\'"
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
			return $value; # this is a string, e.g. spectrum file
		} else {
			if { $native_unit == "mm" } {
				# internal lengths are always in mm
				return [::ctsimu::in_mm $value $given_unit]
			} elseif { $native_unit == "s" } {
				# internal time durations are always in s
				return [::ctsimu::in_s $value $given_unit]
			} elseif { $native_unit == "deg" } {
				return [::ctsimu::in_deg $value $given_unit]
			} elseif { $native_unit == "rad" } {
				return [::ctsimu::in_rad $value $given_unit]
			} elseif { $native_unit == "mA" } {
				# internal currents are always in mA
				return [::ctsimu::in_mA $value $given_unit]
			} elseif { $native_unit == "kV" } {
				# internal voltages are always in kV
				return [::ctsimu::in_kV $value $given_unit]
			} elseif { $native_unit == "g/cm^3" } {
				# internal mass densities are always in g/cm^3
				return [::ctsimu::in_g_per_cm3 $value $given_unit]
			} elseif { $native_unit == "lp/mm" } {
				# internal resolution (or MTF frequency) is in lp/mm
				return [::ctsimu::in_lp_per_mm $value $given_unit]
			} elseif { $native_unit == "bool" } {
				return [::ctsimu::from_bool $value]
			}
		}

		::ctsimu::fail "Native unit $native_unit is incompatible with the given unit $given_unit."
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
		} elseif { $native_unit == "bool" } {
			# This is not a value/unit pair.
			# Only convert bool $value to 1 or 0.
			return [::ctsimu::from_bool $value_and_unit]
		} elseif { $native_unit == "string" } {
			if { ![json exists $value_and_unit value] } {
				# This is already a string, not embedded in
				# a value/unit pair.
				return $value_and_unit
			}			
		}

		if { [json exists $value_and_unit value] } {
			set value [json get $value_and_unit value]
			set unit ""
			if { [json exists $value_and_unit unit] } {
				# The unit does not necessarily have to exist.
				# For example, in the case of strings it is clear
				# just from the native unit.
				set unit  [json get $value_and_unit unit]
			}

			return [::ctsimu::convert_to_native_unit $unit $native_unit $value]
		} else {
			::ctsimu::fail "Trying to convert a value to $native_unit, but no value+unit pair is provided from JSON object."
		}
	}

	proc get_value_in_unit { native_unit dictionary keys {fail_value 0} } {
		# Takes a sequence of JSON keys from the given dictionary where
		# a JSON object with a value/unit pair must be located.
		# Returns the value of this JSON object in the requested native_unit.
		set value_unit_pair [::ctsimu::json_extract $dictionary $keys]
		if {![::ctsimu::object_value_is_null_or_zero $value_unit_pair]} {
			return [::ctsimu::json_convert_to_native_unit $native_unit $value_unit_pair]
		}

		return $fail_value
	}
}