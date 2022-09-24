# ctsimu_scenario
The main class for a complete CT scan scenario. This class keeps everything together: simulation settings and virtual scenario parameters (usually from a [CTSimU JSON file](https://bamresearch.github.io/ctsimu-scenarios)).

## Methods of the `::ctsimu::scenario` class

* `get { setting }` — Get the value of a settings parameter. See table below.
* `set { setting value }` — Set the `setting` parameter to the given `value`. See table below.
* `reset` — Reset scenario to standard settings.
* `load_json_scene { json_filename }` — Loads a CTSimU scenario from the given JSON file.

### Current simulation status:

* `is_running` — Is the simulation currently running? (`0` or `1`)
* `batch_is_running` — Is the batch queue currently running? (`0` or `1`)
* `json_loaded_successfully` — Scenario loaded successfully? (`0` or `1`)

### Status setters (intended only for internal use):

* `_set_run_status { status }`
* `_set_batch_run_status { status }`
* `_set_json_load_status { status }`

### Preparation functions, mostly for internal use:

* `set_basename_from_json { json_filename }` — Extracts the base name of a JSON file and sets the `output_basename` setting accordingly.
* `create_projection_counter_format { nProjections }` — Sets the number format string to get the correct number of digits in the consecutive projection file names.

## Settings parameters

The class keeps a `_settings` dictionary to store simulation-related settings. The methods `get` and `set` are used to retrieve and manipulate the settings.

The following table gives an overview of the currently used keys and their meanings.

| Settings Key          | Description                                                         |
| :-------------------- | :------------------------------------------------------------------ |
| `json_file`           | The currently loaded CTSimU scenario description.                   |
| `json_file_directory` | Directory of the currently loaded CTSimU scenario file.             |
| `format_version`      | The file format version of the currently loaded scenario.           |
| `output_fileformat`   | File format of the projection images: `raw` or `tiff`.              |
| `output_datatype`     | Data type of the projection images: `uint16` or `float32`.          |
| `output_folder`       | Where the projection files and simulation results will be stored.   |
| `output_basename`     | Name of the simulation. Precedes output filenames, e.g. for images. |
| `projection_counter_format` | Counter format for sequential projection image number. Generated automatically based on the number of projection images. |
| `start_angle`         | Angle where CT rotation starts.                                     |
| `stop_angle`          | Angle where CT rotation stops.                                      |
| `n_projections`       | Total number of projection images from the CT scan.                 |
| `proj_nr`             | Projection number that is currently represented in the scene.       |
| `include_final_angle` | Take the last projection at the stop angle? (`0` or `1`)            |
| `start_proj_nr`       | Projection number where to start the simulation (useful if a simulation crashed). |
| `dark_field`          | Calculate a dark field image? Typically noise-free in aRTist. (`0` or `1`) |
| `n_darks`             | Number of dark field images to create.                              |
| `n_flats`             | Number of flat field images to create.                              |
| `n_flat_avg`          | Number of frame averages for a flat field image.                    |
| `flat_field_ideal`    | Generate an ideal (noise-free) flat field image? (`0` or `1`)       |
| `create_cera_config_file` | If a reconstruction configuration file for SIEMENS CERA shall be created for the simulated projection images. |
| `cera_output_datatype` | Data type of the CERA reconstruction volume: `uint16` or `float32`. |
| `create_clfdk_config_file` | If a reconstruction configuration file for BAM clFDK shall be created for the simulated projection images. |
| `openct_output_datatype` | Data type of the OpenCT reconstruction volume: `uint16` or `float32`. |