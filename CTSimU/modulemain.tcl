# main file for startup within aRTist

# remember namespace
variable ns [namespace current]
variable BasePath [file dirname [info script]]

proc Info {} {
	return [dict create \
		Name        CTSimU \
		Description "CTSimU Scenario Loader" \
		Version     "1.2.2" \
	]
}

# requires the rl_json package which ships with aRTist since version 2.10.2
package require rl_json
package require csv
package require fileutil

# Source the CTSimU namespace and tell it the module namespace:
source [file join $BasePath ctsimu_main.tcl]
::ctsimu::set_module_namespace $ns
::ctsimu::set_module_directory $BasePath

variable ctsimu_scenario; # the currently loaded CTSimU scenario
variable ctsimu_batchmanager
set ctsimu_scenario [::ctsimu::scenario new]
set ctsimu_batchmanager [::ctsimu::batchmanager new]

proc Settings { args } {
	variable GUISettings

	switch -- [llength $args] {
		0 { return [array get GUISettings] }
		1 { Utils::UpdateArray GUISettings [lindex $args 0] }
		default { Utils::UpdateArray GUISettings $args }
	}

}

proc Init {} {
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	# Load preferences dict (stored by aRTist):
	Utils::nohup { Settings [Preferences::GetWithDefault CTSimU Settings {}] }

	set prefs [Preferences::GetWithDefault CTSimU Settings {}]

	if { [dict exists $prefs fileFormat] } {
		$ctsimu_scenario set output_fileformat [dict get $prefs fileFormat]
	}

	if { [dict exists $prefs dataType] } {
		$ctsimu_scenario set output_datatype [dict get $prefs dataType]
	}

	if { [dict exists $prefs showStageInScene] } {
		$ctsimu_scenario set show_stage [dict get $prefs showStageInScene]
	}

	if { [dict exists $prefs restartArtistAfterBatchRun] } {
		$ctsimu_batchmanager set restart_aRTist_after_each_run [dict get $prefs restartArtistAfterBatchRun]
	}

	if { [dict exists $prefs skipSimulation] } {
		$ctsimu_scenario set skip_simulation [dict get $prefs skipSimulation]
	}

	if { [dict exists $prefs csvJobList] } {
		$ctsimu_batchmanager set csv_list_to_import [dict get $prefs csvJobList]
	}

	if { [dict exists $prefs nextBatchRun] } {
		$ctsimu_batchmanager set next_run [dict get $prefs nextBatchRun]
	}

	if { [dict exists $prefs waitingForRestart] } {
		$ctsimu_batchmanager set waiting_for_restart [dict get $prefs waitingForRestart]
	}

	if { [dict exists $prefs cfgFileCERA] } {
		$ctsimu_scenario set create_cera_config_file [dict get $prefs cfgFileCERA]
	}

	if { [dict exists $prefs ceraOutputDatatype] } {
		$ctsimu_scenario set cera_output_datatype [dict get $prefs ceraOutputDatatype]
	}

	if { [dict exists $prefs cfgFileOpenCT] } {
		$ctsimu_scenario set create_openct_config_file [dict get $prefs cfgFileOpenCT]
	}

#	if { [dict exists $prefs openctOutputDatatype] } {
#		$ctsimu_scenario set openct_output_datatype [dict get $prefs openctOutputDatatype]
#	}

	if { [dict exists $prefs openctAbsPaths] } {
		$ctsimu_scenario set openct_abs_paths [dict get $prefs openctAbsPaths]
	}

	if { [dict exists $prefs openctUncorrected] } {
		$ctsimu_scenario set openct_uncorrected [dict get $prefs openctUncorrected]
	}

	if { [dict exists $prefs openctCircularEnforced] } {
		$ctsimu_scenario set openct_circular_enforced [dict get $prefs openctCircularEnforced]
	}

	if { [dict exists $prefs cfgFileCLFDK] } {
		$ctsimu_scenario set create_clfdk_config_file [dict get $prefs cfgFileCLFDK]
	}

	if { [dict exists $prefs clfdkOutputDatatype] } {
		$ctsimu_scenario set clfdk_output_datatype [dict get $prefs clfdkOutputDatatype]
	}

	# Feed the imported settings (so far) to the GUI:
	fillCurrentParameters

	return [Info]
}

# main entry point for aRTist
proc Run {} {
	variable ns
	set ret [Modules::make_window .ctsimu ${ns}::InitGUI]

	variable batchList
	variable ctsimu_batchmanager
	$ctsimu_batchmanager set_batch_list $batchList
	$ctsimu_batchmanager kick_off_import

	return $ret
}

