# ::ctsimu::part
Parts are objects in the scene: detector, source, stage and samples.

They have a coordinate system and can define deviations from their standard geometries (translations and rotations around given axes). The center, vectors and deviations can all have drifts, allowing for an evolution through time.

Each part has its own coordinate system, and a parallel "ghost" coordinate system for calculating projection matrices for the reconstruction. This is necessary because the user is free not to pass any deviations to the reconstruction.

## Methods of the `::ctsimu::part` class

### Constructor

* `constructor { { name "" } { id "" } }`

    A `name` for the part can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well. The `id` designates aRTist's identifier for the object (to find it in the part list).

### General

* `reset` — Reset to the default (such as after the object is constructed). Will result in standard alignment with the world coordinate system. Any geometrical deviations are deleted.
* `set_geometry { geometry stageCS }` — Sets up the part from a JSON geometry definition. Here, `geometry` must be an `rl_json` object. The `stageCS` must be given as a `::ctsimu::coordinate_system` object. If this part is not attached to the stage, the `$::ctsimu::world` coordinate system can be passed instead.
* `set_frame_cs { cs stageCS frame nFrames { only_known_to_reconstruction 0 } { w_rotation_in_rad 0 } }` — Set up the given coordinate system `cs`such that it complies with the `frame` number and all necessary drifts and deviations. (Assuming a total number of `nFrames`). This function is used by `set_frame` and is usually not called from outside the object.
* `set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set up the part for the given frame number, obeying all deviations and drifts.

	- `stageCS:` A `::ctsimu::coordinate_system` that represents the stage. Only necessary if the coordinate system will be attached to the stage. Otherwise, the world coordinate system can be passed as an argument.
	- `frame:` Frame number to set up.
	- `nFrames:` Total number of frames in the CT scan.
	- `w_rotation_in_rad:` Possible rotation angle of the object around its w axis for the given frame. Only used for the CT rotation of the sample stage.

### Getters

* `get { property }` — Returns the current value for a given `property`.
* `parameter { property }` — Returns the parameter object behind a given `property`.
* `current_coordinate_system` — Returns the current `::ctsimu::coordinate_system` of the part.
* `recon_coordinate_system` — Returns the current recon `::ctsimu::coordinate_system` of the part.
* `center` — Returns the part's center as a `::ctsimu::scenevector`.
* `u` — Returns the part's `u` vector as a `::ctsimu::scenevector`.
* `w` — Returns the part's `w` vector as a `::ctsimu::scenevector`.
* `name` — Returns the name of the part.
* `id` — Returns the aRTist ID of the part.
* `is_attached_to_stage` — Returns `1` if the part is attached to the stage coordinate system, or `0` if the world coordinate system is the reference.

### Setters

* `set { property value { native_unit "undefined" }}` — Set a simple property value in the internal properties dictionary. The standard value of the `::ctsimu::parameter` object that is identified by the `property` key is set to `value`. If the parameter already exists in the internal properties dictionary, it is reset (i.e., all drifts are deleted).
* `set_parameter { property parameter }` — Sets the object in the internal properties dictionary that is identified by the `property` key to the given `parameter` (should be a `::ctsimu::parameter` object). If there is already an entry under the given `property` key, this old parameter object will be deleted.
* `set_parameter_value { property dictionary key_sequence { fail_value 0 } { native_unit "" } }` — Sets the value for the parameter that is identified by the `property` key in the internal properties dictionary. The new value is taken from the given JSON `dictionary`, and located by the given `key_sequence`. Optionally, a `fail_value` can be specified if the value cannot be found at the given `key_sequence` or is set to `null`. Also, a `native_unit` can be provided in case the `property` does not yet exist in the internal properties dictionary. In this case, a new `::ctsimu::parameter` is created for the `property` and given the `native_unit`. If the parameter already exists in the internal properties dictionary, it is reset (i.e., all drifts are deleted).
* `set_parameter_from_key { property dictionary key_sequence { fail_value 0 } { native_unit "" } }` — Set up a parameter object for the given `property` from the `key_sequence` in the given `dictionary`. The object located at the key sequence must at least have a `value` property. Optionally, a `fail_value` can be specified if the value cannot be found at the given `key_sequence` or is set to `null`.
* `set_parameter_from_possible_keys { property dictionary key_sequences { fail_value 0 } { native_unit "" } }` — Like `set_parameter_from_key`, but a list of multiple possible `key_sequences` can be provided. Uses the first sequence that matches or the `fail_value` if nothing matches.
* `set_name { name }` — Set the `name` of the part.
* `set_id { id }` — Set the aRTist `id` of the part.
* `set_cs_names { }` — Uses this object's name to give names to its proper coordinate systems. Invoked by default by the `set_name` function.
* `set_center { c }` — Set center. Expects a `::ctsimu::scenevector`.
* `set_u { u }` — Set vector u. Expects a `::ctsimu::scenevector`.
* `set_w { w }` — Set vector w. Expects a `::ctsimu::scenevector`.
* `attach_to_stage { attached }` — Set `1` if the part is attached to the stage coordinate system, or `0` if the world coordinate system is the reference.