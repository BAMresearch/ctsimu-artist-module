package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_scenario.tcl]

# Class for a batch job.

namespace eval ::ctsimu {
	::oo::class create batchjob {
		variable _properties

		constructor { } {
			my set id                 0
			my set status             "Pending"
			my set runs               1
			my set start_run          1
			my set start_proj_nr      0
			my set json_file          ""
			my set output_fileformat  "tiff"
			my set output_datatype    "uint16"
			my set output_folder      ""
			my set output_basename    "proj_"
		}

		destructor {

		}

		# Getters
		# -------------------------
		method get { property } {
			# Returns the value for a given `property`.
			return [dict get $_properties $property]
		}

		method format_string { } {
			set formatString "RAW "
			if { [my get output_fileformat] == "tiff" } {
				set formatString "TIFF "
			}

			if { [my get output_datatype] == "float32" } {
				append formatString "float32"
			} else {
				append formatString "uint16"
			}

			return $formatString
		}
		
		# Setters
		# -------------------------
		method set { property value } {
			# Set a settings value in the settings dict
			dict set _properties $property $value
		}

		method set_format { format_string } {
			# Converts a batch format string to individual 
			# output_fileformat and output_datatype.
			switch $format_string {
				"RAW float32" {
					my set output_fileformat "raw"
					my set output_datatype "float32"
				}
				"RAW uint16" {
					my set output_fileformat "raw"
					my set output_datatype "uint16"
				}
				"TIFF float32" {
					my set output_fileformat "tiff"
					my set output_datatype "float32"
				}
				"TIFF uint16" {
					my set output_fileformat "tiff"
					my set output_datatype "uint16"
				}
			}
		}

		method set_from_json { jsonfile } {
			my set json_file $jsonfile

			# Set output basename and folder:
			my set output_basename [file rootname [file tail $jsonfile]]

			set json_file_directory [file dirname "$jsonfile"]
			set folder $json_file_directory
			append folder "/"
			append folder [my get output_basename]
			my set output_folder $folder
		}
	}
}