# main file for startup within aRTist

# remember namespace
variable ns [namespace current]
variable BasePath [file dirname [info script]]

proc Info {} {
	return [dict create \
		Name        CTSimU \
		Description "CTSimU Scenario Loader" \
		Version     "1.0.0" \
	]
}

# requires the rl_json package which ships with aRTist since version 2.10.2
package require rl_json
package require csv
package require fileutil

# Source the CTSimU namespace and tell it the module namespace:
source [file join $BasePath ctsimu_main.tcl]
::ctsimu::set_module_namespace $ns

# The currently loaded CTSimU scenario:
variable ctsimu_scenario
set ctsimu_scenario [::ctsimu::scenario new]

proc Settings { args } {
	variable GUISettings

	switch -- [llength $args] {
		0 { return [array get GUISettings] }
		1 { Utils::UpdateArray GUISettings [lindex $args 0] }
		default { Utils::UpdateArray GUISettings $args }
	}

}

proc Init {} {
	variable ns
	variable ctsimu_scenario
	variable GUISettings
	variable CacheFiles [dict create]

	# Load preferences dict (stored by aRTist):
	Utils::nohup { Settings [Preferences::GetWithDefault CTSimU Settings {}] }

	set prefs [Preferences::GetWithDefault CTSimU Settings {}]

	if {[dict exists $prefs fileFormat]} {
		$ctsimu_scenario set output_fileformat [dict get $prefs fileFormat]
	}

	if {[dict exists $prefs dataType]} {
		$ctsimu_scenario set output_datatype [dict get $prefs dataType]
	}

	if {[dict exists $prefs cfgFileCERA]} {
		$ctsimu_scenario set create_cera_config_file [dict get $prefs cfgFileCERA]
	}
	
	if {[dict exists $prefs ceraOutputDatatype]} {
		$ctsimu_scenario set cera_output_datatype [dict get $prefs ceraOutputDatatype]
	}

	if {[dict exists $prefs cfgFileOpenCT]} {
		$ctsimu_scenario set create_openct_config_file [dict get $prefs cfgFileOpenCT]
	}
	
	if {[dict exists $prefs	openctOutputDatatype]} {
		$ctsimu_scenario set openct_output_datatype [dict get $prefs openctOutputDatatype]
	}

	# Feed the imported settings (so far) to the GUI:
	fillCurrentParameters

	return [Info]
}

# main entry point for aRTist
proc Run {} {
	variable ns
	return [Modules::make_window .ctsimu ${ns}::InitGUI]
}

proc Running {} {
	variable toplevel
	if { [info exists toplevel] && [winfo exists $toplevel] } { return true}
	return false
}