proc Running {} {
	variable toplevel
	if { [info exists toplevel] && [winfo exists $toplevel] } { return true}
	return false
}

proc CanClose {} {
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	if {[$ctsimu_batchmanager is_running] == 1} {
		return false
	}

	if {[$ctsimu_scenario is_running] == 1} {
		return false
	}

	applyCurrentSettings
	return true
}

# construct an input form for a given property list
# containing Name, section option, type,payload
# of the property

# set variable var to default, if it doesn't exist yet
proc dset { varname default } {
	upvar $varname var
	if { ![info exists var] } { set var $default }
}

proc dataform { topframe settings } {
	variable ns
	variable GUITokens
	variable GUISettings

	set iconsize [Preferences::Get IconSize Button]
	set field 0

	foreach { description token type payload } $settings {

		set labeltext $description
		incr field

		switch $type {

			string {
				if { $payload != {} } { append labeltext " ($payload)" }
				set label [ttk::label $topframe.lbl${field} -text $labeltext]
				set entry [ttk::entry $topframe.ent${field} -textvariable ${ns}::GUISettings($token)]
				dset GUISettings($token) ""
				grid $label $entry -sticky nsew
			}

			double {
				if { $payload != {} } { append labeltext " ($payload)" }
				set label [ttk::label $topframe.lbl${field} -text $labeltext]
				set entry [ttk::entry $topframe.ent${field} -textvariable ${ns}::GUISettings($token)]
				dset GUISettings($token) 0.0
				grid $label $entry -sticky w
			}

			integer {
				if { $payload != {} } { append labeltext " ($payload)" }
				set label [ttk::label $topframe.lbl${field} -text $labeltext]
				set entry [ttk::entry $topframe.ent${field} -textvariable ${ns}::GUISettings($token)]
				dset GUISettings($token) 0
				grid $label $entry -sticky w
			}

			bool {
				set cbt   [ttk::checkbutton $topframe.cbt${field} -variable ${ns}::GUISettings($token) -text $labeltext]
				dset GUISettings($token) 0
				grid $cbt - -sticky nsew

				# bool needs to be normalized to 0/1
				if { ![string is bool -strict $GUISettings($token)] } {
					set GUISettings($token) 0
				} else {
					if { $GUISettings($token) } { set GUISettings($token) 1 } else { set GUISettings($token) 0 }
				}
			}

			choice {
				set frame  [ttk::frame  $topframe.frm${field}]
				set label  [ttk::label  $topframe.lbl${field} -text $labeltext]

				foreach { radioLabel value } $payload {
					set rbt   [ttk::radiobutton $frame.rbt${field} -text $radioLabel -variable ${ns}::GUISettings($token) -value $value]
					incr field
				}

				dset GUISettings($token) ""
				grid {*}[winfo children $frame] -sticky ew
				#grid columnconfigure $frame $entry -weight 1
				grid $label $frame -sticky ew
			}

			infostring {
				set label [ttk::label $topframe.lbl${field} -textvariable ${ns}::GUISettings($token)]
				dset GUISettings($token) 0
				grid $label - -sticky nsew
			}

			file {
				set frame  [ttk::frame  $topframe.frm${field}]
				set label  [ttk::label  $topframe.lbl${field} -text $labeltext]
				set entry  [ttk::entry     $frame.ent${field} -textvariable ${ns}::GUISettings($token)]
				set button [ttk::button    $frame.btn${field} -command [list ${ns}::OpenFile $token $payload] -text "..." -image [aRTist::IconGet document-open-folder $iconsize] -style Toolbutton]
				dset GUISettings($token) ""
				grid {*}[winfo children $frame] -sticky ew
				grid columnconfigure $frame $entry -weight 1
				grid $label $frame -sticky ew
			}

			folder {
				set frame  [ttk::frame  $topframe.frm${field}]
				set label  [ttk::label  $topframe.lbl${field} -text $labeltext]
				set entry  [ttk::entry     $frame.ent${field} -textvariable ${ns}::GUISettings($token)]
				set button [ttk::button    $frame.btn${field} -command [list ${ns}::OpenFolder $token $payload] -text "..." -image [aRTist::IconGet document-open-folder $iconsize] -style Toolbutton]
				dset GUISettings($token) ""
				grid {*}[winfo children $frame] -sticky ew
				grid columnconfigure $frame $entry -weight 1
				grid $label $frame -sticky ew
			}

			buttons {
				set frame  [ttk::frame  $topframe.frm${field}]
				set label  [ttk::label  $topframe.lbl${field} -text $labeltext]
				#set entry  [ttk::entry     $frame.ent${field} -textvariable ${ns}::GUISettings($token)]

				set i 0
				foreach { name command width } $payload {
					set btnCmd $ns
					append btnCmd "::"
					append btnCmd $command
					puts "Command: $btnCmd"
					set nr [expr $field*1000 + $i]
					set button [ttk::button $frame.btn${nr} -command $btnCmd -text "$name" -width $width ]
					incr i
				}

				dset GUISettings($token) ""
				grid {*}[winfo children $frame] -sticky ew
				#grid columnconfigure $frame $entry -weight 1
				grid $label $frame -sticky ew

			}

			dynlist -
			list {

				set label [ttk::label $topframe.lbl${field} -text $labeltext]
				set cbx   [ttk::combobox $topframe.cbx${field} -textvariable ${ns}::GUISettings($token) -state readonly -exportselection 0]
				dset GUISettings($token) ""

				if { $type == "dynlist" } {
					$cbx configure -postcommand [list $payload $cbx]
				} else {
					$cbx configure -values $payload
				}

				grid $label $cbx -sticky nsw

			}

			default { error "Unknown scalar type $type" }

		}

		lappend GUITokens $token

	}

	grid columnconfigure $topframe { 0 1 } -weight 1 -uniform width

}

