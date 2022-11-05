# CTSimU aRTist Module
This module is written in object-oriented Tcl (TclOO). Its components are split across several Tcl files which are sourced in a chain. It is written in such a way that it can also be used independently from aRTist from any Tcl script.

## Code Documentation
The following list provides the source order and links to the descriptions of each object class.

* **`ctsimu_main.tcl`**

	Main CTSimU module file which takes care of sourcing all other files. When using the CTSimU module in your own project, only source this file to get the whole package.
    
* **[`ctsimu_scenario.tcl`](scenario.md)**

	A class to manage and set up a complete CTSimU scenario.

* **[`ctsimu_samplemanager.tcl`](samplemanager.md)**

	The sample manager keeps the samples of the scene together.

* **[`ctsimu_source.tcl`](source.md)**

	A class to set up and generate an X-ray source. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_stage.tcl`](stage.md)**

	A class to set up and generate the stage. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_detector.tcl`](detector.md)**

	A class to set up and generate a detector. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_sample.tcl`](sample.md)**

	A generic sample. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_materialmanager.tcl`](materialmanager.md)**

	The material manager that handles all the sample materials.

* **[`ctsimu_material.tcl`](material.md)**

	A class for a sample material.

* **[`ctsimu_part.tcl`](part.md)**
	
	Parts are objects in the scene: detector, source, stage and samples.

	They have a coordinate system and can define deviations from their standard geometries (translations and rotations around given axes). The center, vectors and deviations can all have drifts, allowing for an evolution through time.

	Each part has its own coordinate system, and a parallel "ghost" coordinate system for calculating projection matrices for the reconstruction. This is necessary because the user is free not to pass any deviations to the reconstruction.

* **[`ctsimu_coordinate_system.tcl`](coordinate_system.md)**

	Class for a coordinate system with three basis vectors.

* **[`ctsimu_deviation.tcl`](deviation.md)**

	Class for a geometrical deviation of a coordinate system, i.e. a translation or a rotation. Can include drifts in time.

* **[`ctsimu_scenevector.tcl`](scenevector.md)**

	A scene vector is a 3D vector that knows the type of its reference coordinate sytem, given as world, stage or sample. It provides functions to convert between these coordinate systems and can handle drifts.

* **[`ctsimu_parameter.tcl`](parameter.md)**

	Class for a parameter value, includes handling of parameter drifts.

* **[`ctsimu_drift.tcl`](drift.md)**

	Class to handle the drift of an arbitrary parameter for a given number of frames, including interpolation.

    
* **[`ctsimu_matrix.tcl`](matrix.md)**

	Basic matrix class and a function to generate a 3D rotation matrix.

* **[`ctsimu_vector.tcl`](vector.md)**

	Basic vector class.

* **[`ctsimu_helpers.tcl`](helpers.md)**

	Helpers for logging (info messages, warning, errors) and handling JSON files using the `rl_json` Tcl extension.

* **[`ctsimu_output_metadata.tcl`](output_metadata.md)**

	Generator function to create a metadata file for the simulation.