proc CanClose {} {
	variable ctsimu_scenario
	if {[$ctsimu_scenario batch_is_running] == 1} {
		return false
	}

	if {[$ctsimu_scenario is_running] == 1} {
		return false
	}

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
		{ }                      loadbtn     buttons { "Load" loadCTSimUScene 10 }
	}

	set CTProjection  [FoldFrame $model.frmCTProjection -text "CT Projection"     -padding $pad]
	dataform $CTProjection {
		{Start Angle}          startAngle     integer   {° deg}
		{Stop Angle}           stopAngle      integer   {° deg}
		{Projections}          nProjections   integer   {}
		{Display Projection #} projNr      integer   {}
		{Final projection is taken at stop angle}  includeFinalAngle  bool   { }
		{ } projBtns       buttons { "Show" showProjection 7 "<" prevProjection 3 ">" nextProjection 3 }
	}

	set CTScan  [FoldFrame $model.frmCTScan -text "Simulation"     -padding $pad]
	dataform $CTScan {
		{Output Folder}           outputFolder    folder   {}
		{Projection Base Name}    outputBaseName  string   {}
		{Start at Projection Nr.} startProjNr     integer  {}
		{File Format}             fileFormat      choice   { "TIFF" "tiff" "RAW" "raw" }
		{Data Type}               dataType        choice   { "uint16" "16bit" "float32" "32bit" }
		{Save ideal dark field}   takeDarkField   bool     {}
		{Flat field images}       nFlatFrames     integer  {}
		{Flat frames to average}  nFlatAvg        integer  {}
		{Flat field mode}         ffIdeal         choice   { "Regular" 0 "Ideal" 1 }
		{ }                       scanBtn         buttons  { "Run scenario" startScan 12 "Stop" CTSimU_stopScan 7 }
	}
	
#	set infoFrame   [FoldFrame $model.frmInfo -text "Status"     -padding $pad]
#	dataform $infoFrame {
#		{Hallo}                  statusLine  infostring { }
#	}

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
	ttk::button $buttons.btnSaveJobList -text "Save List..." -command ${ns}::saveBatchJobs_user
	ttk::button $buttons.btnLoadJobList -text "Import..." -command ${ns}::loadBatchJobs
	grid {*}[winfo children $buttons] -sticky snew

	grid $batchList $batchListGroup.sclY -sticky snew
	grid $batchListGroup.sclX -sticky snew
	grid $buttons - -sticky snew
	foreach dir { row column } { grid ${dir}configure $batchListGroup $batchList -weight 1 }

	foreach item [winfo children $batch] { grid $item -sticky snew }
	foreach dir { row column } { grid ${dir}configure $batch $batchListGroup -weight 1 }



	set reconCfgGroup   [FoldFrame $settings.frmReconCfg  -text "Reconstruction"  -padding $pad]
	dataform $reconCfgGroup {
		{Create CERA config file}   cfgFileCERA          bool   { }
		{CERA volume data type}     ceraOutputDataType   choice { "uint16" "16bit" "float32" "32bit"}
		{Create OpenCT config file} cfgFileOpenCT         bool   { }
		{OpenCT volume data type}   openctOutputDataType choice { "uint16" "16bit" "float32" "32bit"}
	}

	set buttons [ttk::frame $reconCfgGroup.frmButtons]
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

	loadCTSimUScene
	showProjection
}

proc loadCTSimUScene {} {
	variable GUISettings
	variable ns
	variable ctsimu_scenario

	applyCurrentParameters
	aRTist::LoadEmptyProject
#	CTSimU::setModuleNamespace $ns

	set sceneState [$ctsimu_scenario load_json_scene $GUISettings(jsonfile)]

	# Continue only if JSON was loaded successfully:
	if { $sceneState == 1 } {
		fillCurrentParameters
#		showInfo "Scenario loaded."
#		showProjection
		$ctsimu_scenario set_frame 0 1
		Engine::RenderPreview
		::SceneView::ViewAllCmd
	}
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

	set GUISettings(jsonfile)             [$ctsimu_scenario get json_file]
	set GUISettings(startAngle)           [$ctsimu_scenario get start_angle]
	set GUISettings(stopAngle)            [$ctsimu_scenario get stop_angle]
	set GUISettings(nProjections)         [$ctsimu_scenario get n_projections]
	set GUISettings(projNr)               [$ctsimu_scenario get proj_nr]
	set GUISettings(outputBaseName)       [$ctsimu_scenario get output_basename]
	set GUISettings(outputFolder)         [$ctsimu_scenario get output_folder]
	set GUISettings(fileFormat)           [$ctsimu_scenario get output_fileformat]
	set GUISettings(dataType)             [$ctsimu_scenario get output_datatype]
	set GUISettings(includeFinalAngle)    [$ctsimu_scenario get include_final_angle]
	set GUISettings(startProjNr)          [$ctsimu_scenario get start_proj_nr]

	set GUISettings(takeDarkField)        [$ctsimu_scenario get dark_field]
	set GUISettings(nFlatFrames)          [$ctsimu_scenario get n_flats]
	set GUISettings(nFlatAvg)             [$ctsimu_scenario get n_darks]
	set GUISettings(ffIdeal)              [$ctsimu_scenario get flat_field_ideal]

	# Recon settings
	set GUISettings(cfgFileCERA)          [$ctsimu_scenario get create_cera_config_file]
	set GUISettings(ceraOutputDataType)   [$ctsimu_scenario get cera_output_datatype]

	set GUISettings(cfgFileOpenCT)        [$ctsimu_scenario get create_openct_config_file]
	set GUISettings(openctOutputDataType) [$ctsimu_scenario get openct_output_datatype]
}