proc OpenFile { token mask } {

	variable toplevel
	variable BasePath
	variable GUISettings

	set fname [file normalize [file join $BasePath $GUISettings($token)]]
	set fname [tk_getOpenFile -parent $toplevel -filetypes $mask -initialdir [file dirname $fname] -initialfile [file tail $fname]]
	if { $fname != "" } { set GUISettings($token) [Utils::GetRelativePath $fname $BasePath] }
}

proc OpenFolder { token mask } {

	variable toplevel
	variable BasePath
	variable GUISettings

	set fname [tk_chooseDirectory -parent $toplevel -initialdir {$GUISettings($token)}]
	if { $fname != "" } { set GUISettings($token) [Utils::GetRelativePath $fname $BasePath] }
}

proc ChooseFile { mask } {
	variable toplevel
	variable BasePath
	variable GUISettings

	set fname [tk_getOpenFile -parent $toplevel -filetypes $mask]

	if { $fname != "" } {
		return [Utils::GetRelativePath $fname $BasePath]
	}

	return ""
}

proc ChooseFiles { mask } {
	variable toplevel
	variable BasePath
	variable GUISettings

	set fnames [tk_getOpenFile -parent $toplevel -filetypes $mask -multiple 1]

	if { $fnames != "" } {
		set namesList { }

		foreach fname $fnames {
			if { $fname != "" } {
				lappend namesList [Utils::GetRelativePath $fname $BasePath]
			}
		}

		return $namesList
	} else {
		return ""
	}
}

