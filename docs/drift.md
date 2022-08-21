# ctsimu_drift
This submodule provides a general class to handle the drift of an arbitrary parameter for a given number of frames, including interpolation.

## Methods of the `::ctsimu::drift` class

### General

* `reset` — Reset drift object to standard parameters. Clears the trajectory list as well. Used by the constructor as initialization function.
* `get_value_for_frame { frame nFrames }` — Returns a drift value for the given `frame` number, assuming a total number of `nFrames`. If interpolation is activated, linear interpolation will take place between drift values, but also for `frame` numbers outside the expected range: `0 < frame > nFrames`. Note that the `frame` number starts at `0`.

### Getters

* `is_active` — Returns whether this drift object is active (`1`) or inactive (`0`).
* `known_to_reconstruction` — Returns whether this drift must be considered during a reconstruction (`1`) or not (`0`). This parameter is used when calculating projection matrices.
* `interpolation` — Returns whether a linear interpolation should take place between drift values (if the number of drift values does not match the number of frames). If no interpolation takes place, there will be discrete steps of drift values (and possibly sudden changes).
* `unit` — Returns the unit for the drift values.

### Setters

* `set_active { state }` — Activates (`state` = `1`) or deactivates (`state` = `0`) this drift object.
* `set_known_to_reconstruction { known }` — Sets the "known to reconstruction" attribute to true (`known` = `1`) or false (`known` = `0`).
* `set_interpolation { intpol }` — Activates linear interpolation between drift values (`intpol` = `1`) or deactivates it (`intpol` = `0`).
* `set_unit { unit }` — Sets the `unit` (string) of the drift values.
* `set_from_json { jsonObj }` — Sets the drift from a given JSON drift object.