# CTSimU aRTist Module: API & Class Documentation

This module is written in object-oriented Tcl (TclOO). Its components are split across several Tcl files which are sourced in a chain. It is written in such a way that it can also be used independently from aRTist from any Tcl script. You can find demo Tcl scripts in the `examples` folder of the module's Git repository.

## aRTist module interface functions

The aRTist module provides a number of functions in `modulemain.tcl` that can be used to control the module through a Tcl script that is passed to aRTist on startup. The following example files from this repository demonstrate the usage of the interface functions that are documented below.

* `examples/artist_api_single.tcl`
* `examples/artist_api_batch.tcl`

### Setting module parameters

The parameters that are typically accessible from the GUI can be set via a script using the `setProperty` function:

* `setProperty { property value }`

The following properties can be set:

| Property                        | Value                     | Remarks                                                  |
| :------------------------------ | :------------------------ | :------------------------------------------------------- |
| `output_basename`               | string                    |                                                          |
| `output_folder`                 | string                    |                                                          |
| `output_fileformat`             | `"raw"` or `"tiff"`       |                                                          |
| `output_datatype`               | `"uint16"` or `"float32"` |                                                          |
| `start_angle`                   | float                     | Start angle of the scan.                                 |
| `stop_angle`                    | float                     | Stop angle of the scan.                                  |
| `n_projections`                 | integer                   | Number of projections in the scan.                       |
| `include_final_angle`           | `0` or `1`                | Take the last projection when the stop angle is reached? |
| `start_projection_number`       | integer                   | Projection number at which the simulation should start.  |
| `scattering_image_interval`     | integer                   | Calculate new scatter image every n projections.         |
| `show_stage`                    | `0` or `1`                | Show stage in aRTist scene?                              |
| `restart_aRTist_after_each_run` | `0` or `1`                | Batch manager: restart aRTist after each run?            |
| `create_cera_config_file`       | `0` or `1`                | Create a CERA reconstruction config file?                |
| `cera_output_datatype`          | `"uint16"` or `"float32"` | Output datatype of the CERA volume.                      |
| `create_openct_config_file`     | `0` or `1`                | Create an openCT reconstruction config file?             |
| `openct_output_datatype`        | `"uint16"` or `"float32"` | Output datatype of the openCT reconstruction volume.     |

### Functions for single scenarios

* `loadScene { json_filename }` — Load the JSON scenario given in the filename.
* `showProjection { projection_nr }` — Show the given projection number in the aRTist scene. Note that the projection number starts at `0`.
* `nextProjection { }` — Show the next projection from the scan sequence.
* `prevProjection { }` — Show the previous projection from the scan sequence.
* `startScan { }` — Run the scan from the loaded scenario.
* `stopScan { }` — Stop the execution of the current scan simulation.

### Functions for the batch manager

* `clearBatchList { }` — Remove all batch jobs from the list.
* `importBatchJobs { csv_filename }` — Import the batch jobs specified in the given CSV file. Note that these jobs will be added after any jobs that are already in the queue.
* `insertBatchJob { jsonFileName {runs 1} {startRun 1} {startProjectionNumber 0} {format "RAW uint16"} {outputFolder ""} {outputBasename ""} {status "Pending"} }` — Insert a batch job at the end of the batch list. The parameters are the same as the ones from the GUI.
* `saveBatchJobs { csv_filename }` — Save the current state of the batch list.
* `runBatch { }` — Start the batch run.
* `stopBatch { }` — Stop the batch run.

## Source files

The following list provides the source order and links to the descriptions of each object class.

* **`ctsimu_main.tcl`**

	Main CTSimU module file which takes care of sourcing all other files. When using the CTSimU module in your own project, only source this file to get the whole package.

* **[`ctsimu_batchmanager.tcl`](batchmanager.md)**

	Handles and runs a batch queue of JSON scenario files.

* **[`ctsimu_batchjob.tcl`](batchjob.md)**

	A single batch job on the batch manager's queue.

* **[`ctsimu_scenario.tcl`](scenario.md)**

	Manage and set up a complete CTSimU scenario.

* **[`ctsimu_samplemanager.tcl`](samplemanager.md)**

	The sample manager keeps the samples of the scene together.

* **[`ctsimu_source.tcl`](source.md)**

	Set up and generate an X-ray source. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_stage.tcl`](stage.md)**

	Set up and generate the stage. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_detector.tcl`](detector.md)**

	Set up and generate a detector. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_sample.tcl`](sample.md)**

	A generic sample. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_filter.tcl`](filter.md)**

	Filters define a material and thickness.

* **[`ctsimu_materialmanager.tcl`](materialmanager.md)**

	The material manager that handles all the sample materials.

* **[`ctsimu_material.tcl`](material.md)**

	Generic material class: composition, density and their drifts.

* **[`ctsimu_part.tcl`](part.md)**

	Parts are objects in the scene: detector, source, stage and samples.

	They have a coordinate system and can define deviations from their standard geometries (translations and rotations around given axes). The center, vectors and deviations can all have drifts, allowing for an evolution in time.

	Each part has its own coordinate system and a parallel "ghost" coordinate system for calculating projection matrices for the reconstruction. This is necessary because the user is free not to pass any deviations to the reconstruction.

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

* **[`ctsimu_image.tcl`](image.md)**

	Image reader using aRTist's built-in loading functions.

* **[`ctsimu_helpers.tcl`](helpers.md)**

	Helpers for logging (info messages, warning, errors) and handling JSON files using the `rl_json` Tcl extension.