proc InitGUI { parent } {

	variable ns
	variable toplevel $parent
	variable GUISettings
	variable options
	variable GUITokens {}
	variable OffColor #BEBEBE

	set moduleInfo [Info]
	set modulename [dict get $moduleInfo Description]
	set version [dict get $moduleInfo Version]
	set GUISettings(versionLine) "Version $version"

	aRTist::setwindowtitle $parent "CTSimU Scenario Loader"

	set pad       [aRTist::GetPadding]
	set iconsize  [Preferences::Get IconSize Button]

	set main      [ttk::frame $parent.frmMain -padding $pad]
	set note      [ttk::notebook $main.nbkMain]
	set model     [ttk::frame $note.frmModel -padding $pad]
	set batch     [ttk::frame $note.frmBatch -padding $pad]
	set settings  [ttk::frame $note.frmSettings -padding $pad]

	set general   [FoldFrame $model.frmGeneral -text "General"     -padding $pad]
	dataform $general {
		{JSON File}   jsonfile    file   { { {CTSimU Scenario} .json } }
		{ }                      loadbtn     buttons { "Load" loadScene_GUI 10 }
	}

	set CTProjection  [FoldFrame $model.frmCTProjection -text "CT Projection"     -padding $pad]
	dataform $CTProjection {
		{Start angle}          startAngle     integer   {° deg}
		{Stop angle}           stopAngle      integer   {° deg}
		{Projections}          nProjections   integer   {}
		{Display frame nr.} projNr      integer   {}
		{Final projection is taken at stop angle}  includeFinalAngle  bool   { }
		{ } projBtns       buttons { "Show frame" showProjection_GUI 12 "<" prevProjection 3 ">" nextProjection 3 }
	}

	set CTScan  [FoldFrame $model.frmCTScan -text "Simulation"     -padding $pad]
	dataform $CTScan {
		{Output folder}           outputFolder        folder   {}
		{Projection base name}    outputBaseName      string   {}
		{Start at projection nr.} startProjNr         integer  {}
		{Scatter image interval}  scatterImgInterval  integer  {}
		{File format}             fileFormat          choice   { "TIFF" "tiff" "RAW" "raw" }
		{Data type}               dataType            choice   { "uint16" "uint16" "float32" "float32" }
		{ }                       scanBtn             buttons  { "Run scenario" startScan 12 "Stop" stopScan 7 }
	}

	set buttons [ttk::frame $general.frmButtons]
	grid $buttons - -sticky snew

	foreach item [winfo children $model] { grid $item -sticky snew }



	set batchListGroup   [FoldFrame $batch.frmBatchList  -text "Job List"  -padding $pad]

	variable batchList $batchListGroup.tblJobs
	tablelist::tablelist $batchList -stretch all -selectmode extended -exportselection 0 \
		-width 24 -height 6 -xscroll [list $batchListGroup.sclX set] -yscroll [list $batchListGroup.sclY set] \
		-columns [list 0 "Job" left 0 "Status" left 0 "Runs" left 0 "StartRun" left 0 "StartProjNr" left 0 "JSON Scenario" left 0 "Output Format" left 0 "Output Folder" left 0 "Projection Base Name" left  ] \
		-movablecolumns 0 -movablerows 0 -setgrid 0 -showseparators 1 \
		-editstartcommand ${ns}::startEdit
	ttk::scrollbar $batchListGroup.sclY -orient vertical   -command [list $batchList yview]
	ttk::scrollbar $batchListGroup.sclX -orient horizontal -command [list $batchList xview]

	$batchList columnconfigure 0 -name "Job"                -editable 0 -editwindow ttk::entry
	$batchList columnconfigure 1 -name "Status"             -editable 1 -editwindow ttk::combobox
	$batchList columnconfigure 2 -name "Runs"               -editable 1 -editwindow ttk::entry
	$batchList columnconfigure 3 -name "StartRun"           -editable 1 -editwindow ttk::entry
	$batchList columnconfigure 4 -name "StartProjNr"        -editable 1 -editwindow ttk::entry
	$batchList columnconfigure 5 -name "JSONFile"           -editable 1 -editwindow ttk::entry
	$batchList columnconfigure 6 -name "OutputFormat"       -editable 1 -editwindow ttk::combobox
	$batchList columnconfigure 7 -name "OutputFolder"       -editable 1 -editwindow ttk::entry
	$batchList columnconfigure 8 -name "ProjectionBaseName" -editable 1 -editwindow ttk::entry

	set buttons [ttk::frame $batchListGroup.frmButtons]
	ttk::button $buttons.btnAdd -command ${ns}::addBatchJob    {*}[aRTist::ToolbuttonOptions "Add" list-add $iconsize]
	ttk::button $buttons.btnDel -command ${ns}::deleteBatchJob {*}[aRTist::ToolbuttonOptions "Remove" list-remove $iconsize]
	ttk::button $buttons.btnRunBatch -command ${ns}::runBatch  {*}[aRTist::CompoundOptions "Run" compute-run $iconsize] -width 5
	ttk::button $buttons.btnStopBatch -command ${ns}::stopBatch {*}[aRTist::CompoundOptions "Stop" compute-stop $iconsize] -width 5
	ttk::button $buttons.btnSaveJobList -command ${ns}::saveBatchJobs_user {*}[aRTist::CompoundOptions "Save List..." document-save $iconsize] -width 8
	ttk::button $buttons.btnLoadJobList -command ${ns}::loadBatchJobs {*}[aRTist::CompoundOptions "Import..." document-open $iconsize] -width 8
	ttk::button $buttons.btnClearJobList -command ${ns}::clearBatchList {*}[aRTist::CompoundOptions "Clear" document-close $iconsize] -width 5
	grid {*}[winfo children $buttons] -sticky snew

	grid $batchList $batchListGroup.sclY -sticky snew
	grid $batchListGroup.sclX -sticky snew
	grid $buttons - -sticky snew
	foreach dir { row column } { grid ${dir}configure $batchListGroup $batchList -weight 1 }

	foreach item [winfo children $batch] { grid $item -sticky snew }
	foreach dir { row column } { grid ${dir}configure $batch $batchListGroup -weight 1 }


	set generalCfgGroup   [FoldFrame $settings.frmGeneralCfg  -text "General"  -padding $pad]
	dataform $generalCfgGroup {
		{Show stage coordinate system in scene}       showStageInScene     bool   { }
		{Restart aRTist after each batch run}         restartArtistAfterBatchRun   bool   { }
		{Skip simulation, only create config files}   skipSimulation     bool   { }
	}
	set buttons [ttk::frame $generalCfgGroup.frmButtons]
	grid $buttons - -sticky snew


	set ceraCfgGroup   [FoldFrame $settings.frmCeraCfg  -text "CERA Reconstruction"  -padding $pad]
	dataform $ceraCfgGroup {
		{Create CERA config file}   cfgFileCERA          bool   { }
		{CERA volume data type}     ceraOutputDatatype   choice { "uint16" "uint16" "float32" "float32" }
	}
	set buttons [ttk::frame $ceraCfgGroup.frmButtons]
	grid $buttons - -sticky snew

	set openctCfgGroup   [FoldFrame $settings.frmOpenCTCfg  -text "openCT Reconstruction"  -padding $pad]
	dataform $openctCfgGroup {
		{Create OpenCT config file} cfgFileOpenCT        bool   { }
		{Use absolute file paths}   openctAbsPaths       bool   { }
		{Run flat/dark correction in reconstruction software}   openctUncorrected   bool   { }
		{Enforce circular format instead of free trajectory}   openctCircularEnforced   bool   { }
	}
#		{OpenCT volume data type}   openctOutputDatatype choice { "uint16" "uint16" "float32" "float32" }
	set buttons [ttk::frame $openctCfgGroup.frmButtons]
	grid $buttons - -sticky snew

	set clfdkCfgGroup   [FoldFrame $settings.frmCLFDKCfg  -text "clFDK Reconstruction"  -padding $pad]
	dataform $clfdkCfgGroup {
		{Create clFDK run script}  cfgFileCLFDK         bool   { }
		{clFDK volume data type}   clfdkOutputDatatype  choice { "uint16" "uint16" "float32" "float32" }
	}
	set buttons [ttk::frame $clfdkCfgGroup.frmButtons]
	grid $buttons - -sticky snew

	foreach item [winfo children $settings] { grid $item -sticky snew }


	$note add $model    -text "CT Setup" -sticky snew
	$note add $batch    -text "Batch Processing" -sticky snew
	$note add $settings -text "Settings" -sticky snew

	set buttons [ttk::frame $main.frmButtons]
	#ttk::button $buttons.btnOk -text "OK" -command ${ns}::GUIok
	#ttk::button $buttons.btnCancel -text "Close" -command ${ns}::GUIcancel
	#ttk::label $buttons.lblVer -text "     $GUISettings(versionLine)"
	ttk::label $buttons.lblStatus -textvariable ${ns}::GUISettings(statusLine)
	dock::dockhandle $buttons.dockHandle -window $parent

	grid {*}[winfo children $buttons] -sticky e
	grid columnconfigure $buttons $buttons.dockHandle -weight 1

	foreach item [winfo children $main] { grid $item -sticky snew }
	foreach dir { row column } { grid ${dir}configure $main $note -weight 1 }

	grid $main -sticky snew
	foreach dir { row column } { grid ${dir}configure $parent $main -weight 1 }

	showInfo "$GUISettings(versionLine)"
}

