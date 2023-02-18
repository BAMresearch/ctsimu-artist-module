# ::ctsimu::sample
A class for a generic sample. Inherits from [`::ctsimu::part`](part.md).

## Methods of the `::ctsimu::sample` class

### Constructor

* `constructor { { name "Sample" } }`

	A name for the sample can be passed as an argument to the constructor.

### General

* `reset` — Reset sample to standard settings. Deletes all previously defined drifts, etc.
* `set_from_json { jobj stageCS }` — Import the sample geometry from the given JSON sample object (`jobj`). The `stageCS` must be given as a [`::ctsimu::coordinate_system`](coordinate_system.md) object. If this part is not attached to the stage, the `$::ctsimu::world` coordinate system can be passed instead.
* `load_mesh_file { material_manager }` — Load the sample's mesh file into aRTist. The scenario's [`::ctsimu::materialmanager`](materialmanager.md) must be passed as an argument.
* `update_mesh_file { material_manager }` — Check if the mesh file has changed (due to drifts) and update it if necessary. The scenario's [`::ctsimu::materialmanager`](materialmanager.md) must be passed as an argument.
* `update_scaling_factor` — Update the sample size to match the current frame's scaling factor for the object.