proc applyCurrentSettings {} {
	# Store the parameters that are defined by the user in the settings pane,
	# both in $ctsimu_scenario and in the module's preferences.
	variable GUISettings
	variable ctsimu_scenario

	$ctsimu_scenario set create_cera_config_file   $GUISettings(cfgFileCERA)
	$ctsimu_scenario set cera_output_datatype      $GUISettings(ceraOutputDataType)

	$ctsimu_scenario set create_openct_config_file $GUISettings(cfgFileOpenCT)
	$ctsimu_scenario set openct_output_datatype    $GUISettings(openctOutputDataType)

	# Create a settings dict for aRTist:
	dict set storeSettings fileFormat    [$ctsimu_scenario get output_fileformat]
	dict set storeSettings dataType      [$ctsimu_scenario get output_datatype]

	dict set storeSettings cfgFileCERA   [$ctsimu_scenario get create_cera_config_file]
	dict set storeSettings ceraOutputDataType [$ctsimu_scenario get cera_output_datatype]

	dict set storeSettings cfgFileOpenCT [$ctsimu_scenario get create_openct_config_file]
	dict set storeSettings openctOutputDataType [$ctsimu_scenario get openct_output_datatype]

	# Save the settings dict in preferences file:
	Preferences::Set CTSimU Settings $storeSettings
}

proc applyCurrentParameters {} {
	# Take parameters from GUI and store them in $ctsimu_scenario.
	variable GUISettings
	variable ctsimu_scenario

	$ctsimu_scenario set json_file           $GUISettings(jsonfile)
	$ctsimu_scenario set start_angle         $GUISettings(startAngle)
	$ctsimu_scenario set stop_angle          $GUISettings(stopAngle)
	$ctsimu_scenario set n_projections       $GUISettings(nProjections)
	$ctsimu_scenario set proj_nr             $GUISettings(projNr)
	$ctsimu_scenario set include_final_angle $GUISettings(includeFinalAngle)
	$ctsimu_scenario set start_proj_nr       $GUISettings(startProjNr)

	$ctsimu_scenario set dark_field          $GUISettings(takeDarkField)
	$ctsimu_scenario set n_flats             $GUISettings(nFlatFrames)
	$ctsimu_scenario set n_flat_avg          $GUISettings(nFlatAvg)
	$ctsimu_scenario set flat_field_ideal    $GUISettings(ffIdeal)
	
	$ctsimu_scenario set output_fileformat   $GUISettings(fileFormat)
	$ctsimu_scenario set output_datatype     $GUISettings(dataType)

	applyCurrentSettings
}

proc setOutputParameters { file_format data_type output_folder projectionBasename } {
	variable ctsimu_scenario
	# file_format: "raw" or "tiff". Standard: "raw".
	# data_type: "16bit" or "32bit". Standard: "16bit"

	if { [string match -nocase "tiff" $file_format] } {
		$ctsimu_scenario set output_fileformat "tiff"
	} else {
		$ctsimu_scenario set output_fileformat "raw"
	}

	if { [string match -nocase "32bit" $data_type] } {
		$ctsimu_scenario set output_datatype "32bit"
	} else {
		$ctsimu_scenario set output_datatype "16bit"
	}

	if { [string length $output_folder] > 0 } {
		$ctsimu_scenario set output_folder $output_folder
	}

	if { [string length $projectionBasename] > 0 } {
		$ctsimu_scenario set output_basename $projectionBasename
	}

	fillCurrentParameters
}


# ------------------------------
#  Batch Jobs
# ------------------------------

proc saveBatchJobs_user { } {
	variable batchList
	set filename [tk_getSaveFile -title "Save Current Batch" -filetypes { { {Comma separated} .csv } } -initialfile "batch.csv"]

	if { $filename != "" } {
		saveBatchJobs $filename
	}
}

