# ctsimu_scenevector
A scene vector is a 3D vector that knows the type of its reference coordinate sytem, given as world, local or sample. It provides functions to convert between coordinate systems and it can handle drifts. Therefore, all three components of a scene vector are of type `::ctsimu::parameter.`

Useful for vectors that can change due to drifts, such as rotation axis and pivot point of a deviation, or, in general, the coordinate system vectors.

## Methods of the `::ctsimu::scenevector` class

### Constructor

* `constructor { { native_unit "" } }` — Because a `::ctsimu::scenevector` is just a collection of three parameters, a `native_unit` for those parameters can be assigned. For example, the center location of a coordinate system should be described in `"mm"`. See the documentation on [native units](native_units.md) for a complete list of valid strings.

### General

* `standard_vector` — Creates a `::ctsimu::vector` that represents this vector without any drifts.
* `drift_vector { frame nFrames { only_known_to_reconstruction 0 } }` — Creates a `::ctsimu::vector` that represents only the drift values for the given `frame` number (out of a total of `nFrames`). Can later be added to the standard value to get the resulting vector respecting all drifts.
* `vector_for_frame { frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a `::ctsimu::vector` for the given frame, respecting all drifts.

### Conversion Functions

The following functions all generate and return new vector objects for a specific reference coordinate system, and a specific `frame` out of a total of `nFrames` in the CT scan, obeying any specified vector drifts.

The first parameter of each function, **`point_or_direction`**, must be a string that is either `"point"` (if your scene vector represents a point coordinate that needs to be transformed) or `"direction"` (if the vector denotes a general direction in space).

**`world`** must be a `::ctsimu::coordinate_system` that represents the world coordinate system, **`local`** would be the object's local coordinate system (in terms of the world coordinate system), and **`sample`** the object's sample coordinate system (in terms of the stage coordinate system). In some cases, it is not necessary to provide all three coordinate system (such as when transforming the scene vector from stage to world). Unnecessary coordinate systems can be set to `0` or you can pass the world coordinate system instead. 

For scene vectors that refer to a sample coordinate system, the `local` coordinate system must be the stage coordinate system if the sample is attached to the stage, or `[self]` if it is located in the world coordinate system (in this case, `sample` would be the world CS as well).

* `in_world { point_or_direction world local sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a `::ctsimu::vector` in terms of the world coordinate system.
* `in_local { point_or_direction world local sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a `::ctsimu::vector` in terms of the local coordinate system.
* `in_sample { point_or_direction world stage sample frame nFrames { only_known_to_reconstruction 0 } }` — Create and return a `::ctsimu::vector` in terms of the sample coordinate system.

### Getters

* `reference` — Returns a string for the vector's reference coordinate system: `"world"`, `"local"` or `"sample"`.

### Setters

* `set_reference { reference }` — Set the reference coordinate system. Must be a string, any of: `"world"`, `"local"` or `"stage"`.
* `set_native_unit { native_unit }` — Set native unit of vector components. Necessary for the location of points such as the center points of coordinate systems, usually given in `"mm"` as native unit.
* `set_simple { c0 c1 c2 }` — Set a simple scene vector from three numbers, results in a scene vector without drifts.
* `set_component { i parameter }` — Set the `i`th vector component to `parameter` (which must be a `::ctsimu::parameter`).
* `set_from_json { json_object }` — Sets up the scene vector from a CTSimU JSON object that describes a three-component vector.