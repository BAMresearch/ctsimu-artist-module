# ::ctsimu::samplemanager
The sample manager keeps the samples of the scene together.

## Methods of the `::ctsimu::samplemanager` class

* `reset` — Delete all managed parts.
* `add_sample { s }` — Add a [`::ctsimu::sample`](sample.md) object to the list of managed samples.
* `set_frame { stageCS frame nFrames }` — Set current frame number (propagates to all samples). The current stage coordinate system must be given as a [`::ctsimu::coordinate_system`](coordinate_system.md).
* `update_scene { stageCS material_manager }` — Move objects in the aRTist scene to match the current frame number. The current stage coordinate system must be given as a [`::ctsimu::coordinate_system`](coordinate_system.md).
* `set_from_json { jsonscene stageCS }` — Import all sample information from a given JSON scenario. The complete scenario should be passed as a JSON structure. The stage coordinate system must be given as a [`::ctsimu::coordinate_system`](coordinate_system.md).
* `load_meshes { stageCS material_manager }` — Load the mesh file of each part into aRTist.