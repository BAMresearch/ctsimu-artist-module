# ctsimu_part
Parts are objects in the scene: detector, source, stage and samples.

They have a coordinate system and can define deviations from their standard geometries (translations and rotations around given axes). The center, vectors and deviations can all have drifts, allowing for an evolution through time.

Each part has its own coordinate system, and a parallel "ghost" coordinate system for calculating projection matrices for the reconstruction. This is necessary because the user is free not to pass any deviations to the reconstruction.

## Methods of the `::ctsimu::part` class

### Constructor

* `constructor { { name "" } }`

    A name for the part can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well.

### General

* `reset` — Reset to the default (such as after the object is constructed). Will result in standard alignment with the world coordinate system. Any geometrical deviations are deleted.
* `set_geometry { geometry world stage }` — Sets up the part from a JSON geometry definition. Here, `geometry` must be an `rl_json` object. The `world` and `stage` have to be given as `::ctsimu::coordinate_system` objects.
* `set_frame_cs { cs world stage frame nFrames { only_known_to_reconstruction 0 } { w_rotation_in_rad 0 } }` — Set up the given coordinate system `cs`such that it complies with the `frame` number and all necessary drifts and deviations. (Assuming a total number of `nFrames`). This function is used by `set_frame` and is usually not called from outside the object.
* `set_frame { world stage frame nFrames w_rotation_in_rad }` — Set up the part for the given frame number, obeying all deviations and drifts.
	
	- `world:` A `::ctsimu::coordinate_system` that represents the world.
	- `stage:` A `::ctsimu::coordinate_system` that represents the stage. Only necessary if the coordinate system will be attached to the stage. Otherwise, the world coordinate system can be passed as an argument.
	- `frame:` Frame number to set up.
	- `nFrames:` Total number of frames in the CT scan.
	- `w_rotation_in_rad:` Possible rotation of the object around its w axis. Only used for the CT rotation of the sample stage.

### Getters

* `name` — Returns the name of the part.
* `is_attached_to_stage` — Returns `1` if the part is attached to the stage coordinate system, or `0` if the world coordinate system is the reference.

### Setters

* `set_name { name }` — Set the `name` of the part.
* `set_cs_names { }` — Uses this object's name to give names to its proper coordinate systems. Invoked by default by the `set_name` function.
* `attach_to_stage { attached }` — Set `1` if the part is attached to the stage coordinate system, or `0` if the world coordinate system is the reference.