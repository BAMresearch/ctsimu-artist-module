package require TclOO
package require rl_json
package require fileutil

variable BasePath [file dirname [info script]]

# Generator function for:
# METADATA FILES

namespace eval ::ctsimu {
	proc create_metadata_file { S { run 1 } { nruns 1 } } {
		# Parameters:
		# - S: scenario object (of class ::ctsimu::scenario)
		# - run: run number
		# - nruns: total number of runs

		# A metadata file for the simulation:
		set metadata {
			{
				"file":
				{
					"name": "",
					"description": "",
					
					"contact": "",
					"date_created": "",
					"date_changed": "",
					"version": {"major": 1, "minor": 0}
				},
				
				"output":
				{
					"system": "",
					"date_measured": "",
					"projections":
					{
						"filename":   "",
						"datatype":   "",
						"byteorder":  "little",
						"headersize": null,
						
						"number": 1,
						"dimensions": {
							"x": {"value": 1000, "unit": "px"},
							"y": {"value": 1000, "unit": "px"}
						},
						"pixelsize": {
							"x": {"value": 0.1, "unit": "mm"},
							"y": {"value": 0.1, "unit": "mm"}
						},
						"dark_field": {
							"number": 0,
							"frame_average": null,
							"filename": null,
							"projections_corrected": false
						},
						"flat_field": {
							"number": 0,
							"frame_average": null,
							"filename": null,
							"projections_corrected": false
						}
					},
					"tomogram": null,
					"reconstruction": null,
					"acquisitionGeometry":
					{
						"path_to_CTSimU_JSON": ""
					}
				}
			}
		}

		set systemTime [clock seconds]
		set today [clock format $systemTime -format %Y-%m-%d]

		set aRTistVersion "unknown"
		set modulename "CTSimU"
		set moduleversion "unknown"

		if {[::ctsimu::aRTist_available]} {
			set aRTistVersion [aRTist::GetVersion]
			set moduleInfo [${::ctsimu::ctsimu_module_namespace}::Info]
			set modulename [dict get $moduleInfo Description]
			set moduleversion [dict get $moduleInfo Version]
		}

		set fileExtension ".tif"
		set headerSizeValid 0
		if {[$S get output_fileformat] == "raw"} {
			set fileExtension ".raw"
			set headerSizeValid 1
		}
		set projFilename [$S get run_output_basename]
		append projFilename "_"
		append projFilename [$S get projection_counter_format]
		append projFilename $fileExtension


		# Fill template:
		::rl_json::json set metadata file name [::rl_json::json new string [$S get run_output_basename]]

		set systemTime [clock seconds]
		set today [clock format $systemTime -format %Y-%m-%d]
		::rl_json::json set metadata file date_created [::rl_json::json new string $today]
		::rl_json::json set metadata file date_changed [::rl_json::json new string $today]

		::rl_json::json set metadata output system [::rl_json::json new string "aRTist $aRTistVersion, $modulename $moduleversion"]
		::rl_json::json set metadata output date_measured [::rl_json::json new string $today]
		::rl_json::json set metadata output projections filename [::rl_json::json new string $projFilename]
		::rl_json::json set metadata output projections datatype [::rl_json::json new string [$S get output_datatype]]

		if {$headerSizeValid==1} {
			::rl_json::json set metadata output projections headersize {{"file": 0, "image": 0}}
		}

		# Projection number and size:
		::rl_json::json set metadata output projections number [::rl_json::json new number [$S get n_projections]]
		::rl_json::json set metadata output projections dimensions x value [::rl_json::json new number [[$S detector] get columns]]
		::rl_json::json set metadata output projections dimensions y value [::rl_json::json new number [[$S detector] get rows]]
		::rl_json::json set metadata output projections pixelsize x value [::rl_json::json new number [[$S detector] get pitch_u]]
		::rl_json::json set metadata output projections pixelsize y value [::rl_json::json new number [[$S detector] get pitch_v]]

		# Dark field:
		if {[$S get n_darks] > 0} {
			::rl_json::json set metadata output projections dark_field number [::rl_json::json new number [$S get n_darks]]
			::rl_json::json set metadata output projections dark_field frame_average [::rl_json::json new number [$S get n_darks_avg]]

			set dark_filename_pattern [$S get run_output_basename]
			append dark_filename_pattern "_dark"

			if { [$S get n_darks] == 1 } {
				append dark_filename_pattern $fileExtension
				::rl_json::json set metadata output projections dark_field filename [::rl_json::json new string $dark_filename_pattern]
			} else {
				append dark_filename_pattern "_"
				append dark_filename_pattern [::ctsimu::generate_projection_counter_format [$S get n_darks]]; # something like %04d
				append dark_filename_pattern $fileExtension

				::rl_json::json set metadata output projections dark_field filename [::rl_json::json new string $dark_filename_pattern]
			}
		}

		# Flat field:
		if {[$S get n_flats] > 0} {
			::rl_json::json set metadata output projections flat_field number [::rl_json::json new number [$S get n_flats]]
			::rl_json::json set metadata output projections flat_field frame_average [::rl_json::json new number [$S get n_flats_avg]]

			set flat_filename_pattern [$S get run_output_basename]
			append flat_filename_pattern "_flat"

			if { [$S get n_flats] == 1 } {
				append flat_filename_pattern $fileExtension
				::rl_json::json set metadata output projections flat_field filename [::rl_json::json new string $flat_filename_pattern]
			} else {
				append flat_filename_pattern "_"
				append flat_filename_pattern [::ctsimu::generate_projection_counter_format [$S get n_flats]]; # something like %04d
				append flat_filename_pattern $fileExtension

				::rl_json::json set metadata output projections flat_field filename [::rl_json::json new string $flat_filename_pattern]
			}
		}

		if { [$S get ff_correction_on] } {
			::rl_json::json set metadata output projections flat_field projections_corrected [::rl_json::json new boolean 1]
		}

		# JSON filename:
		::rl_json::json set metadata output acquisitionGeometry path_to_CTSimU_JSON [::rl_json::json new string [$S get json_file_name]]

		# Write metadata file:
		set metadataFilename "[$S get run_projection_folder]/[$S get run_output_basename]_metadata.json"
		fileutil::writeFile -encoding utf-8 $metadataFilename [::rl_json::json pretty $metadata]
	}
}