# ::ctsimu::part
Parts are objects in the scene: detector, source, stage and samples.

They have a coordinate system and can define deviations from their standard geometries (translations and rotations around given axes). The center, vectors and deviations can all have drifts, allowing for an evolution through time.

## Methods of the `::ctsimu::part` class

### Constructor

* `constructor { { name "" } { id "" } }`

    A `name` for the part can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well. The `id` designates aRTist's identifier for the object (to find it in the part list).

### General

* `reset` — Reset to the default. Will result in standard alignment with the world coordinate system. Any geometrical deviations are deleted.
* `set_geometry { geometry stageCS }` — Sets up the part from a JSON geometry definition. Here, `geometry` must be an `rl_json` object. The `stageCS` must be given as a [`::ctsimu::coordinate_system`](coordinate_system.md) object. If this part is not attached to the stage, the `$::ctsimu::world` coordinate system can be passed instead.
* `set_frame_cs { stageCS frame nFrames only_known_to_reconstruction { w_rotation_in_rad 0 } }` — Set up the part's current coordinate system such that it complies with the `frame` number and all necessary drifts and deviations (assuming a total number of `nFrames`). This function is used by `set_frame` and is usually not called from outside the object.
* `set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set up the part for the given frame number, obeying all deviations and drifts.
	- `stageCS:` A [`::ctsimu::coordinate_system`](coordinate_system.md) that represents the stage. Only necessary if the coordinate system will be attached to the stage. Otherwise, the world coordinate system can be passed as an argument: `$::ctsimu::world`.
	- `frame:` Frame number to set up.
	- `nFrames:` Total number of frames in the CT scan.
	- `w_rotation_in_rad:` Possible rotation angle of the object around its w axis for the given frame. Only used for the CT rotation of the sample stage
* `set_frame_for_recon { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set up the part for the given frame number, obeying only those deviations and drifts that are known to the reconstruction software. The function arguments are the same as for `set_frame`.
* `place_in_scene { stageCS }` — Set the position and orientation of the part in the aRTist scene.

### Getters

* `get { property }` — Returns the current value for a given `property`.
* `standard_value { property }` — Returns the standard value for a given `property` (i.e., the value unaffected by drifts).
* `parameter { property }` — Returns the [`::ctsimu::parameter`](parameter.md) object behind a given `property`.
* `changed { property }` — Has the property changed its value since the last acknowledgment? (See setter function `acknowledge_change`).
* `current_coordinate_system` — Returns the current [`::ctsimu::coordinate_system`](coordinate_system.md) of the part.
* `center` — Returns the part's center as a [`::ctsimu::scenevector`](scenevector.md).
* `u` — Returns the part's `u` vector as a [`::ctsimu::scenevector`](scenevector.md).
* `w` — Returns the part's `w` vector as a [`::ctsimu::scenevector`](scenevector.md).
* `name` — Returns the name of the part.
* `id` — Returns the aRTist ID of the part.
* `is_attached_to_stage` — Returns `1` if the part is attached to the stage coordinate system, or `0` if the world coordinate system is the reference.

### Setters

* `set { property value { native_unit "undefined" }}` — Set a simple property value in the internal properties dictionary. The standard value of the [`::ctsimu::parameter`](parameter.md) object that is identified by the `property` key is set to `value`. If the parameter already exists in the internal properties dictionary, the parameter is reset (i.e., all its drifts are deleted) before the new standard value is set.
* `acknowledge_change { property { new_change_state 0} }` — Acknowledge a change of the given `property` due to a drift. After the acknowledgment, the function `changed` will return the `new_change_state` value (standard: `0`).
* `set_parameter { property parameter }` — Sets the object in the internal properties dictionary that is identified by the `property` key to the given `parameter` (must be a [`::ctsimu::parameter`](parameter.md) object). If there is already an entry under the given `property` key, this old parameter object will be deleted.
* `set_parameter_value { property dictionary key_sequence { fail_value 0 } { native_unit "" } }` — Sets the value for the parameter that is identified by the `property` key in the internal properties dictionary. The new value is taken from the given JSON `dictionary` and located by the given `key_sequence`. Optionally, a `fail_value` can be specified if the value cannot be found at the given `key_sequence` or is set to `null`. Also, a `native_unit` can be provided in case the `property` does not yet exist in the internal properties dictionary. In this case, a new [`::ctsimu::parameter`](parameter.md) is created for the `property` and given the `native_unit`. If the parameter already exists in the internal properties dictionary, it is reset (i.e., all drifts are deleted).
* `set_parameter_from_key { property dictionary key_sequence { fail_value 0 } { native_unit "" } }` — Set up a parameter object for the given `property` from the `key_sequence` in the given `dictionary`. The object located at the key sequence must at least have a `value` property. Optionally, a `fail_value` can be specified if the value cannot be found at the given `key_sequence` or is set to `null`.
* `set_parameter_from_possible_keys { property dictionary key_sequences { fail_value 0 } { native_unit "" } }` — Like `set_parameter_from_key`, but a list of multiple possible `key_sequences` can be provided. Uses the first sequence that matches or the `fail_value` if nothing matches.
* `set_name { name }` — Set the `name` of the part.
* `set_id { id }` — Set the aRTist `id` of the part.
* `set_cs_names { }` — Uses this object's name to give names to its proper coordinate systems. Invoked by default by the `set_name` function.
* `set_center { c }` — Set center. Expects a [`::ctsimu::scenevector`](scenevector.md).
* `set_u { u }` — Set vector u. Expects a [`::ctsimu::scenevector`](scenevector.md).
* `set_w { w }` — Set vector w. Expects a [`::ctsimu::scenevector`](scenevector.md).
* `attach_to_stage { attached }` — Set `1` if the part is attached to the stage coordinate system, or `0` if the world coordinate system is the reference.
* `set_static_if_no_drifts` — Sets the object to 'static' if it does not drift, i.e., not moving. In this case, its coordinate system does not need to be re-assembled for each frame.