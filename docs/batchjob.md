# ::ctsimu::batchjob
A single batch job on the batch manager's queue.

## Methods of the `::ctsimu::batchmanager` class

### Getters

* `get { property }` — Returns the value for a given `property`. See table below.
* `format_string { }` — Returns the job's file format and data type in a single string (such as `TIFF float32` or `RAW uint16`).

### Setters

* `set { property value }` — Set a value in the properties dictionary. See table below.
* `set_format { format_string }` — Converts a batch format string (such as `TIFF float32` or `RAW uint16`) to individual `output_fileformat` and `output_datatype` values for the job.
* `set_from_json { jsonfile }` — Set the batch job's output directory and base name from the file name and location of the given JSON scenario file.

## Settings parameters

The class keeps a `_properties` dictionary to store its settings. The methods `get` and `set` are used to retrieve and manipulate these settings.

The following table gives an overview of the currently used keys and their meanings.

| Settings Key                | Description                                                     |
| :-------------------------- | :-------------------------------------------------------------- |
| `id`                        | List ID, used for the position in the aRTist GUI list.          |
| `status`                    | Job status: `Pending`, `Inactive`, `Done`, etc.                 |
| `runs`                      | Number of repeated runs for this batch job.                     |
| `start_run`                 | Run number at which the simulation should start. Used to skip runs that have already been simulated. |
| `start_projection_number`   | At which projection to start in the first simulated run. Used to pick up a batch job after a crash. `start_run` should be set to the correct run number as well. |
| `json_file`                 | JSON file that contains the scenario to simulate for this job.  |
| `output_fileformat`         | `tiff` or `raw`.                                                |
| `output_datatype`           | `uint16` or `float32`.                                          |
| `output_folder`             | Where to store the simulation results (projection images, etc.) |
| `output_basename`           | Base filename to use for the output.                            |