proc startEdit { table row col text } {

	set widget [$table editwinpath]

	switch -- [$table columncget $col -name] {

		OutputFormat {
			$widget configure -state readonly -values {"RAW uint16" "RAW float32" "TIFF uint16" "TIFF float32"}
			bind $widget <<ComboboxSelected>> [list $table finishediting]
		}

		Status {
			$widget configure -state readonly -values {"Done" "Inactive" "Pending"}
			bind $widget <<ComboboxSelected>> [list $table finishediting]
		}
	}

	return $text

}

proc GUIcancel {} {
	# close window
	variable toplevel
	destroy $toplevel
}

proc GUIok {} {
	variable toplevel
	variable GUISettings

	loadScene_GUI
	showProjection_GUI
}

# ----------------------------------------------
#  Connectors between frontend and backend
# ----------------------------------------------

proc loadedSuccessfully { } {
	variable ctsimu_scenario

	if [$ctsimu_scenario json_loaded_successfully] {
		return 1
	}

	fail "Please load a CTSimU scene from a JSON file first."
	return 0
}

proc showInfo { infotext } {
	# Displays $infotext in the bottom of the module GUI
	variable GUISettings
	set GUISettings(statusLine) $infotext
	update
}

proc fillCurrentParameters {} {
	# Fill GUI elements with parameters stored in $ctsimu_scenario
	variable GUISettings
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	set GUISettings(jsonfile)             [$ctsimu_scenario get json_file]
	set GUISettings(startAngle)           [$ctsimu_scenario get start_angle]
	set GUISettings(stopAngle)            [$ctsimu_scenario get stop_angle]
	set GUISettings(nProjections)         [$ctsimu_scenario get n_projections]
	set GUISettings(projNr)               [$ctsimu_scenario get current_frame]
	set GUISettings(outputBaseName)       [$ctsimu_scenario get output_basename]
	set GUISettings(outputFolder)         [$ctsimu_scenario get output_folder]
	set GUISettings(fileFormat)           [$ctsimu_scenario get output_fileformat]
	set GUISettings(dataType)             [$ctsimu_scenario get output_datatype]
	set GUISettings(includeFinalAngle)    [$ctsimu_scenario get include_final_angle]
	set GUISettings(startProjNr)          [$ctsimu_scenario get start_projection_number]

	set GUISettings(scatterImgInterval)   [$ctsimu_scenario get scattering_image_interval]

	# General settings
	set GUISettings(showStageInScene)     [$ctsimu_scenario get show_stage]
	set GUISettings(restartArtistAfterBatchRun)  [$ctsimu_batchmanager get restart_aRTist_after_each_run]
	set GUISettings(skipSimulation)       [$ctsimu_scenario get skip_simulation]

	# Recon settings
	set GUISettings(cfgFileCERA)          [$ctsimu_scenario get create_cera_config_file]
	set GUISettings(ceraOutputDatatype)   [$ctsimu_scenario get cera_output_datatype]

	set GUISettings(cfgFileOpenCT)         [$ctsimu_scenario get create_openct_config_file]
#	set GUISettings(openctOutputDatatype)  [$ctsimu_scenario get openct_output_datatype]
	set GUISettings(openctAbsPaths)        [$ctsimu_scenario get openct_abs_paths]
	set GUISettings(openctUncorrected)     [$ctsimu_scenario get openct_uncorrected]
	set GUISettings(openctCircularEnforced) [$ctsimu_scenario get openct_circular_enforced]

	set GUISettings(cfgFileCLFDK)         [$ctsimu_scenario get create_clfdk_config_file]
	set GUISettings(clfdkOutputDatatype)  [$ctsimu_scenario get clfdk_output_datatype]
}

