# ::ctsimu::json_basics
Helper functions when handling CTSimU JSON objects via the rl_json extension.

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

### Checkers for valid data

* `isNull_value { value }` — Checks if a specific value is set to `null`.
* `isNullOrZero_value { value }` — Checks if a specific value is set to `null` or zero.
* `isNull_jsonObject { json_obj }` — Checks if a JSON object has a `value` parameter and if this parameter is set to `null`.
* `isNullOrZero_jsonObject { json_obj }` — Checks if a JSON object has a `value` parameter and if this parameter is set to `null` or zero.

### Getters

* `getValue { sceneDict keys }` — Get the specific value of parameter that is located by a given sequence of `keys` in the JSON dictionary. Example from above:
    
    `getValue $object {center x value}` returns `10.0`
* `extractJSONobject { sceneDict keys }`  — Get the JSON sub-object that is located by a given sequence of `keys` in the JSON dictionary.

### Unit Conversion

Unit conversion functions take a JSON object that must contain a `value` and a `unit`. Each function supports the allowed units from the [CTSimU file format specification](https://bamresearch.github.io/ctsimu-scenarios).

* `in_mm { value unit }` — Converts a length to mm.
* `in_rad { value unit }` — Converts an angle to radians.
* `in_deg { value unit }` — Converts an angle to degrees.
* `in_s { value unit }` — Converts a time to seconds.
* `in_mA { value unit }` — Converts a current to mA.
* `in_kV { value unit }` — Converts a voltage to kV.
* `in_g_per_cm3 { value unit }` — Converts a mass density to g/cm³.
* `from_bool { value }` — Converts `true` to `1` and `false` to `0`.
* `convert_to_native_unit { givenUnit nativeUnit value }` — Checks which native unit is requested, converts JSON `value` accordingly. Possible native units are `"mm"`, `"rad"`, `"deg"`, `"s"`, `"mA"`, `"kV"`, `"g/cm^3"` and `"bool"`.
* `json_convert_to_native_unit { nativeUnit valueAndUnit }` — Like the previous function `convert_to_native_unit`, but takes a JSON object `valueAndUnit` that must contain a `value` and an associated `unit` (the "given unit"). Checks which native unit is requested, converts JSON `value` accordingly.
* `json_get { nativeUnit sceneDict keys }` — Takes a sequence of JSON `keys` from the given dictionary where a JSON object with a value/unit pair must be located. Returns the value of this JSON object in the requested `nativeUnit`.