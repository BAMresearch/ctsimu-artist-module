# An example script that can be passed to aRTist as a startup parameter.
# It shows how to modify module settings and how to load and run a single scenario file.

if { [::Modules::Available "CTSimU"] } {
	set ctsimu [dict get [::Modules::Get "CTSimU"] Namespace]
	if { ![winfo exists .ctsimu] } { ${ctsimu}::Run }

	# Get current script directory:
	set script_directory [ file dirname [ file normalize [ info script ] ] ]

	# The stage display option must be set before the scenario is loaded:
	${ctsimu}::setProperty show_stage 0

	# Load the example scenario:
	${ctsimu}::loadScene "$script_directory/scenario/example.json"

	# Show projection number 10/21.
	# Note that for the module, the projection number starts at 0.
	${ctsimu}::showProjection 9

	# Change some output parameters.
	# Note that the output folder must already exist.
	${ctsimu}::setProperty output_basename   "my_scan"
	${ctsimu}::setProperty output_folder     "C:/Users/David/Desktop/example_scan"
	${ctsimu}::setProperty output_fileformat "tiff"
	${ctsimu}::setProperty output_datatype   "float32"
	${ctsimu}::setProperty start_angle                -5
	${ctsimu}::setProperty stop_angle                360
	${ctsimu}::setProperty n_projections              50
	${ctsimu}::setProperty include_final_angle         0
	${ctsimu}::setProperty start_projection_number     9
	${ctsimu}::setProperty scattering_image_interval   3
	${ctsimu}::setProperty recon_output_datatype   "float32"
	${ctsimu}::setProperty create_cera_config_file     0
	${ctsimu}::setProperty create_openct_config_file   0

	# Start the scan simulation:
	${ctsimu}::startScan

	# Wait until the module has finished the simulation:
	while { ![${ctsimu}::CanClose] } { update; after 100 }
}

# Close aRTist when everything is done:
::aRTist::shutdown -force
exit