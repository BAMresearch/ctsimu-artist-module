# ctsimu_parameter
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

* `constructor { unit { standard 0 } }`

    When a parameter object is constructed, is must be assigned a valid native `unit` to enable the JSON parser to convert the drift values from the JSON file, if necessary. Valid drift units are:

    + `""` — Unitless.
    + `"mm"`, `"rad"`, `"deg"`, `"s"`, `"mA"`, `"kV"`, `"g/cm^3"` and `"bool"`.
    + `"string"` — Special type for string parameters such as spectrum file names.

    Optionally, a `standard` value can be passed to the constructor. The standard value is the "actual" `value` defined for this parameter in the JSON file. If a JSON object is used to set up this parameter, the `standard` value provided in the constructor is overwritten by the `value` given in the JSON file.

### General

* `reset` — Delete all drifts and set the parameter's current value to the standard value.

### Getters

* `unit` — Get the parameter's native unit.
* `standard_value` — Get the parameter's standard value (unaffected by drifts).
* `current_value` — Get the parameter's current value.

### Setters

* `set_unit { unit }` — Set the parameter's native unit.
* `set_standard_value { value }` — Set the parameter's standard value.
* `add_drift { json_drift_obj }` — Generates a `ctsimu::drift` object (from a JSON object that defines a drift) and adds it to its internal list of drifts to handle.
* `set_from_json { json_parameter }` — Set up this parameter from a JSON parameter object.
* `set_frame { frame nFrames { only_drifts_known_to_reconstruction 0 } }` — Prepares the `current_value` for the given `frame` number (assuming a total of `nFrames` frames). This takes into account all drifts. 
    
    The parameter `only_drifts_known_to_reconstruction` can be set to `1` if this the new parameter value should only be calculated from drifts which are known to the reconstruction software.

    Returns `1` if the parameter value has changed from its previous state (due to drifts) and `0` if it has not changed.