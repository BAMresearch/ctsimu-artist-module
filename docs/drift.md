# ctsimu_drift
This submodule provides a general class to handle the drift of an arbitrary parameter for a given number of frames, including interpolation.

## Methods of the `::ctsimu::drift` class

### Constructor

* `constructor { native_unit }`

    When a drift object is constructed, is must be assigned a valid `native_unit` to enable the JSON parser to convert the drift values from the JSON file, if necessary. See the documentation on [native units](native_units.md) for a complete list of valid strings.

### General

* `reset` — Reset drift object to standard parameters. Clears the trajectory list as well. Used by the constructor as initialization function.
* `get_value_for_frame { frame nFrames }` — Returns a drift value for the given `frame` number, assuming a total number of `nFrames`. If interpolation is activated, linear interpolation will take place between drift values, but also for `frame` numbers outside the expected range: `0 < frame` or `frame > nFrames`. Note that the `frame` number starts at `0`.

### Getters

* `known_to_reconstruction` — Returns whether this drift must be considered during a reconstruction (`1`) or not (`0`). This parameter is used when calculating projection matrices.
* `interpolation` — Returns whether a linear interpolation should take place between drift values (if the number of drift values does not match the number of frames). If no interpolation takes place, there will be discrete steps of drift values (and possibly sudden changes).
* `native_unit` — Returns the native unit (see above) for the drift values.

### Setters

* `set_known_to_reconstruction { known }` — Sets the "known to reconstruction" attribute to true (`known` = `1`) or false (`known` = `0`).
* `set_interpolation { intpol }` — Activates linear interpolation between drift values (`intpol` = `1`) or deactivates it (`intpol` = `0`).
* `set_native_unit { native_unit }` — Sets the `native_unit` (string, see above) of the drift values.
* `set_from_json { json_object }` — Sets the drift from a given JSON drift object.