proc saveBatchJobs { csvFilename } {
	variable batchList

	if { $csvFilename != "" } {
		if {[string tolower [file extension $csvFilename]] != ".csv"} {
			append csvFilename ".csv"
		}

		set fileId [open $csvFilename "w"]
		puts $fileId "# JSON File,Output Format,Output Folder,Projection Base Name,Runs,StartRun,StartProjNr,Status"

		foreach index [$batchList childkeys root] {
			if { [catch {
				set jsonFilename       [$batchList cellcget $index,JSONFile  -text]
				set outputFormat       [$batchList cellcget $index,OutputFormat  -text]
				set output_folder       [$batchList cellcget $index,OutputFolder  -text]
				set projectionBasename [$batchList cellcget $index,ProjectionBaseName  -text]
				set nRuns              [$batchList cellcget $index,Runs  -text]
				set startRun           [$batchList cellcget $index,StartRun  -text]
				set startProjNr        [$batchList cellcget $index,StartProjNr  -text]
				set status             [$batchList cellcget $index,Status  -text]

				set csvLine [::csv::join [list $jsonFilename $outputFormat $output_folder $projectionBasename $nRuns $startRun $startProjNr $status ]]

				puts $fileId $csvLine

			} err] } {
				continue
			}
		}

		close $fileId
	}
}

proc loadBatchJobs { } {
	variable batchList

	# Choose a JSON file:
	set csvFilename [ChooseFile { { {Comma separated} .csv } } ]

	if { $csvFilename != "" } {
		importBatchJobs $csvFilename
	}
}

proc importBatchJobs { csvFilename } {
	variable batchList

	set csvfile [open $csvFilename r]
	fconfigure $csvfile -encoding utf-8
	set csvstring [read $csvfile]
	close $csvfile

	set lines [split $csvstring "\n"]
	foreach line $lines {
		# Check if line starts with a comment character:
		if {[string index $line 0] == "#"} {
			continue
		}

		set entries [::csv::split $line]

		if {[llength $entries] >= 4} {
			set jsonFilename       ""
			set outputFormat       ""
			set outputFolder       ""
			set projectionBasename ""
			set nRuns              "1"
			set startRun           "1"
			set startProjNr        "0"
			set status             "Pending"

			set i 0
			foreach entry $entries {
				if {$i == 0} {set jsonFilename $entry}
				if {$i == 1} {set outputFormat $entry}
				if {$i == 2} {set outputFolder $entry}
				if {$i == 3} {set projectionBasename $entry}
				if {$i == 4} {set nRuns $entry}
				if {$i == 5} {set startRun $entry}
				if {$i == 6} {set startProjNr $entry}
				if {$i == 7} {set status $entry}

				incr i
			}

			# Get number of jobs so far...
			set id 1
			foreach index [$batchList childkeys root] {
				incr id
			}

			set colEntries [list $id $status $nRuns $startRun $startProjNr $jsonFilename $outputFormat $outputFolder $projectionBasename ]
			$batchList insert end $colEntries
		}
	}
}

proc addBatchJob { } {
	variable batchList
	variable GUISettings

	# Choose a JSON file:
	set jsonFileNames [ChooseFiles { { {CTSimU Scenario} .json } } ]

	foreach jsonFileName $jsonFileNames {
		if { $jsonFileName != "" } {
			set formatString "RAW "
			if { $GUISettings(fileFormat) == "tiff" } {
				set formatString "TIFF "
			}

			if { $GUISettings(dataType) == "32bit" } {
				append formatString "float32"
			} else {
				append formatString "uint16"
			}

			# Get number of jobs so far...
			set id 1
			foreach index [$batchList childkeys root] {
				incr id
			}

			set colEntries [list $id "Pending" "1" "1" "0" $jsonFileName]
			lappend colEntries $formatString
			lappend colEntries [getOutputFolderFromJSONfilename $jsonFileName]
			lappend colEntries [getOutputBasenameFromJSONfilename $jsonFileName]

			$batchList insert end $colEntries
		}
	}
}

proc clearBatchList { } {
	variable batchList
	foreach index [$batchList childkeys root] {
		$batchList delete $index
	}
}

proc deleteBatchJob { } {
	variable batchList
	set items [$batchList curselection]
	if { $items != {} } { $batchList delete $items }

	# Set job numbers anew...
	set id 1
	foreach index [$batchList childkeys root] {
		$batchList cellconfigure $index,Job -text "$id"
		incr id
	}
}

proc stopBatch { } {
	variable ctsimu_scenario
	$ctsimu_scenario set_batch_run_status 0
	CTSimU_stopScan
}