proc applyCurrentSettings {} {
	# Store the parameters that are defined by the user in the settings pane,
	# both in $ctsimu_scenario and in the module's preferences.
	variable GUISettings
	variable batchList
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	$ctsimu_scenario set show_stage                $GUISettings(showStageInScene)
	$ctsimu_batchmanager set restart_aRTist_after_each_run $GUISettings(restartArtistAfterBatchRun)
	$ctsimu_scenario set skip_simulation           $GUISettings(skipSimulation)

	$ctsimu_scenario set create_cera_config_file   $GUISettings(cfgFileCERA)
	$ctsimu_scenario set cera_output_datatype      $GUISettings(ceraOutputDatatype)

	$ctsimu_scenario set create_openct_config_file $GUISettings(cfgFileOpenCT)
#	$ctsimu_scenario set openct_output_datatype    $GUISettings(openctOutputDatatype)
	$ctsimu_scenario set openct_abs_paths          $GUISettings(openctAbsPaths)
	$ctsimu_scenario set openct_uncorrected        $GUISettings(openctUncorrected)
	$ctsimu_scenario set openct_circular_enforced   $GUISettings(openctCircularEnforced)

	$ctsimu_scenario set create_clfdk_config_file  $GUISettings(cfgFileCLFDK)
	$ctsimu_scenario set clfdk_output_datatype     $GUISettings(clfdkOutputDatatype)

	$ctsimu_scenario set output_fileformat         $GUISettings(fileFormat)
	$ctsimu_scenario set output_datatype           $GUISettings(dataType)

	$ctsimu_batchmanager set_batch_list $batchList
	$ctsimu_batchmanager sync_batchlist_into_manager
	$ctsimu_batchmanager set standard_output_fileformat $GUISettings(fileFormat)
	$ctsimu_batchmanager set standard_output_datatype   $GUISettings(dataType)

	# Create a settings dict for aRTist:
	dict set storeSettings fileFormat    [$ctsimu_scenario get output_fileformat]
	dict set storeSettings dataType      [$ctsimu_scenario get output_datatype]

	dict set storeSettings showStageInScene  [$ctsimu_scenario get show_stage]
	dict set storeSettings skipSimulation    [$ctsimu_scenario get skip_simulation]
	dict set storeSettings restartArtistAfterBatchRun [$ctsimu_batchmanager get restart_aRTist_after_each_run]
	dict set storeSettings waitingForRestart [$ctsimu_batchmanager get waiting_for_restart]
	dict set storeSettings nextBatchRun      [$ctsimu_batchmanager get next_run]
	dict set storeSettings csvJobList        [$ctsimu_batchmanager csv_joblist 1]

	dict set storeSettings cfgFileCERA        [$ctsimu_scenario get create_cera_config_file]
	dict set storeSettings ceraOutputDatatype [$ctsimu_scenario get cera_output_datatype]

	dict set storeSettings cfgFileOpenCT [$ctsimu_scenario get create_openct_config_file]
#	dict set storeSettings openctOutputDatatype [$ctsimu_scenario get openct_output_datatype]
	dict set storeSettings openctAbsPaths [$ctsimu_scenario get openct_abs_paths]
	dict set storeSettings openctUncorrected [$ctsimu_scenario get openct_uncorrected]
	dict set storeSettings openctCircularEnforced [$ctsimu_scenario get openct_circular_enforced]

	dict set storeSettings cfgFileCLFDK [$ctsimu_scenario get create_clfdk_config_file]
	dict set storeSettings clfdkOutputDatatype [$ctsimu_scenario get clfdk_output_datatype]

	# Save the settings dict in preferences file:
	Preferences::Set CTSimU Settings $storeSettings
}

