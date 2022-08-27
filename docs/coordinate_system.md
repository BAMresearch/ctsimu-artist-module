# ctsimu_coordinate_system
This submodule provides a class for coordinate systems and coordinate transformations, and two helper functions.

## Functions

This module adds the following functions to the `::ctsimu` namespace:

* `basis_transform_matrix { csFrom csTo {m4x4 0} }` — Returns the basis transform matrix to convert vector coordinates given in `csFrom` to vector coordinates in `csTo`, assuming both coordinate systems share a common point of origin. If `m4x4` is set to `1`, a 4x4 matrix will be returned instead of a 3x3 matrix.
* `change_reference_frame_of_point { point csFrom csTo }` — Returns point's coordinates, given in `csFrom`, in terms of `csTo`.

## Methods of the `::ctsimu::coordinate_system` class

### Constructor

* `constructor { }`

    The constructor currently does not take any arguments.

### General

* `reset` — Resets the coordinate system to a standard world coordinate system:

        u:      (1, 0, 0)
        v:      (0, 1, 0)
        w:      (0, 0, 1)
        center: (0, 0, 0)
* `print` — Generates a human-readable info string.
* `make_unit_coordinate_system` — Basis vectors are made into unit vectors.
* `make_from_vectors { center u w attached }` — Set the coordinate system from the `::ctsimu::vector` objects `center`, `u` (first basis vector) and `w` (third basis vector). `attached` should be `1` if the reference coordinate system is the stage ("attached to stage") and `0` if not.
* `make { cx cy cz ux uy uz wx wy wz attached }` — Set up the coordinate system from vector components (all floats) for the center (`cx`, `cy`, `cz`), the u vector (first basis vector, `ux`, `uy`, `uz`) and the w vector (third basis vector, `wx`, `wy`, `wz`). `attached` should be `1` if the reference coordinate system is the stage ("attached to stage") and `0` if not.

### Getter Functions

* `get_copy` — Returns a copy of this coordinate system.
* `center` — A vector that represents the coordinate system's center (in its reference coordinate system).
* `u` — The `u` basis vector in terms of the reference coordinate system.
* `v` — The `v` basis vector in terms of the reference coordinate system.
* `w` — The `w` basis vector in terms of the reference coordinate system.
* `is_attached_to_stage` — If the coordinate system is assumed to be attached to the stage (`1`) or not (`0`). If it is attached to the stage, its reference coordinate system is the stage coordinate system.

### Setter Functions

* `set_center { c }` — Set the coordinates of the origin of the coordinate system (in terms of its reference coordinate system). The argument `c` must be a `::ctsimu::vector`.
* `set_u { u }` — Set the `u` basis vector. A `::ctsimu::vector` is expected.
* `set_v { v }` — Set the `v` basis vector. A `::ctsimu::vector` is expected.
* `set_w { w }` — Set the `w` basis vector. A `::ctsimu::vector` is expected.
* `attach_to_stage { attached }` — Pass `1` if the reference coordinate system is assumed to be the stage coordinate system. Otherwise, `0`.
* `set_up_from_json_geometry { geometry world stage { onlyKnownToReconstruction 0 } }` — Set up the geometry from a JSON object. The function arguments are:
    - `geometry` — A JSON object that contains the geometry definition for this coordinate system, including rotations, drifts and translational deviations (the latter are deprecated).
    - `world` — A `::ctsimu::coordinate_system` that represents the world.
    - `stage` — A `::ctsimu::coordinate_system` that represents the stage. Only necessary if the coordinate system will be attached to the stage. Otherwise, the world coordinate system can be passed as an argument.
    - `onlyKnownToReconstruction` — Pass `1` if the `known_to_reconstruction` JSON parameter must be obeyed, so only deviations that are known to the reconstruction software will be handled. Other deviations will be ignored.

### Transformations

* `translate { vec }` — Shift center by given vector.
* `translate_x { dx }` — Translate coordinate system in x direction by amount `dx`.
* `translate_y { dy }` — Translate coordinate system in y direction by amount `dy`.
* `translate_z { dz }` — Translate coordinate system in z direction by amount `dz`.
* `rotate { axis angle_in_rad }` — Rotate coordinate system around the given `axis` vector by `angle_in_rad`. This does not move the center point, as the axis vector is assumed to be attached to the center of the coordinate system.
* `rotate_around_pivot_point { axis angle_in_rad pivot_point }` — Rotate coordinate system around a pivot point. Generally, this will result in a different center position, as the axis of rotation is assumed to be attached to the pivot point. `axis` and `pivot_point` must be given as `::ctsimu::vector` objects.
* `rotate_around_u { angle_in_rad }` — Rotate coordinate system around its u axis by `angle_in_rad`.
* `rotate_around_v { angle_in_rad }` — Rotate coordinate system around its v axis by `angle_in_rad`.
* `rotate_around_w { angle_in_rad }` — Rotate coordinate system around its w axis by `angle_in_rad`.
* `transform { csFrom csTo }` — Relative transformation in world coordinates from `csFrom` to `csTo`, result will be in world coordinates. Detailed description: assuming this CS, `csFrom` and `csTo` all three are independent coordinate systems in a common reference coordinate system (e.g. world). This function will calculate the necessary translation and rotation that would have to be done to superimpose `csFrom` with `csTo`. This translation and rotation will, however, be applied to this CS, not to `csFrom`.
* `change_reference_frame { csFrom csTo }` — Transform this coordinate system from the `csFrom` reference frame to the `csTo` reference frame. Result will be in terms of `csTo`. Note: both `csFrom` and `csTo` must be in the same reference coordinate system (e.g., the world coordinate system).