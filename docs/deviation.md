# ctsimu_deviation
A class for a geometrical deviation of a coordinate system, i.e. a translation or a rotation with respect to one of the axes x, y, z (world), u, v, w (local), or r, s, t (sample) or any other arbitrary vector.

Like any parameter, they can have drifts, which means they can change over time.

## Methods of the `::ctsimu::deviation` class

### Getters

* `type` — Get the transformation type (`"rotation"` or `"translation"`).
* `axis` — Get the transformation axis as a `ctsimu::scenevector` object.
* `pivot` — Get the pivot point for rotations as a `ctsimu::scenevector` object.
* `amount` — Returns a `::ctsimu::parameter` object that specifies the amount of the deviation.
* `native_unit` — Returns the native unit of the deviation's `amount`.
* `known_to_reconstruction` — Returns whether this drift must be considered during a reconstruction (`1`) or not (`0`). This parameter is used when calculating projection matrices.

### Setters

* `set_type { type }` — Sets the transformation type (`"rotation"` or `"translation"`).
* `set_axis { axis }` — Sets the transformation axis. Can be a `::ctsimu::scenevector` object or an axis name: `"x"`, `"y"`, `"z"`, `"u"`, `"v"`, `"w"`, `"r"`, `"s"`, `"t"`.
* `set_pivot { pivot }` — Sets the pivot point for rotations. Expects a `::ctsimu::scenevector` object.
* `set_known_to_reconstruction { known }` — Sets the "known to reconstruction" attribute to true (`known` = `1`) or false (`known` = `0`).
* `set_amount_from_json { json_obj }` — Set the deviation's amount from a JSON object, which is a parameter with a value and potentially a drift. This function is usually not called from the outside, but used by `set_from_json`.
* `set_from_json { json_obj }` — Set up the deviation from a JSON deviation structure.