proc applyCurrentParameters {} {
	# Take parameters from GUI and store them in $ctsimu_scenario.
	variable GUISettings
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	$ctsimu_scenario set json_file                 $GUISettings(jsonfile)
	$ctsimu_scenario set start_angle               $GUISettings(startAngle)
	$ctsimu_scenario set stop_angle                $GUISettings(stopAngle)
	$ctsimu_scenario set n_projections             $GUISettings(nProjections)
	$ctsimu_scenario set current_frame             $GUISettings(projNr)
	$ctsimu_scenario set include_final_angle       $GUISettings(includeFinalAngle)
	$ctsimu_scenario set start_projection_number   $GUISettings(startProjNr)
	$ctsimu_scenario set scattering_image_interval $GUISettings(scatterImgInterval)

	applyCurrentSettings
}

proc setFrameNumber { nr } {
	variable GUISettings
	set GUISettings(projNr) $nr
}


# ------------------------------
#  Batch Jobs
# ------------------------------

proc saveBatchJobs_user { } {
	# Opens a file dialog to choose a CSV file
	# to save the batch list.
	set filename [tk_getSaveFile -title "Save Current Batch" -filetypes { { {Comma separated} .csv } } -initialfile "batch.csv"]

	if { $filename != "" } {
		saveBatchJobs $filename
	}
}

proc saveBatchJobs { csv_filename } {
	variable ctsimu_batchmanager

	# Send batchlist reference to batch manager:
	applyCurrentParameters

	$ctsimu_batchmanager sync_batchlist_into_manager
	$ctsimu_batchmanager save_batch_jobs $csv_filename
}

proc loadBatchJobs { } {
	# Opens a file dialog to choose CSV batch list:
	set csvFilename [ChooseFile { { {Comma separated} .csv } } ]

	if { $csvFilename != "" } {
		importBatchJobs $csvFilename
	}
}

proc importBatchJobs { csv_filename } {
	# Import the batch jobs specified in the given CSV file.
	# Note that these jobs will be added after any jobs that are already in the queue.
	variable ctsimu_batchmanager

	# Send batchlist reference to batch manager:
	applyCurrentParameters

	$ctsimu_batchmanager import_batch_jobs $csv_filename
}

proc addBatchJob { } {
	# Opens GUI dialog for the user to select a JSON file to add to the batch list.
	variable ctsimu_batchmanager

	# Choose a JSON file:
	set jsonFileNames [ChooseFiles { { {CTSimU Scenario} .json } } ]

	# Sets the currently selected file type
	# and data type as standard values for the batch manager:
	applyCurrentParameters

	foreach jsonFileName $jsonFileNames {
		$ctsimu_batchmanager add_batch_job_from_json $jsonFileName
	}
}

