# ::ctsimu::materialmanager
A manager class for the materials of a CTSimU scenario.

## Methods of the `::ctsimu::materialmanager` class

### General

* `reset` — Delete all materials and reset manager to initial state. The only remaining materials will be `"void"` and `"none"`.
* `add_material { m }` — Add a [`::ctsimu::material`](material.md) object to the material manager.
* `set_frame { frame nFrames }` — Set the current `frame` number, given a total of `nFrames`. This will update all the materials listed in the material manager to the given frame number and obey possible drifts.

### Getters

* `get { material_id }` — Get the [`::ctsimu::material`](material.md) object that is identified by the given `material_id`.
* `density { material_id }` — Get the current mass density of the material that is identified by the given `material_id`.
* `composition { material_id }` — Get the aRTist composition string of the material that is identified by the given `material_id`.
* `aRTist_id { material_id }` — Get the aRTist ID for the material that is identified by the given `material_id`.

### Setters

* `set_from_json { jsonscene }` — Fill the material manager from a given CTSimU scenario JSON structure. The full scenario should be passed in the parameter: the function tries to find the `"materials"` section on its own and gives an error if it cannot be found.