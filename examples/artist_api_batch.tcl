# An example script that can be passed to aRTist as a startup parameter.
# It shows how to add jobs to the batch manager and start running them.

if { [::Modules::Available "CTSimU"] } {
	set ctsimu [dict get [::Modules::Get "CTSimU"] Namespace]
	if { ![winfo exists .ctsimu] } { ${ctsimu}::Run }

	# Current script directory:
	set script_directory [ file dirname [ file normalize [ info script ] ] ]

	# Clear the batch list to start with a fresh batch manager:
	${ctsimu}::clearBatchList

	# Deactivate the option to restart aRTist after each run.
	# The option can also be activated, with the only disadvantage
	# that the batch list saved at the end of this script would not be
	# saved with the up to date job statuses. Instead, it would only be
	# saved after the first batch run: after this, the batch manager
	# would take over control of aRTist.
	${ctsimu}::setProperty restart_aRTist_after_each_run 0

	# Activate the creation of reconstruction config files
	# and set the volume output datatype:
	${ctsimu}::setProperty create_cera_config_file   1
	${ctsimu}::setProperty cera_output_datatype      "float32"
	${ctsimu}::setProperty create_openct_config_file 1
	${ctsimu}::setProperty openct_output_datatype    "float32"

	# Example 1:
	# Import a batch list from a CSV file:
	${ctsimu}::importBatchJobs "$script_directory/scenario/batch.csv"

	# Example 2:
	# Add a scenario file to the batch list, simply by passing the
	# - file name of the JSON file.
	# The other job parameters are set automatically to their standard values.
	${ctsimu}::insertBatchJob "$script_directory/scenario/example.json"

	# Example 3:
	# Add a job and some important parameters:
	# - file name of the JSON file
	# - number of runs
	# - start run number
	# - start projection number
	# - output file format with data type
	${ctsimu}::insertBatchJob "$script_directory/scenario/example.json" 10 1 0 "TIFF float32"

	# Example 4:
	# Add a job and set all its parameters in one function call:
	# - file name of the JSON file
	# - number of runs
	# - start run number
	# - start projection number
	# - output file format with data type
	# - output folder
	# - output basename
	${ctsimu}::insertBatchJob "$script_directory/scenario/example.json" 5 1 0 "RAW uint16" "C:/Users/David/Desktop/example_scan" "my_scan"

	# Start the batch execution:
	${ctsimu}::runBatch

	# Wait until the module has finished all batch jobs:
	while { ![${ctsimu}::CanClose] } { update; after 100 }

	# Save the batch list so you can have a look at the
	# scan job status in case something goes wrong.
	${ctsimu}::saveBatchJobs "C:/Users/David/Desktop/example_scan/final_batch_status.csv"
}

# Close aRTist when everything is done:
::aRTist::shutdown -force
exit