# ::ctsimu::parameter
Class for a parameter value, includes handling of parameter drifts.

CTSimU defines a [JSON-based file format](https://bamresearch.github.io/ctsimu-scenarios) for scenario descriptions. Its *parameters* typically have a structure like in the following example, where `"x"` would be a *parameter* of the `"center"` object. Each parameter comes with a `value` and a `unit`, optionally with an uncertainty definition (currently not used in an aRTist simulation) and a definition of the parameter drift throughout the scan. Drifts are handled in this aRTist module.

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

## Methods of the `::ctsimu::parameter` class

### Constructor

* `constructor { { native_unit "" } { standard 0 } }`

    When a parameter object is constructed, it must be assigned a valid `native_unit` to enable the JSON parser to convert the drift values from the JSON file, if necessary. See the documentation on [native units](native_units.md) for a complete list of valid strings.

    Optionally, a `standard` value can be passed to the constructor. The standard value is the "actual" `value` defined for this parameter in the JSON file. If a JSON object is used to set up this parameter, the `standard` value provided in the constructor is overwritten by the `value` given in the JSON file.

### General

* `reset` — Delete all drifts and set the parameter's current value to the standard value.
* `print { frame nFrames }` — Returns a human-readable string that gives information about the parameter's value for the given `frame` number (out of a total of `nFrames`).
* `set_frame_and_get_value { frame { nFrames 1 } { only_drifts_known_to_reconstruction 0 } }` — Sets and returns the parameter's current value such that it matches the given `frame` out of a total of `nFrames`, depending on whether all drifts are applied or only drifts known to the reconstruction software.
* `get_total_drift_value_for_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } }` — Calculates the total drift value from all drift components, for the given `frame` out of a total of `nFrames`, depending on whether all drifts are applied or only drifts known to the reconstruction software.
* `add_drift { json_drift_obj }` — Generates a [`::ctsimu::drift`](drift.md) object (from a JSON object that defines a drift) and adds it to its internal list of drifts to handle.
* `set_from_json { json_parameter_object }` — Set up this parameter from a JSON parameter object. Returns `1` on success, `0` otherwise.
* `set_parameter_from_key { json_object key_sequence }` — Tries to find a valid parameter object at the given `key_sequence` in the given `json_object`. Sets the parameter if possible and returns `1` on success, `0` otherwise.
* `set_parameter_from_possible_keys { json_object key_sequences }` — Accepts a list of `key_sequences` that specify possible locations of a parameter object in the given `json_object`. Sets up the parameter from the first valid JSON parameter object it finds, and returns `1` on success, `0` if no key sequence in the list of key sequences turned out to be a valid parameter. This can be used to support multiple spelling variants, for example "center" and "centre":

      $center_x set_parameter_from_possible_keys $geometry [list {center x} {centre x}]

* `set_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } }` — Prepares the `current_value` for the given `frame` number (assuming a total of `nFrames`). This takes into account all drifts.

    The parameter `only_drifts_known_to_reconstruction` can be set to `1` if this the new parameter value should only be calculated from drifts which are known to the reconstruction software.

    Returns `1` if the parameter value has changed from its previous state (due to drifts) and `0` if it has not changed.

### Getters

* `native_unit` — Get the parameter's native unit, as used internally by aRTist.
* `preferred_unit` — Get the parameter's preferred unit (as defined in the JSON file).
* `preferred_uncertainty_unit` — Get the parameter's preferred uncertainty unit (as defined in the JSON file).
* `standard_value` — Get the parameter's standard value (in native unit, unaffected by any drifts).
* `current_value` — Get the parameter's current value  (in native unit). Should be used after `set_frame`.
* `uncertainty` — Get the parameter's uncertainty value.
* `maximum_value { nFrames { only_drifts_known_to_reconstruction 0 } }` — Get the maximum value during the evolution of `nFrames`, given drifts.
* `minimum_value { nFrames { only_drifts_known_to_reconstruction 0 } }` — Get the minimum value during the evolution of `nFrames`, given drifts.
* `changed` — Has the parameter changed since the last acknowledged change? (See setter function `acknowledge_change`). Returns `1` if true, `0` if not.
* `has_drifts` — Does the parameter drift? Returns `1` if yes, `0` if not.

### Setters

* `set_native_unit { native_unit }` — Set the parameter's native unit.
* `set_preferred_unit { preferred_unit }` — Set the parameter's preferred unit.
* `set_preferred_uncertainty_unit { preferred_uncertainty_unit }` — Set the parameter's preferred uncertainty unit.
* `set_standard_value { value }` — Set the parameter's standard value. Automatically sets the current value to the standard value.
* `set_uncertainty { value }` — Set the parameter's standard uncertainty.
* `acknowledge_change { { new_change_state 0} }` — Acknowledge a change of the parameter due to a drift. After the acknowledgment, the function `changed` will return the `new_change_state` value (standard: `0`).