proc runBatch { } {
	variable ctsimu_scenario

	if {[$ctsimu_scenario batch_is_running] == 0} {
		$ctsimu_scenario set_batch_run_status 1
		applyCurrentSettings

		set nJobsDone 0

		foreach index [$batchList childkeys root] {
			if { [catch {
				set jobNr              [$batchList cellcget $index,Job  -text]
				set status             [$batchList cellcget $index,Status  -text]
				set nRuns              [$batchList cellcget $index,Runs  -text]
				set startRun           [$batchList cellcget $index,StartRun  -text]
				set startProjNr        [$batchList cellcget $index,StartProjNr  -text]
				set jsonFilename       [$batchList cellcget $index,JSONFile  -text]
				set outputFormat       [$batchList cellcget $index,OutputFormat  -text]
				set outputFolder       [$batchList cellcget $index,OutputFolder  -text]
				set projectionBasename [$batchList cellcget $index,ProjectionBaseName  -text]
			} err] } {
				continue
			}

			if {$status == "Pending"} {
				if {$nRuns > 0} {
					set file_format "raw"
					set data_type "16bit"

					if { $outputFormat == "RAW float32" } {
						set data_type "32bit"
					} elseif { $outputFormat == "TIFF float32" } {
						set data_type "32bit"
						set file_format "tiff"
					} elseif { $outputFormat == "TIFF uint16" } {
						set file_format "tiff"
					}

					$batchList cellconfigure $index,Status -text "Running $startRun/$nRuns"

					if { [catch {
						loadFullScenario $jsonFilename
					} err] } {
						$batchList cellconfigure $index,Status -text "ERROR"
						continue
					}

					CTSimU::setStartProjNr $startProjNr

					for {set run $startRun} {$run <= $nRuns } {incr run} {
						$batchList cellconfigure $index,Status -text "Stopped"
						if {[$ctsimu_scenario batch_is_running] == 0} {
							return
						}

						$batchList cellconfigure $index,Status -text "Running $run/$nRuns"

						set runBasename $projectionBasename
						set runName ""

						if {$nRuns > 1} {
							set runName "run[format "%03d" $run]"

							if { $runBasename != "" } {
								append runBasename "_run[format "%03d" $run]"
							}
						}

						if { [catch {
							setOutputParameters $file_format $data_type $output_folder $runBasename $runName
							CTSimU::startScan
							$batchList cellconfigure $index,Status -text "Stopped"
							incr nJobsDone
						} err] } {
							$batchList cellconfigure $index,Status -text "ERROR"
							incr nJobsDone
							break
						}

						if {[$ctsimu_scenario batch_is_running] == 0} {
							return
						}

						$batchList cellconfigure $index,Status -text "Done"

						CTSimU::setStartProjNr 0
					}

					stopBatch

					# Run Batch again, just in case the user added new jobs or resubmitted some.
					# Also, this 'foreach' loop only runs until the first 'pending' entry, then
					# calls the runBatch function again and quits, in case the user changed
					# any directory names, output basenames, etc.
					if {$nJobsDone > 0} {
						runBatch
					}

					return
					
				} else {
					$batchList cellconfigure $index,Status -text "Done"
				}
			}
		}

		stopBatch
	}
}

# ----------------------------------------------
#  Scenario loading and handling
# ----------------------------------------------

proc showProjection {} {
	variable GUISettings
	variable ctsimu_scenario

	applyCurrentParameters
	#setupProjection [$ctsimu_scenario getCurrentProjNr] 1
}

proc nextProjection {} {
	variable GUISettings

	applyCurrentParameters
	
	set projNr $GUISettings(projNr)
	incr projNr
	set GUISettings(projNr) $projNr

	showProjection
}

proc prevProjection {} {
	variable GUISettings

	applyCurrentParameters
	
	set projNr $GUISettings(projNr)
	incr projNr -1
	set GUISettings(projNr) $projNr

	showProjection
}

proc startScan {} {
	# User starts scan with button

	variable GUISettings
	variable container
	variable ctsimu_scenario

	applyCurrentParameters
	
	$ctsimu_scenario set output_folder $GUISettings(outputFolder) ""
	$ctsimu_scenario set output_basename $GUISettings(outputBaseName)
}

proc CTSimU_stopScan {} {
	variable GUISettings
	stopScan
}