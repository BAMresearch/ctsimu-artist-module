# CTSimU aRTist Module: API & Class Documentation

This module is written in object-oriented Tcl (TclOO). Its components are split across several Tcl files which are sourced in a chain. It is written in such a way that it can also be used independently from aRTist from any Tcl script. You can find demo Tcl scripts in the `examples` folder of the module's Git repository.

## aRTist module interface functions

The aRTist module provides a number of functions in `modulemain.tcl` that can be used to control the module through a Tcl script that is passed to aRTist on startup. The following example files from this repository demonstrate the usage of the interface functions, which are documented below.

* `examples/artist_api_single.tcl`
* `examples/artist_api_batch.tcl`

### Setting module parameters

The parameters that are typically accessible from the GUI can be set via a script using the `setProperty` function:

* `setProperty { property value }`

The following properties can be set:

| Property                         | Value                     | Remarks                                                  |
| :------------------------------- | :------------------------ | :------------------------------------------------------- |
| `output_basename`                | string                    |                                                          |
| `output_folder`                  | string                    |                                                          |
| `output_fileformat`              | `"raw"` or `"tiff"`       |                                                          |
| `output_datatype`                | `"uint16"` or `"float32"` |                                                          |
| `start_angle`                    | float                     | Start angle of the scan.                                 |
| `stop_angle`                     | float                     | Stop angle of the scan.                                  |
| `n_projections`                  | integer                   | Number of projections in the scan.                       |
| `include_final_angle`            | `0` or `1`                | Take the last projection when the stop angle is reached? |
| `start_projection_number`        | integer                   | Projection number at which the simulation should start.  |
| `scattering_image_interval`      | integer                   | Calculate new scatter image every n projections.         |
| `contact_name`                   | string                    | Contact name for the metadata file.                      |
| `show_stage`                     | `0` or `1`                | Show stage in aRTist scene?                              |
| `skip_simulation`                | `0` or `1`                | Skip simulation and only create config/metadata files?   |
| `run_number_always_in_filenames` | `0` or `1`                | Run number in file and folder names, even for single runs. |
| `restart_aRTist_after_each_run`  | `0` or `1`                | Batch manager: restart aRTist after each run?            |
| `onload_compute_detector`        | `0` or `1`                | Compute full detector?                                   |
| `onload_compute_source`          | `0` or `1`                | Compute full X-ray source?                               |
| `onload_load_samples`            | `0` or `1`                | Load samples from scenario?                              |
| `onload_scattering_active`       | `0` or `1`                | Set multisampling for scenario?                          |
| `onload_multisampling`           | `0` or `1`                | Set scattering if required by scenario?                  |
| `recon_output_datatype`          | `"uint16"` or `"float32"` | Output datatype for the reconstruction volume.           |
| `recon_config_uncorrected`       | `0` or `1`                | Prepare recon configs for uncorrected projection images? |
| `create_cera_config_file`        | `0` or `1`                | Create a CERA reconstruction config file?                |
| `create_openct_config_file`      | `0` or `1`                | Create an OpenCT reconstruction config file?             |
| `openct_abs_paths`               | `0` or `1`                | Use absolute file paths in OpenCT config file?           |
| `openct_circular_enforced`       | `0` or `1`                | Enforce the circular trajectory file format variant?     |
| `create_clfdk_run_script`        | `0` or `1`                | Create a batch file for a clFDK reconstruction?          |

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

## Submodules

The following list gives an overview over the submodules and provides the source order in which their files are included. The links lead to the description of each submodule and its class and function definitions.

* **`ctsimu_main.tcl`**

	Main CTSimU module file which takes care of sourcing all other files. When using the CTSimU module in your own project, only source this file to get the whole package.

* **[`ctsimu_batchmanager`](batchmanager.md)**

	Handles and runs a batch queue of JSON scenario files.

* **[`ctsimu_batchjob`](batchjob.md)**

	A single batch job on the batch manager's queue.

* **[`ctsimu_scenario`](scenario.md)**

	Manage and set up a complete CTSimU scenario.

* **[`ctsimu_samplemanager`](samplemanager.md)**

	The sample manager keeps the samples of the scene together.

* **[`ctsimu_source`](source.md)**

	Set up and generate an X-ray source. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_stage`](stage.md)**

	Set up and generate the stage. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_detector`](detector.md)**

	Set up and generate a detector. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_sample`](sample.md)**

	A generic sample. Inherits from [`::ctsimu::part`](part.md).

* **[`ctsimu_filter`](filter.md)**

	Filters define a material and thickness.

* **[`ctsimu_materialmanager`](materialmanager.md)**

	The material manager that handles all the materials of the scenario.

* **[`ctsimu_material`](material.md)**

	Generic material classes: composition, density and their drifts.

* **[`ctsimu_part`](part.md)**

	Parts are objects in the scene: detector, source, stage and samples.

	They have a coordinate system and can define deviations from their standard geometries (translations and rotations around given axes). The center, vectors and deviations can all have drifts, allowing for an evolution in time.

* **[`ctsimu_coordinate_system`](coordinate_system.md)**

	Class for a coordinate system with three basis vectors.

* **[`ctsimu_deviation`](deviation.md)**

	Class for a geometrical deviation of a coordinate system, i.e. a translation or a rotation. Can include drifts in time.

* **[`ctsimu_scenevector`](scenevector.md)**

	A scene vector is a 3D vector that knows the type of its reference coordinate sytem, given as world, stage or sample. It provides functions to convert between these coordinate systems and can handle drifts.

* **[`ctsimu_parameter`](parameter.md)**

	Class for a parameter value, includes handling of parameter drifts.

* **[`ctsimu_drift`](drift.md)**

	Class to handle the drift of an arbitrary parameter for a given number of frames, including interpolation.

* **[`ctsimu_matrix`](matrix.md)**

	Basic matrix class and a function to generate a 3D rotation matrix.

* **[`ctsimu_vector`](vector.md)**

	Basic vector class.

* **[`ctsimu_image`](image.md)**

	Image reader using aRTist's built-in loading functions.

* **[`ctsimu_helpers`](helpers.md)**

	Helper functions and variables, especially for handling CTSimU JSON objects via the `rl_json` extension, as well as unit conversions and other types of conversions. These functions and variables are available directly under the `::ctsimu` namespace.