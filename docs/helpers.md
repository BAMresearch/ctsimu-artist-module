# ::ctsimu::helpers
Helper functions for handling CTSimU JSON objects via the rl_json extension, as well as unit conversions and other types of conversions. These functions are available directly under the ::ctsimu namespace.

CTSimU defines a [JSON-based file format](https://bamresearch.github.io/ctsimu-scenarios) for scenario descriptions. Its parameters typically have a structure like in the following example:

    "center": {
      "x": {
        "value": 10.0,
        "unit": "mm",
        "uncertainty": {
          "value": 0.1,
          "unit": "mm"
          },
        "drift": [
          {
            "value": [-100, 100],
            "unit":  "mm"
          }
        ]
      }
    }

## Functions

### Logging System
The module uses its own little logging system that invokes aRTist's logging system if available. If aRTist is not available, messages are simply printed on the console.

* `fail { message }` — Handles error messages.
* `warn { message }` — Handles warning messages.
* `note { message }` — Handles information messages.
* `debug { message }` — Handles debug messages.

### Checkers

* `is_valid { value valid_list }` — Checks if `value` is an item in the list `valid_list`. Returns `1` on success, `0` if `value` is not in the list of valid values.

### Checkers for valid JSON data

* `value_is_null { value }` — Checks if a specific value is set to `null`.
* `value_is_null_or_zero { value }` — Checks if a specific value is set to `null` or zero.
* `object_value_is_null { json_obj }` — Checks if a JSON object has a `value` parameter and if this parameter is set to `null`.
* `object_value_is_null_or_zero { json_obj }` — Checks if a JSON object has a `value` parameter and if this parameter is set to `null` or zero.

### Getters

* `get_value { dictionary keys {fail_value 0} }` — Get the specific value of the parameter that is located at the given sequence of `keys` in the JSON dictionary. Returns the `fail_value` (standard is `0`) if the key sequence cannot be found or the value is set to `null`. Example from above:
    
    `get_value $object {center x value}` returns `10.0`
* `json_exists { dictionary keys }` — Passthrough of `::rl_json::json exists`.
* `json_type { dictionary { keys {} } }` — Get type of JSON item in `dictionary` located by the `keys` sequence. Passthrough of `::rl_json::json type`.
* `json_extract { dictionary keys }` — Get the JSON sub-object that is located by a given sequence of `keys` in the JSON `dictionary`.
* `json_extract_from_possible_keys { dictionary key_sequences }` — Searches the JSON `dictionary` for each key sequence in the given list of `key_sequences`. The first sequence that exists will return an extracted JSON object.

### Unit Conversion

Unit conversion functions take a JSON object that must contain a `value` and a `unit`. Each function supports the allowed units from the [CTSimU file format specification](https://bamresearch.github.io/ctsimu-scenarios).

* `in_mm { value unit }` — Converts a length to mm.
* `in_rad { value { unit "deg" } }` — Converts an angle to radians.
* `in_deg { value { unit "rad" } }` — Converts an angle to degrees.
* `in_s { value unit }` — Converts a time to seconds.
* `in_mA { value unit }` — Converts a current to mA.
* `in_kV { value unit }` — Converts a voltage to kV.
* `in_g_per_cm3 { value unit }` — Converts a mass density to g/cm³.
* `in_lp_per_mm { value unit }` — Converts a resolution to lp/mm.
* `from_bool { value }` — Converts `true` to `1` and `false` to `0`.
* `convert_SNR_FWHM { SNR_or_FWHM intensity }` — Converts between SNR and Gaussian FWHM for a given intensity (i.e., more generally, the given distribution's mean value).
* `convert_to_native_unit { given_unit native_unit value }` — Checks which native unit is requested, converts JSON `value` accordingly. Possible native units are `"mm"`, `"rad"`, `"deg"`, `"s"`, `"mA"`, `"kV"`, `"g/cm^3"`, `"bool"` and `"string"`.
* `json_convert_to_native_unit { native_unit value_and_unit }` — Like the previous function `convert_to_native_unit`, but takes a JSON object `value_and_unit` that must contain a `value` and an associated `unit` (the "given unit"). Checks which native unit is requested, converts JSON `value` accordingly.
* `get_value_in_unit { native_unit dictionary keys {fail_value 0} }` — Takes a sequence of JSON `keys` from the given `dictionary` where a JSON object with a value/unit pair must be located. Returns the value of this JSON object in the requested `native_unit`. Returns the `fail_value` (standard is `0`) if the key sequence cannot be found or the value is set to `null`.