proc insertBatchJob { jsonFileName {runs 1} {startRun 1} {startProjectionNumber 0} {format "RAW uint16"} {outputFolder ""} {outputBasename ""} {status "Pending"} } {
	# Insert a batch job at the end of the batch list.
	# The parameters are the same as the ones from the GUI.
	variable ctsimu_batchmanager

	# Sets the currently selected file type
	# and data type as standard values for the batch manager:
	applyCurrentParameters

	set bj [::ctsimu::batchjob new]
	$bj set_from_json $jsonFileName
	$bj set status $status
	$bj set runs $runs
	$bj set start_run $startRun
	$bj set start_projection_number $startProjectionNumber
	$bj set_format $format

	if {$outputFolder != ""} {
		$bj set output_folder $outputFolder
	}

	if {$outputBasename != ""} {
		$bj set output_basename $outputBasename
	}

	$ctsimu_batchmanager add_batch_job $bj
}

proc clearBatchList { } {
	# Remove all batch jobs from the list.
	variable ctsimu_batchmanager
	$ctsimu_batchmanager clear
}

proc deleteBatchJob { } {
	# Removes the selected job(s) from the queue.
	variable batchList
	variable ctsimu_batchmanager

	set items [$batchList curselection]
	if { $items != {} } { $batchList delete $items }

	# Set job numbers anew...
	set id 1
	foreach index [$batchList childkeys root] {
		$batchList cellconfigure $index,Job -text "$id"
		incr id
	}

	$ctsimu_batchmanager sync_batchlist_into_manager
}

proc stopBatch { } {
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	$ctsimu_scenario stop_scan
	$ctsimu_batchmanager stop_batch
}

proc runBatch { } {
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	applyCurrentSettings
	::Preferences::Write
	$ctsimu_batchmanager sync_batchlist_into_manager
	$ctsimu_batchmanager run_batch $ctsimu_scenario
}

# ----------------------------------------------
#  Single scenario loading and handling
# ----------------------------------------------

proc loadScene_GUI { } {
	# Loads the JSON file that has been chosen from the GUI.
	variable GUISettings
	loadScene $GUISettings(jsonfile)
}

proc loadScene { json_filename } {
	variable GUISettings
	variable ctsimu_scenario

	stopScan

	applyCurrentParameters
	::aRTist::LoadEmptyProject

	set sceneState [$ctsimu_scenario load_json_scene $json_filename]

	# Continue only if JSON was loaded successfully:
	if { $sceneState == 1 } {
		::ctsimu::status_info "Setting scene for first frame..."
		fillCurrentParameters
		::SceneView::ViewAllCmd
		showProjection_GUI
		::ctsimu::status_info "Ready."
	}
}

proc showProjection_GUI {} {
	variable ctsimu_scenario

	applyCurrentParameters
	$ctsimu_scenario set_frame [$ctsimu_scenario get current_frame]
}

proc showProjection { projection_nr } {
	variable ctsimu_scenario

	applyCurrentParameters
	$ctsimu_scenario set current_frame $projection_nr
	$ctsimu_scenario set_frame $projection_nr
}

proc nextProjection {} {
	variable ctsimu_scenario

	applyCurrentParameters
	$ctsimu_scenario set_next_frame
}

proc prevProjection {} {
	variable ctsimu_scenario

	applyCurrentParameters
	$ctsimu_scenario set_previous_frame
}

proc startScan {} {
	variable GUISettings
	variable ctsimu_scenario

	applyCurrentParameters

	$ctsimu_scenario set output_folder $GUISettings(outputFolder)
	$ctsimu_scenario set output_basename $GUISettings(outputBaseName)
	$ctsimu_scenario start_scan
}

proc stopScan {} {
	variable ctsimu_scenario
	variable ctsimu_batchmanager

	$ctsimu_scenario stop_scan
	$ctsimu_batchmanager stop_batch
}

proc setProperty { property value } {
	if { $property == {restart_aRTist_after_each_run} } {
		# This is a property of the batch manager.
		variable ctsimu_batchmanager
		$ctsimu_batchmanager set $property $value
	} else {
		# Other properties are stored in the scenario object.
		variable ctsimu_scenario
		$ctsimu_scenario set $property $value
	}

	fillCurrentParameters
}

proc kickOff { } {
	# A kick-off function to execute after an aRTist restart.
	# Used by the batch manager to resume batch execution.
	variable ctsimu_batchmanager

	if { [$ctsimu_batchmanager get waiting_for_restart] == 1 } {
		Run

		# Take care of batch manager:
		variable batchList
		variable ctsimu_scenario
		$ctsimu_batchmanager set_batch_list $batchList
		$ctsimu_batchmanager kick_off $ctsimu_scenario
	}
}