# ::ctsimu::helpers
Helper functions and variables, especially for handling CTSimU JSON objects via the `rl_json` extension, as well as unit conversions and other types of conversions. These functions and variables are available directly under the `::ctsimu` namespace.

## Variables

* `pi` — `3.1415926535897931`
* `ctsimu_module_namespace` — Namespace of the CTSimU module in aRTist. Should be set from aRTist when loading the module using `::ctsimu::set_module_namespace`.
* `module_directory` — The script directory (to access files inside the module package).
* `json_path` — Absolute path to the currently loaded JSON file. Usually set by a [`::ctsimu::scenario`](scenario.md) when a JSON scenario is loaded.

## Functions

### General

* `aRTist_available` — To check whether the `aRTist` namespace is available.
* `set_module_namespace { ns }` — Store reference to aRTist module namespace in `ctsimu` namespace, so that the `modulemain.tcl` can be accessed. Used to show GUI status messages.
* `set_module_directory { dir }` — Set the absolute directory path of the CTSimU module (in aRTist).
* `set_json_path { jsonpath }` — Set the absolute path to the currently loaded JSON file, so that `get_absolute_path` can return the absolute location of files that are referenced in the JSON file.
* `get_absolute_path { filename }` — Returns the absolute path for the requested filename, which is assumed to be given relative to the current JSON file. If an absolute path to a file is passed, it will be returned unchanged. `set_json_path` should have been used to set the correct path beforehand.
* `generate_projection_counter_format { nProjections }` — Generates a number format string to get the correct number of digits in the consecutive projection file names.
* `add_filters_to_list { filter_list jobj key_sequence }` — Add filters from a given key sequence in the json object to the given filter list.

### CSV and TSV handling

* `read_json_file { filename }` — Read JSON file, check its validity, and return a dictionary using rl_json.
* `read_csv_file { filename }` — Read CSV file, return dict of lists: one list for each column, columns identified by column number (`0` ... `N-1`).
* `load_csv_into_tab_separated_string { filename { skip_x_le_zero 0 } }` — Loads CSV or TSV into a tab-separated string where all value pairs are in a consecutive tab-separated stream. `skip_x_le_zero` (if set to `1`) allows to skip lines that contain x-values <= 0 (necessary for X-ray spectra: aRTist does not support acceleration energies <= 0.)
* `load_csv_into_list { filename }` — Loads CSV or TSV into list of consecutive values (line by line).

### Logging System
The module uses its own little logging system that invokes aRTist's logging system if available. If aRTist is not available, messages are simply printed on the console.

* `fail { message }` — Handles error messages.
* `warning { message }` — Handles warning messages.
* `info { message }` — Handles information messages.
* `debug { message }` — Handles debug messages.
* `status_info { message }` — Shows a status note in the module's GUI (if aRTist is available).

### Checkers

* `is_valid { value valid_list }` — Checks if `value` is an item in the list `valid_list`. Returns `1` on success, `0` if `value` is not in the list of valid values.

### Checkers for valid JSON data

* `value_is_null { value }` — Checks if a specific value is set to `null`.
* `value_is_null_or_zero { value }` — Checks if a specific value is set to `null` or zero (`0`).
* `object_value_is_null { json_obj }` — Checks if a JSON object has a `value` parameter and if this parameter is set to `null`.
* `object_value_is_null_or_zero { json_obj }` — Checks if a JSON object has a `value` parameter and if this parameter is set to `null` or zero (`0`).

### Getters

* `get_value { dictionary { keys {} } {fail_value 0} }` — Get the specific value of the parameter that is located at the given sequence of `keys` in the JSON dictionary. Returns the `fail_value` (standard is `0`) if the key sequence cannot be found or the value is set to `null`.

    Example: `get_value $object {center x value} 10.0`
* `json_exists { dictionary { keys {} } }` — Passthrough of `::rl_json::json exists`.
* `json_isnull { dictionary { keys {} } }` — Passthrough of `::rl_json::json isnull`.
* `json_exists_and_not_null { dictionary { keys {} } }` — Returns `1` if the key sequence exists and its value is not `null`. Otherwise returns `0`.
* `json_type { dictionary { keys {} } }` — Get type of JSON item in `dictionary` located by the `keys` sequence. Passthrough of `::rl_json::json type`.
* `json_extract { dictionary keys }` — Get the JSON sub-object that is located by a given sequence of `keys` in the JSON `dictionary`.
* `json_extract_from_possible_keys { dictionary key_sequences }` — Searches the JSON `dictionary` for each key sequence in the given list of `key_sequences`. For the first sequence that exists, an extracted JSON object will be returned.

### Unit Conversion

Unit conversion functions take a JSON object that must contain a `value` and a `unit`. Each function supports the allowed units from the [CTSimU file format specification](https://bamresearch.github.io/ctsimu-scenarios).

* `in_mm { value unit }` — Converts a length to mm.
* `in_rad { value { unit "deg" } }` — Converts an angle to radians.
* `in_deg { value { unit "rad" } }` — Converts an angle to degrees.
* `in_s { value unit }` — Converts a time to seconds.
* `in_mA { value unit }` — Converts a current to mA.
* `in_kV { value unit }` — Converts a voltage to kV.
* `in_deg_per_s { value unit }` — Converts an angular velocity to deg/s.
* `in_g_per_cm3 { value unit }` — Converts a mass density to g/cm³.
* `in_lp_per_mm { value unit }` — Converts a resolution to lp/mm.
* `from_bool { value }` — Converts `true` to `1` and `false` to `0`.
* `convert_SNR_FWHM { SNR_or_FWHM intensity }` — Converts between SNR and Gaussian FWHM for a given intensity (i.e., more generally, the given distribution's mean value).
* `convert_to_native_unit { given_unit native_unit value }` — Checks which native unit is requested, converts JSON `value` accordingly. Possible native units are `"mm"`, `"rad"`, `"deg"`, `"deg/s"`, `"s"`, `"mA"`, `"kV"`, `"g/cm^3"`, `"bool"` and `"string"`.
* `json_convert_to_native_unit { native_unit value_and_unit { fallback_json_unit ""} }` — Like the previous function `convert_to_native_unit`, but takes a JSON object `value_and_unit` that must contain a `value` and an associated `unit` (the "given unit"). Checks which native unit is requested, converts JSON `value` accordingly. `fallback_json_unit` is used if the unit is not specified in the `value_and_unit` JSON object.
* `get_value_in_native_unit { native_unit dictionary keys {fail_value 0} }` — Takes a sequence of JSON `keys` from the given `dictionary` where a JSON object with a value/unit pair must be located. Returns the value of this JSON object in the requested `native_unit`. Returns the `fail_value` (standard is `0`) if the key sequence cannot be found or the value is set to `null`.