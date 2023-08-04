# ::ctsimu::scenevector
A scene vector is a 3D vector that knows the type of its reference coordinate system, given as world, local or sample. It provides functions to convert between coordinate systems and it can handle drifts. Therefore, all three components of a scene vector are stored as [`::ctsimu::parameter`](parameter.md) objects.

Useful for vectors that can change due to drifts, such as rotation axis and pivot point of a deviation, or, in general, the coordinate system vectors.

## Methods of the `::ctsimu::scenevector` class

### Constructor

* `constructor { { native_unit "" } }` — Because a `::ctsimu::scenevector` is just a collection of three parameters, a `native_unit` for those parameters can be assigned. For example, the center location of a coordinate system should be described in `"mm"`. See the documentation on [native units](native_units.md) for a complete list of valid strings.

### General

* `standard_vector` — Creates a [`::ctsimu::vector`](vector.md) that represents this vector in its standard orientation (without any drifts applied).
* `drift_vector { frame nFrames { only_known_to_reconstruction 0 } }` — Creates a [`::ctsimu::vector`](vector.md) that represents only the drift values for the given `frame` number (out of a total of `nFrames`). Can later be added to the standard value to get the resulting vector respecting all drifts.
* `vector_for_frame { frame { nFrames 0 } { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for the given frame, respecting all drifts.
* `print` — Return a human-readable string for the current vector representation.
* `has_drifts` — Returns `1` if the scene vector drifts during the CT scan, `0` otherwise.

### Conversion Functions

The following functions all generate and return new [`::ctsimu::vector`](vector.md) objects for a specific reference coordinate system, and a specific `frame` out of a total of `nFrames` in the CT scan, obeying any specified vector drifts.

**`local`** would be the object's local coordinate system (in terms of the world coordinate system), and **`sample`** the object's sample coordinate system (in terms of the stage coordinate system). In many cases, it is not necessary to provide all three coordinate systems (such as when transforming the scene vector from stage to world). Unnecessary coordinate systems can be set to `0` or you can pass the `$::ctsimu::world` coordinate system instead.

For scene vectors that refer to a sample coordinate system, the `local` coordinate system must be the stage coordinate system if the sample is attached to the stage, or `[self]` if it is located in the world coordinate system (in this case, `sample` would be the world CS as well).

* `point_in_world { local sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for point coordinates in terms of the world coordinate system. Function arguments:
	- `local` — A [`::ctsimu::coordinate_system`](coordinate_system.md) that represents the object's local CS in terms of world coordinates.
	- `sample` — A [`::ctsimu::coordinate_system`](coordinate_system.md) that represents the sample in terms of the stage coordinate system. If you don't want to convert from a sample vector, it doesn't matter what you pass here (you can pass `0`).
	- `frame` — The number of the current frame.
	- `nFrames` — The total number of frames.
	- `only_known_to_reconstruction` — Only handle drifts that are known to the recon software.
* `point_in_local { local sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for point coordinates in terms of the local coordinate system.
* `point_in_sample { stage sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for point coordinates in terms of the sample coordinate system.
* `direction_in_world { local sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for a direction in terms of the world coordinate system.
* `direction_in_local { local sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for a direction in terms of the local coordinate system.
* `direction_in_sample { stage sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a [`::ctsimu::vector`](vector.md) for a direction in terms of the sample coordinate system.

### Getters

* `reference` — Returns a string for the vector's reference coordinate system: `"world"`, `"local"` or `"sample"`.

### Setters

* `set_reference { reference }` — Set the reference coordinate system. Must be a string, any of: `"world"`, `"local"` or `"sample"`.
* `set_native_unit { native_unit }` — Set native unit of vector components. Necessary for the location of points such as the center points of coordinate systems, usually given in `"mm"` as native unit.
* `set_simple { c0 c1 c2 }` — Set a simple scene vector from three numbers, results in a scene vector without drifts.
* `set_component { i parameter }` — Set the `i`th vector component to `parameter` (which must be a [`::ctsimu::parameter`](parameter.md)).
* `set_from_json { json_object }` — Sets up the scene vector from a CTSimU JSON object that describes a three-component vector.