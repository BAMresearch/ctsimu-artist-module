# ::ctsimu::stage
A class to set up and generate the stage. Inherits from [`::ctsimu::part`](part.md).

## Methods of the `::ctsimu::stage` class

### Constructor

* `constructor { { name "CTSimU_Stage" } }`

	A name for the stage can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well.

### General

* `reset` — Reset stage to standard settings. Deletes all previously defined drifts, etc. Called internally before a new stage definition is loaded from a JSON file.
* `set_from_json { jobj }` — Import the stage geometry from the given JSON object (`jobj`). The JSON object should contain the complete content from the scenario definition file (at least the geometry section containing the stage definition).
* `get_sample_copy` — Create a sample object from this stage for the sample manager, to show it as an object in aRTist's virtual scene.