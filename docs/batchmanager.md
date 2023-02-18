# ::ctsimu::batchmanager
Handles and runs a batch queue of JSON scenario files.

## Methods of the `::ctsimu::batchmanager` class

* `reset` — Remove all batch jobs.
* `kick_off` — Executed by `modulemain.tcl` when aRTist has been restarted by the batch manager after a finished batch run.
* `kick_off_import` — Import the batch list stored in aRTist's preferences file.

### Getters

* `get { property }` — Returns the value for a given `property`. See constructor function for the used property keys.
* `is_running { }` — Is the batch manager currently running a queue?
* `n_jobs { }` — Number of jobs in the batch list.
* `jobs_are_pending { }` — Check if there are still any pending jobs. Returns `1` if jobs are pending, `0` if not.

### Setters

* `set { property value }` — Set a value in the properties dictionary.
* `set_batch_list { bl }` — Sets the handle to aRTist's GUI batch list. The batch manager synchronizes with the GUI list whenever necessary.
* `set_status { bj index message }` — Set status of given batch job `bj` and display it in aRTist's GUI table. `index` is the job's row index in the GUI table.

### Batch jobs and execution

* `sync_batchlist_into_manager { }` — Updates the batch manager to be in sync with aRTist's GUI batch list.
* `add_batch_job { bj }` — Add a [`::ctsimu::batchjob`](batchjob.md) to the batch manager.
* `add_batch_job_to_GUIlist { bj }` — Add the given batch job to the module's aRTist GUI list. Automatically executed by `add_batch_job`.
* `add_batch_job_from_json { jsonfile }` — Create a new batch job for the given JSON scenario file.
* `clear { }` — Clear the batch manager in sync with the GUI list.
* `run_batch { global_scenario }` — Starts the batch execution. Parameter: `global_scenario` is the [`::ctsimu::scenario`](scenario.md) object of the aRTist scene that the batch manager should control. When used outside of aRTist, any [`::ctsimu::scenario`](scenario.md) object can be passed.
* `stop_batch { }` — Stop the current batch execution.

### Batch list import/export

* `csv_joblist { { newline_escaped 0 } }` — Create the contents for a CSV file to store the batch jobs (for a later import) or for aRTist's `settings.ini`. For the `settings.ini` file, newlines need to be escaped: set the `newline_escaped` parameter to `1`.
* `save_batch_jobs { csvFilename }` — Store batch jobs in a CSV file (for later import).
* `import_batch_jobs { csvFilename }` — Import batch jobs from a given CSV file. They are appended to the manager's batch list and to the GUI list.
* `import_csv_joblist { csv_joblist_contents }` — Import the batch list from the contents of a CSV job list into the batch manager. Also used to restore the list from aRTist's `settings.ini`. Called by `import_batch_jobs`, which then also fills the GUI list.

## Settings parameters

The class keeps a `_properties` dictionary to store its settings. The methods `get` and `set` are used to retrieve and manipulate these settings.

The following table gives an overview of the currently used keys and their meanings.

| Settings Key                     | Description                                                         |
| :------------------------------- | :------------------------------------------------------------------ |
| `running`                        | Is the batch manager currently running (`1`) or not (`0`)?          |
| `restart_aRTist_after_each_run`  | Restart aRTist after each run to restore memory (`1`) or not (`0`)? |
| `waiting_for_restart`            | Is the batch manager currently waiting for an aRTist restart?       |
| `next_run`                       | Number of the next run after aRTist will restart .                  |
| `standard_output_fileformat`     | Standard file format for newly added jobs. `tiff` or `raw`.         |
| `standard_output_datatype`       | Standard data type for newly added jobs. `uint16` or `float32`.     |
| `kick_off_done`                  | Have the kick-off functions already been executed (after an aRTist restart)? |
| `csv_list_to_import`           | Contents of a CSV batch list to import during the kick-off script. `modulemain.tcl` fills this parameter with the batch list from aRTist's preferences file when the module starts. |