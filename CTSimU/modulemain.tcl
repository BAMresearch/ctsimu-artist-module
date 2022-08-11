# main file for startup within aRTist

# remember namespace
variable ns [namespace current]
variable BasePath [file dirname [info script]]

proc Info {} {
	return [dict create \
		Name        CTSimU \
		Description "CTSimU Scenario Loader" \
		Version     "1.0" \
	]
}

# requires the rl_json package which ships with aRTist since version 2.10.2
package require rl_json
package require csv
package require fileutil

source [file join $BasePath ctsimu_scenario.tcl]
variable ctsimu_scenario;  # currently loaded CTSimU scenario
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
	variable Project ""
	variable GUISettings
	variable CacheFiles [dict create]

	Utils::nohup { Settings [Preferences::GetWithDefault CTSimU Settings {}] }

	set prefs [Preferences::GetWithDefault CTSimU Settings {}]

	if {[dict exists $prefs fileFormat]} {
		$ctsimu_scenario setFileFormat [dict get $prefs fileFormat]
	}

	if {[dict exists $prefs dataType]} {
		$ctsimu_scenario setDataType [dict get $prefs dataType]
	}

	if {[dict exists $prefs cfgFileCERA]} {
		$ctsimu_scenario setCreateCERAconfigFile [dict get $prefs cfgFileCERA]
	}

	if {[dict exists $prefs cfgFileCLFDK]} {
		$ctsimu_scenario setCreateCLFDKconfigFile [dict get $prefs cfgFileCLFDK]
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
	if {[$ctsimu_scenario batchIsRunning] == 1} {
		return false
	}

	if {[$ctsimu_scenario isRunning] == 1} {
		return false
	}

	return true
}

# construct an input form for a given property list
# containing Name, section option, type,payload
# of the property

# set variable var to default, if it doesn't exists yet
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
		{Start Angle}        startAngle     integer   {° deg}
		{Stop Angle}         stopAngle      integer   {° deg}
		{Projections}        nProjections   integer   {}
		{Display Projection #}  projNr      integer   {}
		{Final projection is taken at stop angle}  includeFinalAngle  bool   { }
		{ } projBtns       buttons { "Show" CTSimU_showProjection 7 "<" CTSimU_prevProjection 3 ">" CTSimU_nextProjection 3 }
	}

	set CTScan  [FoldFrame $model.frmCTScan -text "Simulation"     -padding $pad]
	dataform $CTScan {
		{Output Folder}          outputFolder    folder   {}
		{Projection Base Name}   outputBaseName  string   {}
		{Start at Projection Nr.}        startProjNr     integer  {}
		{File Format}            fileFormat      choice   { "TIFF" "tiff" "RAW" "raw" }
		{Data Type}              dataType        choice   { "uint16" "16bit" "float32" "32bit" }
		{Save ideal dark field}  takeDarkField   bool     {}
		{Flat field images}      nFlatFrames     integer  {}
		{Flat frames to average} nFlatAvg        integer  {}
		{Flat field mode}        ffIdeal         choice   { "Regular" 0 "Ideal" 1 }
		{ }                      scanBtn         buttons  { "Run scenario" CTSimU_startScan 12 "Stop" CTSimU_stopScan 7 }
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
		{Create CERA config file}  cfgFileCERA  bool   { }
		{Create VG Studio/clFDK config file}  cfgFileCLFDK  bool   { }
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
	CTSimU_showProjection
}

# ----------------------------------------------
#  Connectors between frontend and backend
# ----------------------------------------------


proc fail { message } {
	# Main error function
	showInfo "Error: $message"
	aRTist::Error { $message }
	error $message
}

proc loadedSuccessfully { } {
	variable ctsimu_scenario

	if [$ctsimu_scenario jsonLoadedSuccessfully] {
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

	set GUISettings(jsonfile)          [$ctsimu_scenario jsonfile]
	set GUISettings(startAngle)        [$ctsimu_scenario startAngle]
	set GUISettings(stopAngle)         [$ctsimu_scenario stopAngle]
	set GUISettings(nProjections)      [$ctsimu_scenario nProjections]
	set GUISettings(projNr)            [$ctsimu_scenario projNr]
	set GUISettings(outputBaseName)    [$ctsimu_scenario basename]
	set GUISettings(outputFolder)      [$ctsimu_scenario outputFolder]
	set GUISettings(fileFormat)        [$ctsimu_scenario fileFormat]
	set GUISettings(dataType)          [$ctsimu_scenario dataType]
	set GUISettings(includeFinalAngle) [$ctsimu_scenario includeFinalAngle]
	set GUISettings(startProjNr)       [$ctsimu_scenario startProjNr]

	set GUISettings(takeDarkField)     [$ctsimu_scenario takeDarkField]
	set GUISettings(nFlatFrames)       [$ctsimu_scenario nFlats]
	set GUISettings(nFlatAvg)          [$ctsimu_scenario nFlatAvg]
	set GUISettings(ffIdeal)           [$ctsimu_scenario ffIdeal]

	# Recon settings
	set GUISettings(cfgFileCERA)       [$ctsimu_scenario createCERAconfigFile]
	set GUISettings(cfgFileCLFDK)      [$ctsimu_scenario createCLFDKconfigFile]
}

proc applyCurrentSettings {} {
	# Store the parameters that are defined by the user in the settings pane,
	# both in $ctsimu_scenario and in the module's preferences.
	variable GUISettings
	variable ctsimu_scenario
	$ctsimu_scenario setCreateCERAconfigFile  $GUISettings(cfgFileCERA)
	$ctsimu_scenario setCreateCLFDKconfigFile $GUISettings(cfgFileCLFDK)

	dict set storeSettings fileFormat   [$ctsimu_scenario fileFormat]
	dict set storeSettings dataType     [$ctsimu_scenario dataType]
	dict set storeSettings cfgFileCERA  [$ctsimu_scenario createCERAconfigFile]
	dict set storeSettings cfgFileCLFDK [$ctsimu_scenario createCLFDKconfigFile]

	Preferences::Set CTSimU Settings $storeSettings
}

proc applyCurrentParameters {} {
	# Take parameters from GUI and store them in $ctsimu_scenario.
	variable GUISettings
	variable ctsimu_scenario
	variable ctsimu_scenario

	$ctsimu_scenario setJsonfile          $GUISettings(jsonfile)
	$ctsimu_scenario setStartAngle        $GUISettings(startAngle)
	$ctsimu_scenario setStopAngle         $GUISettings(stopAngle)
	$ctsimu_scenario setNprojections      $GUISettings(nProjections)
	$ctsimu_scenario setProjNr            $GUISettings(projNr)
	$ctsimu_scenario setIncludeFinalAngle $GUISettings(includeFinalAngle)
	$ctsimu_scenario setStartProjNr       $GUISettings(startProjNr)

	$ctsimu_scenario setTakeDarkField     $GUISettings(takeDarkField)
	$ctsimu_scenario setFlats             $GUISettings(nFlatFrames)
	$ctsimu_scenario setFlatAvg           $GUISettings(nFlatAvg)
	$ctsimu_scenario setFFideal           $GUISettings(ffIdeal)
	
	$ctsimu_scenario setFileFormat        $GUISettings(fileFormat)
	$ctsimu_scenario setDataType          $GUISettings(dataType)

	applyCurrentSettings
}

proc setOutputParameters { fileFormat dataType outputFolder projectionBasename run } {
	variable ctsimu_scenario
	# fileFormat: "raw" or "tiff". Standard: "raw".
	# dataType: "16bit" or "32bit". Standard: "16bit"

	if { [string match -nocase "tiff" $fileFormat] } {
		$ctsimu_scenario setFileFormat "tiff"
	} else {
		$ctsimu_scenario setFileFormat "raw"
	}

	if { [string match -nocase "32bit" $dataType] } {
		$ctsimu_scenario setDataType "32bit"
	} else {
		$ctsimu_scenario setDataType "16bit"
	}

	if { [string length $outputFolder] > 0 } {
		$ctsimu_scenario setOutputFolder $outputFolder $run
	}

	if { [string length $projectionBasename] > 0 } {
		$ctsimu_scenario setBasename $projectionBasename
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
				set outputFolder       [$batchList cellcget $index,OutputFolder  -text]
				set projectionBasename [$batchList cellcget $index,ProjectionBaseName  -text]
				set nRuns              [$batchList cellcget $index,Runs  -text]
				set startRun           [$batchList cellcget $index,StartRun  -text]
				set startProjNr        [$batchList cellcget $index,StartProjNr  -text]
				set status             [$batchList cellcget $index,Status  -text]

				set csvLine [::csv::join [list $jsonFilename $outputFormat $outputFolder $projectionBasename $nRuns $startRun $startProjNr $status ]]

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
	$ctsimu_scenario setBatchIsRunning 0
	CTSimU_stopScan
}

proc runBatch { } {
	variable ctsimu_scenario

	if {[$ctsimu_scenario batchIsRunning] == 0} {
		$ctsimu_scenario setBatchIsRunning 1
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
					set fileFormat "raw"
					set dataType "16bit"

					if { $outputFormat == "RAW float32" } {
						set dataType "32bit"
					} elseif { $outputFormat == "TIFF float32" } {
						set dataType "32bit"
						set fileFormat "tiff"
					} elseif { $outputFormat == "TIFF uint16" } {
						set fileFormat "tiff"
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
						if {[$ctsimu_scenario batchIsRunning] == 0} {
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
							setOutputParameters $fileFormat $dataType $outputFolder $runBasename $runName
							CTSimU::startScan
							$batchList cellconfigure $index,Status -text "Stopped"
							incr nJobsDone
						} err] } {
							$batchList cellconfigure $index,Status -text "ERROR"
							incr nJobsDone
							break
						}

						if {[$ctsimu_scenario batchIsRunning] == 0} {
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
#  Helper functions
# ----------------------------------------------

proc getOutputFolderFromJSONfilename { jsonfilename } {
	set jsonfiledir [file dirname "$jsonfilename"]
	return "$jsonfiledir"
}

proc getOutputBasenameFromJSONfilename { jsonfilename } {
	set baseName [file root [file tail $jsonfilename]]
	return $baseName
}


# ----------------------------------------------
#  Scenario loading and handling
# ----------------------------------------------

proc loadFullScenario { jsonFile } {
	variable ctsimu_scenario

	$ctsimu_scenario reset
	$ctsimu_scenario setJsonfile $jsonFile

	fillCurrentParameters
	loadCTSimUScene
}

proc runScenario { jsonFile fileFormat dataType outputFolder projectionBasename } {
	# Run a full CT scan simulation using the provided JSON file.
	# fileFormat: "raw" or "tiff". Standard: "raw".
	# dataType: "16bit" or "32bit". Standard: "16bit"
	# Give empty strings for outputFolder and projectionBasename to auto-generate them.

	loadFullScenario $jsonFile
	applyCurrentParameters
	setOutputParameters $fileFormat $dataType $outputFolder $projectionBasename	""
	CTSimU_startScan
}

proc loadCTSimUScene {} {
	variable GUISettings

	applyCurrentParameters
	aRTist::LoadEmptyProject

	set sceneState [parseJSONscene $GUISettings(jsonfile) ]

	# Continue only if JSON was loaded successfully:
	if { $sceneState == 1 } {
		fillCurrentParameters
		showInfo "Scenario loaded."
		CTSimU_showProjection
		Engine::RenderPreview
		::SceneView::ViewAllCmd
	}
}

proc CTSimU_showProjection {} {
	variable GUISettings
	variable ctsimu_scenario

	applyCurrentParameters
	setupProjection [$ctsimu_scenario getCurrentProjNr] 1
}

proc CTSimU_nextProjection {} {
	variable GUISettings

	applyCurrentParameters
	
	set projNr $GUISettings(projNr)
	incr projNr
	set GUISettings(projNr) $projNr

	CTSimU_showProjection
}

proc CTSimU_prevProjection {} {
	variable GUISettings

	applyCurrentParameters
	
	set projNr $GUISettings(projNr)
	incr projNr -1
	set GUISettings(projNr) $projNr

	CTSimU_showProjection
}

proc CTSimU_startScan {} {
	# User starts scan with button

	variable GUISettings
	variable container
	variable ctsimu_scenario

	applyCurrentParameters
	
	$ctsimu_scenario setOutputFolder $GUISettings(outputFolder) ""
	$ctsimu_scenario setBasename $GUISettings(outputBaseName)
	startScan
}

proc CTSimU_stopScan {} {
	variable GUISettings
	stopScan
}



namespace import ::rl_json::*


proc setProjectionShortPath { run } {
	variable ctsimuSettings
	if { [string length $run] > 0 } {
		dict set ctsimuSettings projectionShortPath "projections/$run"
	} else {
		dict set ctsimuSettings projectionShortPath "projections"
	}
}

proc setFFProjectionShortPath { run } {
	variable ctsimuSettings
	if { [string length $run] > 0 } {
		dict set ctsimuSettings ffProjectionShortPath "projections/$run/corrected"
	} else {
		dict set ctsimuSettings ffProjectionShortPath "projections/corrected"
	}
}

proc setReconShortPath { run } {
	variable ctsimuSettings
	if { [string length $run] > 0 } {
		dict set ctsimuSettings reconShortPath "reconstruction/$run"
	} else {
		dict set ctsimuSettings reconShortPath "reconstruction"
	}
}

proc setProjectionFolder { folder run } {
	variable ctsimuSettings
	setProjectionShortPath $run

	set shortPath [dict get $ctsimuSettings projectionShortPath]
	dict set ctsimuSettings projectionFolder "$folder/$shortPath"
}

proc setFFProjectionFolder { folder run } {
	variable ctsimuSettings
	setFFProjectionShortPath $run

	set shortPath [dict get $ctsimuSettings ffProjectionShortPath]
	dict set ctsimuSettings ffProjectionFolder "$folder/$shortPath"
}

proc setReconFolder { folder run } {
	variable ctsimuSettings
	setReconShortPath $run

	set shortPath [dict get $ctsimuSettings reconShortPath]
	dict set ctsimuSettings reconFolder "$folder/$shortPath"
}

proc setOutputFolder { folder run } {
	variable ctsimuSettings
	dict set ctsimuSettings outputFolder $folder

	setProjectionFolder $folder $run
	setReconFolder $folder $run
	setFFProjectionFolder $folder $run
}

proc setOutputBaseName { basename } {
	variable ctsimuSettings
	dict set ctsimuSettings outputBaseName $basename
}

proc setIncludeFinalAngle { includeFinalAngle } {
	variable ctsimuSettings
	aRTist::Info { "Include final angle: $includeFinalAngle." }
	dict set ctsimuSettings includeFinalAngle $includeFinalAngle
}

proc getIncludeFinalAngle { } {
	variable ctsimuSettings
	return [dict get $ctsimuSettings includeFinalAngle]
}

proc setTakeDarkField { takeDF } {
	variable ctsimuSettings
	dict set ctsimuSettings takeDarkField $takeDF
}

proc getTakeDarkField { } {
	variable ctsimuSettings
	return [dict get $ctsimuSettings takeDarkField]
}

proc setNFlatFrames { nFlatFrames } {
	variable ctsimuSettings
	dict set ctsimuSettings nFlatFrames $nFlatFrames
}

proc getNFlatFrames { } {
	variable ctsimuSettings
	return [dict get $ctsimuSettings nFlatFrames]
}

proc setNFlatAvg { nFlatAvg } {
	variable ctsimuSettings
	dict set ctsimuSettings nFlatAvg $nFlatAvg
}

proc getNFlatAvg { } {
	variable ctsimuSettings
	return [dict get $ctsimuSettings nFlatAvg]
}

proc setFFIdeal { ffIdeal } {
	variable ctsimuSettings
	dict set ctsimuSettings ffIdeal $ffIdeal
}

proc getFFIdeal { } {
	variable ctsimuSettings
	return [dict get $ctsimuSettings ffIdeal]
}

proc setScanDirection { scanDirection } {
	variable ctsimuSettings
	dict set ctsimuSettings scanDirection $scanDirection
}

proc setStartProjNr { startProjNr } {
	variable ctsimuSettings
	dict set ctsimuSettings startProjNr $startProjNr
}

proc getStartProjNr { } {
	variable ctsimuSettings
	return [dict get $ctsimuSettings startProjNr]
}

proc aRTist_placeObjectInCoordinateSystem { object coordinateSystem } {
	# Reset object to initial position:
	::PartList::Invoke $object SetPosition    0 0 0
	::PartList::Invoke $object SetRefPos      0 0 0
	::PartList::Invoke $object SetOrientation 0 0 0

	# Position
	set posX [cs_cx $coordinateSystem]
	set posY [cs_cy $coordinateSystem]
	set posZ [cs_cz $coordinateSystem]
	aRTist::Debug { "   Centre for $object: $posX $posY $posZ" }

	::PartList::Invoke $object SetPosition $posX $posY $posZ
	::PartList::Invoke $object SetRefPos   $posX $posY $posZ

	# Orientation
	set ux [cs_ux $coordinateSystem]
	set uy [cs_uy $coordinateSystem]
	set uz [cs_uz $coordinateSystem]
	set wx [cs_wx $coordinateSystem]
	set wy [cs_wy $coordinateSystem]
	set wz [cs_wz $coordinateSystem]
	aRTist::Debug { "   Vector u for $object: $ux $uy $uz" }
	aRTist::Debug { "   Vector w for $object: $wx $wy $wz" }

	set ex [list 1 0 0]
	set ey [list 0 1 0]
	set ez [list 0 0 1]

	# aRTist's detector and source coordinate systems do not match CTSimU specification:
	# aRTist's y vector points downwards in a projection; CTSimU's points upwards.
	# -> reverse w vector to solve this.
	if { $object == "D" || $object == "S"} {
		aRTist::Debug { "Treating detector or source." }
		set wx [expr -$wx]
		set wy [expr -$wy]
		set wz [expr -$wz]
	}

	set u [list $ux $uy $uz]
	set w [list $wx $wy $wz]

	set local_x [list 1 0 0]

	# Rotate object z axis towards w vector
	if { !( ($wx==0 && $wy==0 && $wz==1) ) } {
		# Rotation axis from cross product (0, 0, 1)x(wx, wy, wz)
		set rotAxis [vec3Cross $ez $w]

		if { [vec3Norm $rotAxis]==0 } {
			if { [vec3Dot $w $ez] < 0} {
				# Vectors point in opposite directions. Rotation axis is another stage CS basis vector.
				aRTist::Debug { "   z axis of object and w axis of target coordinate system point in opposite directions. Using u axis as rotation axis."}
				set rotAxis $u
			} else {
				aRTist::Debug { "   w axis of object $object already points in direction z." }
			}	
		}

		if { [vec3Norm $rotAxis]!=0 } {
			set rotAxis_x [lindex $rotAxis 0]
			set rotAxis_y [lindex $rotAxis 1]
			set rotAxis_z [lindex $rotAxis 2]

			# Rotation angle from scalar product (0, 0, 1)*(wx, wy, wz)
			set rotAngle [vec3Angle $ez $w]
			set degAngle [::Math::RadToDeg $rotAngle]
			aRTist::Debug { "   Rotation V for object $object around $rotAxis_x, $rotAxis_y, $rotAxis_z by angle $degAngle °." }

			# Perform rotation
			::PartList::Invoke $object Rotate world $degAngle $rotAxis_x $rotAxis_y $rotAxis_z

			set local_x [rotateVector $local_x $rotAxis $rotAngle]
		}
	}

	# Rotate object x axis towards u vector (around now fixed w axis of the object)
	set localx_x [lindex $local_x 0]
	set localx_y [lindex $local_x 1]
	set localx_z [lindex $local_x 2]

	aRTist::Debug { "   local x axis is now: $localx_x $localx_y $localx_z" }
	set rotAxisToU [vec3Cross $local_x $u]

	if { [vec3Norm $rotAxisToU]==0 } {
		if { [vec3Dot $u $local_x] < 0} {
			# Vectors point in opposite directions. Rotation axis is stage w.
			aRTist::Debug { "   x\' axis of object and u axis of target coordinate system point in opposite directions. Using w axis as rotation axis."}
			set rotAxisToU $w
		} else {
			aRTist::Debug { "   u axis of object $object already points in direction u." }
		}	
	}

	if { [vec3Norm $rotAxisToU]!=0 } {
		set rotAngle [vec3Angle $local_x $u]

		set rotAxis_x [lindex $rotAxisToU 0]
		set rotAxis_y [lindex $rotAxisToU 1]
		set rotAxis_z [lindex $rotAxisToU 2]

		aRTist::Debug { "   Rotation U for object $object around 0, 0, 1 (of object) by angle $rotAngle °." }

		# Perform rotation
		::PartList::Invoke $object Rotate world [::Math::RadToDeg $rotAngle] $rotAxis_x $rotAxis_y $rotAxis_z
	} else {
		aRTist::Debug { "   u axis of object $object already points in direction u." }
	}
}

proc getMaterialID { materialID } {
	if {$materialID == "null"} {
		return "void"
	}

	set internalName "CTSimU_"
	append internalName $materialID

	variable ctsimuSceneMaterials
	if {[lsearch -exact $ctsimuSceneMaterials $materialID] >= 0} {
		# Check density and return "void" if density is not >0:
		if [dict exists $::Materials::MatList $internalName] {
			set density [dict get $::Materials::MatList $internalName density]
			puts "Material $internalName has density $density"
			if {$density <= 0} {
				return "void"
			}
		} else {
			puts "Material $internalName does not exists yet."
		}

		return $internalName
	} else {
		fail "Material not specified in JSON file: $materialID"
	}
}

proc addMaterial { name density composition comment } {
	set values [dict create]
	dict set values density $density
	dict set values composition $composition
	dict set values comment $comment

	# Add a keyword to the material name to
	# avoid overwriting existing materials:
	set mID "CTSimU_"
	append mID $name

	dict set ::Materials::MatList $mID $values

	# Add to currently imported list of materials:
	variable ctsimuSceneMaterials
	lappend ctsimuSceneMaterials $name
}

# From detectorCalc module:
# parse spectrum with n columns into flat list
# ignore superfluous columns, comments & blank lines
proc ParseSpectrum { spectrumtext n } {

	set NR 0
	set result {}
	foreach line [split $spectrumtext \n] {

		incr NR
		if { [regexp {^\s*#(.*)$} $line full cmt] } {
			aRTist::Debug { $line }
			continue
		}

		aRTist::Trace { $line }

		# playing AWK
		set lline [regexp -inline -all -- {\S+} $line]
		set NF [llength $lline]
		if { $NF == 0 } { continue }

		for { set i 1 } { $i <= $NF } { incr i } { set $i [lindex $lline [expr {$i-1}]] }
		# now we have $1, $2, ...

		if { $NF < $n } { error "Corrupt data: Expected at least $n columns, parsing line $NR\n$NR: $line" }

		set clist {}
		for { set i 1 } { $i <= $n } { incr i } {
			set val [set $i]
			if { ![string is double -strict $val] } { error "Corrupt data: Expected number on line $NR:$i\n$NR: $line" }
			lappend clist $val
		}
		lappend result {*}$clist

	}

	return $result
}

# Adaption of DetectorCalc's Compute function:
proc generateDetector { name detectorType pixelSizeX pixelSizeY pixelCountX pixelCountY scintillatorMaterialID scintillatorThickness minEnergy maxEnergy current integrationTime nFrames filterList sourceDetectorDistance SRb SNR FWHM maxGVfromDetector GVatMin GVatMax factor offset } {
	variable ctsimuSettings

	# set user input to general variables
	dict set detector Global Name $name
	dict set detector Global UnitIn {J/m^2}
	dict set detector Global UnitOut {grey values}
	dict set detector Global Pixelsize $pixelSizeX
	set pcount [string trim "$pixelCountX $pixelCountY"]
	if { $pcount != "" } { dict set detector Global PixelCount $pcount }

	if { $SRb == "null" } { set SRb 0 }

	dict set detector Unsharpness Resolution [expr {sqrt(2.0) * $SRb}]
	dict set detector Unsharpness LRUnsharpness 0
	dict set detector Unsharpness LRRatio 0

	# load spectrum
	set spectrumtext [join [XSource::GetFullSpectrum] \n]
	aRTist::Info { "Currently loaded spectrum was used." }

	# Apply environment material "filter" to input spectrum:
	if { ![string match -nocase VOID $::Xsetup(SpaceMaterial)] } {
		aRTist::Verbose { "Filtering input spectrum by environment material $::Xsetup(SpaceMaterial), SDD: $sourceDetectorDistance" }
		Engine::UpdateMaterials $::Xsetup(SpaceMaterial)
		set spectrumtext [xrEngine FilterSpectrum $spectrumtext $::Xsetup(SpaceMaterial) [Engine::quotelist --Thickness [expr {$sourceDetectorDistance / 10.0}]]]
	}

	#aRTist::Verbose { "Spectrum:\n$spectrumtext" }
	set spectrum [ParseSpectrum $spectrumtext 2]
	#aRTist::Debug { "Parsed: $spectrum\n" }

	set sensitivitytext ""

	if {$detectorType == "real"} {
		# Scintillator:
		set density     [Materials::get $scintillatorMaterialID density]
		set composition [Materials::get $scintillatorMaterialID composition]
		set scintillatorSteps  2
		set keys        [list $composition $density $scintillatorThickness $scintillatorSteps $minEnergy $maxEnergy]

		aRTist::Info { "Computing sensitivity..." }

		set start [clock microseconds]
		set sensitivitytext {}
		set first 1
		set Emin 0

		Engine::UpdateMaterials $scintillatorMaterialID

		set i 0
		set steps 9

		foreach { dE Emax EBin } {
			  0.1    50 0.01
			  0.5   100 0.05
			  1     200 0.1
			  5     500 0.2
			 20     600 0.5
			 50    1000 1
			100   10000 2
			200   12000 5
			500   20000 10
		} {
			set percentage [expr round(100*$i/$steps)]
			showInfo "Calculating detector sensitivity: $percentage% ($Emin .. $Emax keV)"
			incr i

			aRTist::Verbose { "$Emin\t$dE\t$Emax\t$EBin" }
			set grid [seq [expr {$Emin + $dE}] $dE [expr {$Emax + $dE / 10.}]]
			set Emin [lindex $grid end]

			# compute sensitivity
			set options [Engine::quotelist \
				--Thickness [expr {$scintillatorThickness / 10.0}] \
				--Steps $scintillatorSteps \
				--EBin $EBin \
				--Min-Energy $minEnergy \
				--Max-Energy $maxEnergy \
			]
			if {($scintillatorThickness > 0) && ($scintillatorMaterialID != "void")} {
				set data [xrEngine GenerateDetectorSensitivity $scintillatorMaterialID $options [join $grid \n]]
			} else {
				fail "A scintillator material of non-zero thickness must be defined for a \'real\' detector."
			}

			foreach line [split $data \n] {

				if { [regexp {^\s*$} $line] } { continue }
				if { [regexp {^\s*#(.*)$} $line full cmt] } {
					if { !$first } { continue }
					if { [regexp {^\s*Time:} $cmt] } { continue }
					if { [regexp {^\s*Norm:} $cmt] } { continue }
					if { [regexp {^\s*Area:} $cmt] } { continue }
					if { [regexp {^\s*Distance:} $cmt] } { continue }
				}

				lappend sensitivitytext $line

			}

			set first 0
		}
		aRTist::Info { [format "Computed sensitivity in %.3fs" [expr {([clock microseconds] - $start) / 1e6}]] }

		showInfo "Calculating detector characteristics..."

		set sensitivitytext [join $sensitivitytext \n]

		if { [catch {

			set CacheFile [TempFile::mktmp .det]

			set fd [open $CacheFile w]
			fconfigure $fd -encoding utf-8 -translation auto
			puts $fd $sensitivitytext
			close $fd

			dict set CacheFiles {*}$keys $CacheFile

		} err] } {
			Utils::nohup { close $fd }
			aRTist::Info { $err }
		}
	} elseif { $detectorType == "ideal" } {
		# For an ideal detector, set the same "sensitivity" for all energies.
		# Filters will be applied in the next step.

		for { set kV 0 } { $kV <= 1000 } { incr kV} {
			append sensitivitytext "$kV 1 $kV\n"
		}
	}

	# Apply detector filters
	foreach {materialID thickness} $filterList {
		aRTist::Verbose { "Filtering by $materialID, Thickness: $thickness" }
		Engine::UpdateMaterials $materialID
		set sensitivitytext [xrEngine FilterSpectrum $sensitivitytext $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]]
	}

	#aRTist::Verbose { "Sensitivity:\n$sensitivitytext" }
	set sensitivity [ParseSpectrum $sensitivitytext 3]
	#aRTist::Debug { "Parsed: $sensitivity\n" }

	# interpolate sensitivity to spectrum
	set P_interact {}
	set E_interact {}
	foreach { energy pi ei } $sensitivity {
		aRTist::Trace { "$energy: $pi $ei" }
		append P_interact "$energy $pi\n"
		append E_interact "$energy $ei\n"
	}
	aRTist::Trace { "Prob:\n$P_interact" }
	aRTist::Trace { "E:\n$E_interact" }
	aRTist::Verbose { "Rebinning sensitivity data..." }
	set P_interact [ParseSpectrum [xrEngine Rebin $P_interact $spectrumtext] 2]
	set E_interact [ParseSpectrum [xrEngine Rebin $E_interact $spectrumtext] 2]
	aRTist::Trace { "Prob: $P_interact\n" }
	aRTist::Trace { "E: $E_interact\n" }

	set keV 1.6021765e-16; # J
	# compute photon count, mean energy, quadratic mean energy
	set Esum 0.0
	set Esqusum 0.0
	set Nsum 0.0
	foreach { esp ni } $spectrum { eprob probability } $P_interact { eenerg e_inter } $E_interact {
		aRTist::Debug { "$esp $ni, $eprob $probability, $eenerg $e_inter" }
		if { $esp != $eprob || $esp != $eenerg } {
			aRTist::Warning { "Grids differ: $esp $eprob $eenerg" }
			if { $esp == "" } {
				aRTist::Warning { "Spectrum shorter than sensitivity" }
				break
			}
		}
		set signal   [expr { $keV * $e_inter }]
		set Nphotons [expr { $ni * $probability }]
		set Nsum     [expr { $Nsum    + $Nphotons }]
		set Esum     [expr { $Esum    + $Nphotons * $signal }]
		set Esqusum  [expr { $Esqusum + $Nphotons * $signal**2 }]

		showInfo "Calculating signal statistics for $keV keV..."
	}
	showInfo "Calculating detector characteristics..."

	if { $Nsum > 0 } {
		set Emean    [expr {$Esum    / $Nsum}]
		set Esqumean [expr {$Esqusum / $Nsum}]

		# the swank factor determines the reduction of SNR by the polychromatic spectrum
		# for mono spectrum, swank==1
		# for poly spectrum, SNR = swank * sqrt(N), N=total photon count
		set swank [expr {$Emean / sqrt($Esqumean)}]

		# compute effective pixel area in units of m^2
		if { $SRb <= 0.0 } {
			set pixelarea [expr { $pixelSizeX * $pixelSizeY * 1e-6 }]
		} else {
			# estimate effective area from gaussian unsharpness
			package require math::special
			set FractionX [math::special::erf [expr { $pixelSizeX / $SRb / sqrt(2) }]]
			set FractionY [math::special::erf [expr { $pixelSizeY / $SRb / sqrt(2) }]]
			set pixelarea [expr { ($pixelSizeX / $FractionX) * ($pixelSizeY / $FractionY) * 1e-6 }]
		}

		# compute total photon count onto the effective area
		set expfak [expr {$current * $integrationTime * $nFrames * $pixelarea / double($sourceDetectorDistance / 1000.0)**2}]
		set Ntotal [expr {$Nsum * $expfak}]
		set Etotal [expr {$Esum * $expfak}]

		if { ($Ntotal > 0) && ($Etotal > 0)} {
			aRTist::Verbose { "Swank factor $swank, Photon count $Ntotal, Energy $Etotal J" }

			set energyPerPixel [expr double($Etotal) / double($pixelarea) / double($nFrames)]
			# should we handle photon counting differently?
			set amplification  [expr {$maxGVfromDetector / $energyPerPixel }]
			set maxinput $energyPerPixel

			# Flat field correction rescale factor
			dict set ctsimuSettings ffRescaleFactor 60000

			# If linear interpolation is used instead of GVmin and GVmax:
			set GVatMaxInput 0
			set GVatNoInput 0
			if { ($factor != "null") && ($offset != "null")} {
				aRTist::Info { "Factor: $factor, Offset: $offset, maxInput: $maxinput" }

				# The factor must be converted to describe
				# an energy density characteristics in aRTist:
				set factor [expr $factor * $pixelarea]

				if { $factor != 0 } {
					set GVatMaxInput [expr $factor * $maxinput + $offset]
					set GVatNoInput [expr $offset]

					# generate linear amplification curve
					dict set detector Characteristic 0.0 $GVatNoInput
					dict set detector Characteristic $maxinput $GVatMaxInput
					dict set detector Exposure TargetValue $GVatMaxInput
				}

				dict set ctsimuSettings GVmax $GVatMaxInput

				# Set the FF correction rescale factor to GVatMaxInput - offset
				dict set ctsimuSettings ffRescaleFactor [expr $GVatMaxInput-$GVatNoInput]

			} elseif { $GVatMax != "null" && $GVatMin != "null" } {
				set amplification  [expr {double($GVatMax) / double($energyPerPixel) }]
				set maxinput $energyPerPixel

				set GVatMaxInput $GVatMax
				set GVatNoInput $GVatMin

				# generate linear amplification curve
				dict set detector Characteristic 0.0 $GVatMin
				dict set detector Characteristic $maxinput $GVatMax

				aRTist::Info { "GV at Min: $GVatMin, GV at Max: $GVatMax, maxInput: $maxinput" }

				dict set detector Exposure TargetValue $GVatMax
				dict set ctsimuSettings GVmax $GVatMax

				# Set the FF correction rescale factor to GVatMax - GVatMin
				dict set ctsimuSettings ffRescaleFactor [expr $GVatMax-$GVatMin]
			}

			if { ($SNR==0) || ($SNR=="0") || ($SNR=="0.0") || ($SNR=="null") } {
				if { !(($FWHM==0) || ($FWHM=="0") || ($FWHM=="0.0") || ($FWHM=="null")) } {
					set SNR [convertSNR_FWHM $FWHM $GVatMaxInput]
					aRTist::Info { "Converted FWHM $FWHM to SNR $SNR" }
				}
			}

			if {$SNR != "null"} {
				# compute maximum theoretical SNR
				set SNR_ideal   [expr {sqrt($Ntotal)}]
				set SNR_quantum [expr {$SNR_ideal * $swank}]
				aRTist::Info { "SNR_quantum $SNR_quantum" }

				if { $SNR > $SNR_quantum } {
					aRTist::Warning { "SNR measured better than quantum noise (SNR_quantum=$SNR_quantum), ignoring theoretical swank factor (SNR_quantum=$SNR_ideal)" }
					set SNR_quantum $SNR_ideal
				}

				if { $SNR > $SNR_quantum } {
					aRTist::Warning { "SNR measured better than quantum noise (SNR_quantum=$SNR_quantum), using measured value (SNR_quantum=$SNR)" }
					set SNR_quantum $SNR
				}

				# structure noise model: NSR^2_total = NSR^2_quantum + NSR^2_structure, NSR^2_structure=const
				set NSR2_quantum   [expr {1.0 / $SNR_quantum**2}]
				set NSR2_total     [expr {1.0 / $SNR**2}]
				set NSR2_structure [expr {$NSR2_total - $NSR2_quantum}]
			}

			dict set detector Quantization ValueMin 0
			dict set detector Quantization ValueMax $maxGVfromDetector
			dict set detector Quantization ValueQuantum 1.0

			dict set detector Sensitivity $sensitivitytext

			# generate SNR curve, 500 log distributed steps
			if {$SNR != "null"} {
				set nsteps   500
				set mininput [expr {1.0 / $amplification}]
				set refinput [expr {($GVatMaxInput) / $amplification * $nFrames}]
				set maxFrames [max 100.0 $nFrames]
				set factor   [expr {(max(100.0, $maxFrames) * $maxinput / $mininput)**(1.0 / $nsteps)}]
				for { set step 0 } { $step <= $nsteps } { incr step } {
					set percentage [expr round(100*$step/$nsteps)]
					showInfo "Calculating SNR characteristics: $percentage%"

					set intensity    [expr {$mininput * $factor**$step}]
					set NSR2         [expr {$NSR2_structure + $NSR2_quantum * $refinput / $intensity}]
					set SNR          [expr {sqrt(1.0 / $NSR2)}]
					dict set detector Noise $intensity $SNR
					aRTist::Debug { "Noise: $intensity [expr {$intensity * $amplification}] $SNR" }
				}
			}

			showInfo "Detector characteristics done."

			return $detector
		} else {
			fail "Detector does not detect any photons. Please check your detector properties (sensitivity, etc.) and your source properties (spectrum, current, etc.) for mistakes."
		}
	} else {
		fail "Detector does not detect any photons. Please check your detector properties (sensitivity, etc.) and your source properties (spectrum, current, etc.) for mistakes."
	}
}

# Adaption from stuff/xsource.tcl. Assumes that XSource() properties are already set.
proc ComputeSpectrum { windows filters } {

	global Xsource Xsource_private
	variable ComputedSpectra

	if { $Xsource(Tube) == "Mono" } {

		# generate monochromatic spectrum
		# 1 GBq at Voltage
		set description "Monochromatic $Xsource(Voltage) keV, 1 / (GBq * sr)"
		lappend spectrum "# $description"
		lappend spectrum "# Name: $Xsource(Tube)"
		lappend spectrum "$Xsource(Voltage) [expr {1e9 / (4 * $Math::Pi)}]"

	} else {

		# xray tube, use xraytools
		set AngleOut $Xsource(TargetAngle)
		if { [string is double -strict $Xsource(AngleIn)] } {
			set AngleIn $Xsource(AngleIn)
		} else {
			set AngleIn [expr {90 - $AngleOut}]
			set Xsource(AngleIn) $AngleIn
		}

		set compute true
		set mode [Preferences::Get Source ComputationMode]
		set keys [list \
			[expr { $Xsource(Transmission) ? "Transmission" : "Direct" }] \
			[Materials::get $Xsource(TargetMaterial) composition] \
			[expr { double([Materials::get $Xsource(TargetMaterial) density]) }] \
			[expr { double($Xsource(TargetThickness)) }] \
			[expr { double($AngleIn) }] \
			[expr { double($AngleOut) }] \
			[expr { double($Xsource(Voltage)) }] \
			[expr { double($Xsource(Resolution)) }] \
			$mode \
		]

		set persistent [Preferences::Get Source PersistentCache]
		if { $persistent } {

			variable SpectrumDir

			set path $SpectrumDir
			foreach key $keys { set path [file join $path [Utils::SanitizeFileName $key]] }
			append path .xrs

			if { [Utils::FileReadable $path] } { set cached $path }

		}

		aRTist::Verbose { "Computing spectrum" }

		set options {}
		switch -nocase -- $mode {
			Precise { lappend options --Interpolation false }
			Fast    { lappend options --BSModel XRTFast }
		}
		lappend options --Transmission [expr { $Xsource(Transmission) ? "true" : "false" }]
		lappend options --Thickness [expr { $Xsource(TargetThickness) / 10.0 }]
		lappend options --Angle-Out $AngleOut --Angle-In $AngleIn
		lappend options --kVp $Xsource(Voltage) --EBin $Xsource(Resolution)
		lappend options --Current 1 --Time 1

		# compute the spectrum
		Engine::UpdateMaterials $Xsource(TargetMaterial)
		xrEngine GenerateSpectrum $Xsource(TargetMaterial) [Engine::quotelist {*}$options]

		if { [catch {

			if { $persistent } {
				set cached $path
				file mkdir [file dirname $cached]
			} else {
				set cached [TempFile::mktmp .xrs]
			}

			aRTist::Verbose { "Caching computed spectrum: '$cached'" }
			WriteXRS $cached [Engine::GetSpectrum]

			if { !$persistent } { dict set ComputedSpectra {*}$keys $cached }

		} err errdict] } {
			aRTist::Info { "Failed to cache computed spectrum: $err" }
		}

		# filter by window material
		if { $Xsource(WindowThickness) > 0 && ![string match -nocase VOID $Xsource(WindowMaterial)] && ![string match -nocase NONE $Xsource(WindowMaterial)] } {
			Engine::UpdateMaterials $Xsource(WindowMaterial)
			# Thickness is in mm, XRayTools expect cm
			xrEngine FilterSpectrum $Xsource(WindowMaterial) [Engine::quotelist --Thickness [expr {$Xsource(WindowThickness) / 10.0}]]
		}

		# build comments
		set description "X-ray tube ($Xsource(Tube)): $Xsource(TargetMaterial), $Xsource(Voltage) kV, $Xsource(TargetAngle)\u00B0"
		if { $Xsource(WindowThickness) > 0 } { append description ", $Xsource(WindowThickness) mm $Xsource(WindowMaterial)" }

		# Filter by any additional windows (JSON supports more than one window)
		set i 0
		foreach {materialID thickness} $windows {
			if {$i > 0} {
				aRTist::Info { "Filtering with additional window: $thickness mm $materialID."}
				Engine::UpdateMaterials $materialID
				# Thickness is in mm, XRayTools expect cm
				xrEngine FilterSpectrum $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]

				if { $thickness > 0 } { append description ", $thickness mm $materialID" }
			}
			incr i						
		}


		# filter by external filter material
		if { $Xsource(FilterThickness) > 0 && ![string match -nocase VOID $Xsource(FilterMaterial)] && ![string match -nocase NONE $Xsource(FilterMaterial)] } {
			Engine::UpdateMaterials $Xsource(FilterMaterial)
			# Thickness is in mm, XRayTools expect cm
			xrEngine FilterSpectrum $Xsource(FilterMaterial) [Engine::quotelist --Thickness [expr {$Xsource(FilterThickness) / 10.0}]]
		}
		
		if { $Xsource(FilterThickness) > 0 } { append description ", $Xsource(FilterThickness) mm $Xsource(FilterMaterial)" }

		# Filter by any additional filters (JSON supports more than one filter)
		set i 0
		foreach {materialID thickness} $filters {
			if {$i > 0} {
				aRTist::Info { "Filtering with additional filter: $thickness mm $materialID."}
				Engine::UpdateMaterials $materialID
				# Thickness is in mm, XRayTools expect cm
				xrEngine FilterSpectrum $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]

				if { $thickness > 0 } { append description ", $thickness mm $materialID" }
			}
			incr i						
		}

		lappend spectrum "# $description"
		lappend spectrum "# Name: $Xsource(Tube)"
		foreach line [Engine::GetSpectrum] {
			if { ![regexp {^\s*#\s*Directory:} $line] } { lappend spectrum $line }
		}

	}

	::XSource::ClearOrigSpectrum
	set Xsource_private(Spectrum) $spectrum
	set Xsource_private(SpectrumName) $Xsource(Tube)
	set Xsource_private(SpectrumDescription) $description
	set Xsource(HalfLife) 0
	set Xsource(computed) 1
	::XSource::GeneratePreviewSpectrum

	set fname [TempFile::mktmp .xrs]
	::XSource::WriteXRS $fname
	XRayProject::AddFile Source spectrum $fname .xrs

	return $fname
}

proc XSourceListToEngineSpectrumString { xsourceList } {
	set spectrum ""
	set i 0
	foreach entry $xsourceList {				
		if { ![regexp {^\s*#} $entry] } {
			set entries [split $entry]
			if {[llength $entries] > 1} {
				set energy [lindex $entries 0]
				set counts [lindex $entries 1]
				if {$i > 0} {
					append spectrum "\n"
				}

				append spectrum "$energy	$counts"
				incr i
			}
		}
	}

	return $spectrum
}

proc engineSpectrumStringToXSourceList { engineString } {
	set spectrum {}
	foreach entry [split $engineString \n] {				
		if { ![regexp {^\s*#} $entry] } {
			set entries [split $entry]
			#puts "Entries: $entries"
			if {[llength $entries] > 1} {
				set energy [lindex $entries 0]
				set counts [lindex $entries 1]

				lappend spectrum [list $energy $counts]
			}
		}
	}

	return $spectrum
}

proc loadCSVintoTabSeparatedString { filename } {
	aRTist::Info { "Reading CSV into tab separeted string: $filename"}
	# $file will contain the file pointer to test.txt (file must exist)
	set file [open $filename]

	# $input will contain the contents of the file
	set input [read $file]

	# Clean up
	close $file

	# $lines will be an array containing each line of test.txt
	set lines [split $input "\n"]

	# Loop through each line
	set text ""
	set i 0
	foreach line $lines {
		# skip empty lines
		if {[string length $line] > 0} {
			# skip comments
		    if { ![regexp {^\s*#} $line] } {

		    	if {$i > 0} {
		    		append text "\n"
		    	}

		    	# split on comma or white space
		    	set entries [split $line " \t,"]
		    	set j 0
		    	foreach entry $entries {
		    		if {$j > 0} {
		    			append text "\t"
		    		}
		    		append text $entry
		    		incr j
		    	}
		    	incr i
		    }
		}
	}

	return $text
}

proc loadCSVintoList { filename } {
	aRTist::Info { "Reading CSV into tab separeted string: $filename"}
	# $file will contain the file pointer to test.txt (file must exist)
	set file [open $filename]

	# $input will contain the contents of the file
	set input [read $file]

	# Clean up
	close $file

	# $lines will be an array containing each line of test.txt
	set lines [split $input "\n"]

	# Loop through each line
	set csvList {}
	foreach line $lines {
		# skip empty lines
		if {[string length $line] > 0} {
			# skip comments
		    if { ![regexp {^\s*#} $line] } {
		    	# split on comma or white space
		    	set entries [split $line " \t,"]
		    	lappend csvList $entries 
		    }
		}
	}

	return $csvList
}

proc LoadSpectrum { file windows filters } {
	# Filter the loaded spectrum by $filters, but not by $windows (latter only for description).

	::aRTist::Info { "Loading spectrum file: $file" }

	global Xsource Xsource_private
	variable ComputedSpectra

	#::XSource::LoadSpectrum $file
	# load spectrum
	#set spectrumList [XSource::GetSpectrum]
	#set spectrumString [XSourceListToEngineSpectrumString $spectrumList]
	set spectrumString [loadCSVintoTabSeparatedString $file]

	# build comments
	set description "X-ray tube ($Xsource(Tube)): $Xsource(TargetMaterial), $Xsource(Voltage) kV, $Xsource(TargetAngle)\u00B0"
	if { $Xsource(WindowThickness) > 0 } { append description ", $Xsource(WindowThickness) mm $Xsource(WindowMaterial)" }

	# Add any additional window materials to description (JSON supports more than one window)
	set i 0
	foreach {materialID thickness} $windows {
		if {$i > 0} {
			if { $thickness > 0 } { append description ", $thickness mm $materialID" }
		}
		incr i						
	}

	# Filter by any additional filters (JSON supports more than one filter)
	foreach {materialID thickness} $filters {
		aRTist::Info { "Filtering with additional filter: $thickness mm $materialID."}
		Engine::UpdateMaterials $materialID
		# Thickness is in mm, XRayTools expect cm
		set spectrumString [xrEngine FilterSpectrum $spectrumString $materialID [Engine::quotelist --Thickness [expr {$thickness / 10.0}]]]

		if { $thickness > 0 } { append description ", $thickness mm $materialID" }			
	}

	set spectrum [ engineSpectrumStringToXSourceList $spectrumString ]

	::XSource::ClearOrigSpectrum
	set Xsource_private(Spectrum) $spectrum
	set Xsource_private(SpectrumName) $Xsource(Tube)
	set Xsource_private(SpectrumDescription) $description
	set Xsource(HalfLife) 0
	set Xsource(computed) 1
	::XSource::GeneratePreviewSpectrum

	set fname [TempFile::mktmp .xrs]
	::XSource::WriteXRS $fname
	XRayProject::AddFile Source spectrum $fname .xrs
}

proc makeGaussianSpotProfile { sigmaX sigmaY } {
	global Xsource_private
	set Xsource_private(SpotRes) 301
	set Xsource_private(SpotLorentz) 0.0

	# Spot width and height are assumed to be FWHM of Gaussian profile.
	# Convert sigma to FWHM:
	set Xsource_private(SpotWidth) [expr 2.3548*$sigmaX]
	set Xsource_private(SpotHeight) [expr 2.3548*$sigmaY]

	set ::Xsetup(SourceSampling) 30
	::XSource::SelectSpotType

	aRTist::Info { "Setting Gaussian spot size. sigmaX=$sigmaX, sigmaY=$sigmaY."}

	::XSource::SetSpotProfile
}

proc load_json { jsonfilename } {
	variable ctsimu_scenario

	$ctsimu_scenario reset; # also sets JSON load status to 0 (not yet successful)
	
	# Set up internal representation:
	$ctsimu_scenario setup_json_scene $jsonfilename



	variable ctsimuSceneMaterials
	global Xsource_private

	# clear global lists:
	#set ctsimuSettings {}
	set ctsimuSamples {}
	set ctsimuSceneMaterials {}

	set jsonfiledir [file dirname "$jsonfilename"]

	set jsonfile [open $jsonfilename r]
	fconfigure $jsonfile -encoding utf-8
	set jsonstring [read $jsonfile]
	close $jsonfile

	# Set output folder and basename for projections:
	$ctsimu_scenario setOutputFolderFromJSON $jsonfilename
	$ctsimu_scenario setBasenameFromJSON $jsonfilename

	set scene $jsonstring
	set scenarioName "CTSimU"

	if {[json exists $scene file file_type]} {
		set filetype [getValue $scene {file file_type}]
		if {$filetype == "CTSimU Scenario"} {

			# Check if file format version exists
			if {([json exists $scene file version major] && [json exists $scene file version minor]) || ([json exists $scene file file_format_version major] && [json exists $scene file file_format_version minor])} {
				
				# Check version to correctly interpret JSON
				set version_major [getValue $scene {file file_format_version major}]
				set version_minor [getValue $scene {file file_format_version minor}]

				if {($version_major == "null") && ($version_minor == "null")} {
					set version_major [getValue $scene {file version major}]
					set version_minor [getValue $scene {file version minor}]
				}

				# Parsing for version 0.3 to 0.8:
				if {$version_major == 0 && ( $version_minor == 3 || $version_minor == 4 || $version_minor == 5 || $version_minor == 6 || $version_minor == 7 || $version_minor == 8 )} {
					aRTist::Info { "Scenario Version $version_major.$version_minor" }

					set scenarioName [getValue $scene {file name}]

					# Geometry dictionaries for detector, source and stage (from JSON)
					set detectorGeometry 0
					set sourceGeometry 0
					set stageGeometry 0

					# Coordinate Systems:
					set csSource   0
					set csStage    0
					set csDetector 0

					showInfo "Setting up geometry..."

					# Set up stage:
					if [json exists $scene geometry stage] {
						set stageGeometry [json extract $scene geometry stage]
						set csStage [makeCoordinateSystemFromGeometry "Stage" $stageGeometry $csWorld]
						dict set ctsimuSettings csStage $csStage
					} else {
						fail "Cannot find stage geometry."
						return
					}

					# Set up detector geometry:
					if [json exists $scene geometry detector] {
						set detectorGeometry [json extract $scene geometry detector]
						set csDetector [makeCoordinateSystemFromGeometry D $detectorGeometry $csStage]
						aRTist_placeObjectInCoordinateSystem D $csDetector
						dict set ctsimuSettings csDetector $csDetector
					} else {
						fail "Cannot find detector geometry."
						return
					}

					# Set up source geometry:
					if [json exists $scene geometry source] {
						set sourceGeometry [json extract $scene geometry source]
						set csSource [makeCoordinateSystemFromGeometry S $sourceGeometry $csStage]
						aRTist_placeObjectInCoordinateSystem S $csSource
						dict set ctsimuSettings csSource $csSource
					} else {
						fail "Cannot find source geometry."
						return
					}


					# Centre points
					set S [dict get $csSource centre]
					set O [dict get $csStage centre]
					set D [dict get $csDetector centre]

					# Source centre:
					set xS [lindex $S 0]
					set yS [lindex $S 1]
					set zS [lindex $S 2]

					# Detector centre and coordinate system
					set xD [lindex $D 0]
					set yD [lindex $D 1]
					set zD [lindex $D 2]
					set uD [vec3Unit [dict get $csDetector u]]
					set vD [vec3Unit [dict get $csDetector v]]
					set wD [vec3Unit [dict get $csDetector w]]

					# Stage coordinate system
					set uO [vec3Unit [dict get $csStage u]]
					set vO [vec3Unit [dict get $csStage v]]
					set wO [vec3Unit [dict get $csStage w]]

					# Centre of stage is transformed to be at origin (0, 0, 0).
					# New centre of source in world CS:
					set rfoc [vec3Diff $S $O]

					# New centre of source in stage CS (which is world CS as far as the projection matrix is concerned):
					set m_worldToStage [basisTransformMatrix $csWorld $csStage]

					set rfoc_in_stageCS [::math::linearalgebra::matmul $m_worldToStage $rfoc]

					set xfoc [lindex $rfoc_in_stageCS 0]
					set yfoc [lindex $rfoc_in_stageCS 1]
					set zfoc [lindex $rfoc_in_stageCS 2]

					# Focus point on detector,
					# i.e. intersection of Source->Stage vector with detector plane.
					# clFDK assumes detector (u, v) coordinate system in mm units,
					# origin at detector centre, u points "right", v points "down".
					
					# Focus unit vector, pointing from source to stage,
					# will intersect with detector plane (hopefully ;-)
					set efoc [vec3Unit [vec3Diff $O $S]]
					set efoc_x [lindex $efoc 0]
					set efoc_y [lindex $efoc 1]
					set efoc_z [lindex $efoc 2]

					# Detector normal:
					set nx [lindex $wD 0]
					set ny [lindex $wD 1]
					set nz [lindex $wD 2]

					# The SDD in this concept means the distance between the source S
					# and the intersection point of vector efoc with the detector plane.
					set E [expr $nx*$xD + $ny*$yD + $nz*$zD]
					set SDD [expr ($E - $xS*$nx - $yS*$ny - $zS*$nz)/($nx*$efoc_x + $ny*$efoc_y + $nz*$efoc_z)]




					# SDD and SOD:
					set SDDcentre2centre [expr abs([vec3Dist $S $D])]
					set SOD [expr abs([vec3Dist $S $O])]
					set ODD [expr abs($SDD - $SOD)]
					dict set ctsimuSettings SOD $SOD
					dict set ctsimuSettings SDDcentre2centre $SDDcentre2centre
					dict set ctsimuSettings SDD $SDD
					dict set ctsimuSettings ODD $ODD
					#dict set ctsimuSettings stageCenterOnDetectorU $stageCenterOnDetectorU
					#dict set ctsimuSettings stageCenterOnDetectorV $stageCenterOnDetectorV

					# Save a source CS as seen from the detector CS. This is convenient to
					# later get the SDD, ufoc and vfoc:
					set sourceFromDetector [changeReferenceFrame $csSource $csWorld $csDetector]
					set stageFromDetector [changeReferenceFrame $csStage $csWorld $csDetector]

					# Focus point on detector: principal, perpendicular ray.
					# In the detector coordinate system, ufoc and vfoc are the u and v coordinates
					# of the source center; SDD (perpendicular to detector plane) is source w coordinate.
					set sourceCenterInDetectorCS [dict get $sourceFromDetector centre]
					set stageCenterInDetectorCS [dict get $stageFromDetector centre]

					#set ufoc [lindex $sourceCenterInDetectorCS 0]
					#set vfoc [lindex $sourceCenterInDetectorCS 1]
					set SDDbrightestSpot [lindex $sourceCenterInDetectorCS 2]
					set SDDbrightestSpot [expr abs($SDDbrightestSpot)]
					set SODbrightestSpot [lindex $stageCenterInDetectorCS 2]
					set SODbrightestSpot [expr abs($SODbrightestSpot)]

					aRTist::Info {"SDD: $SDD"}
					aRTist::Info {"SDD center to center: $SDDcentre2centre"}
					aRTist::Info {"SDD brightest spot: $SDDbrightestSpot"}
					aRTist::Info {"Stage on Detector u: $stageCenterOnDetectorU"}
					aRTist::Info {"Stage on Detector v: $stageCenterOnDetectorV"}

					dict set ctsimuSettings SDDbrightestSpot $SDDbrightestSpot
					dict set ctsimuSettings SODbrightestSpot $SODbrightestSpot
					#dict set ctsimuSettings ufoc $ufoc
					#dict set ctsimuSettings vfoc $vfoc

					# Set up materials:
					showInfo "Setting up materials..."
					if [json exists $scene materials] {
						json foreach mat [json extract $scene materials] {
							if {[json exists $mat id] && [json exists $mat density value] && [json exists $mat composition] && [json exists $mat name]} {
								addMaterial [json get $mat id] [in_g_per_cm3 [json extract $mat density]] [json get $mat composition] [json get $mat name]
							}
						}
					}

					# Samples must be loaded to be centreed at (0, 0, 0):
					set ::aRTist::LoadCentreed 1

					# Import samples:
					showInfo "Importing samples..."
					if {![json isnull $scene samples]} {
						if [json exists $scene samples] {
							set samplesDict [json extract $scene samples]
							#set nSamples [json length $samplesDict]
							#aRTist::Info { "$nSamples samples found." }

							set i 1
							json foreach sample $samplesDict {
								if {$sample != "null"} {
									set STLfilename [json get $sample file]
									set STLname [json get $sample name]
									set STLpath $jsonfiledir
									append STLpath "/$STLfilename"
									aRTist::Info { "STL found: $STLpath"}

									set id $i
									set sampleMaterial "Al"
									if [json exists $sample material_id] {
										set sampleMaterial [getMaterialID [json get $sample material_id]]
									}

									set id [::PartList::LoadPart "$STLpath" "$sampleMaterial" "$STLname" yes]

									set sampleGeometry [json extract $sample position]
									set csSample [makeCoordinateSystemFromGeometry $id $sampleGeometry $csStage]
									aRTist_placeObjectInCoordinateSystem $id $csSample

									# Scale according to JSON:
									set scaleX 1
									set scaleY 1
									set scaleZ 1

									if {[json exists $sample scaling_factor r]} {
										set scaleX [json get $sample scaling_factor r]
									}

									if {[json exists $sample scaling_factor s]} {
										set scaleY [json get $sample scaling_factor s]
									}

									if {[json exists $sample scaling_factor t]} {
										set scaleZ [json get $sample scaling_factor t]
									}

									set objectSize [::PartList::Invoke $id GetSize]

									set sizeX [expr $scaleX*[lindex $objectSize 0]]
									set sizeY [expr $scaleY*[lindex $objectSize 1]]
									set sizeZ [expr $scaleZ*[lindex $objectSize 2]]

									::PartList::Invoke $id SetSize $sizeX $sizeY $sizeZ

									# Make sample object, consisting of original size and coordinate system:
									set sampleObject [dict create coordinates $csSample originalSizeX $sizeX originalSizeY $sizeY originalSizeZ $sizeZ]

									puts "Appending to ctsimuSamples."
									lappend ctsimuSamples $sampleObject

									incr i
								}
							}
						}
					}

					# Set environment material:
					if [json exists $scene environment material_id] {
						set environmentMaterial [getMaterialID [json get $scene environment material_id]]
						set ::Xsetup(SpaceMaterial) $environmentMaterial
					}

					# Acquisition parameters:
					showInfo "Setting acquisition parameters..."
					if [json exists $scene acquisition start_angle] {
						$ctsimu_scenario setStartAngle [in_deg [json extract $scene acquisition start_angle]]
					} else {
						fail "Start angle not specified."
						return
					}

					if [json exists $scene acquisition stop_angle] {
						$ctsimu_scenario setStopAngle [in_deg [json extract $scene acquisition stop_angle]]
					} else {
						fail "Stop angle not specified."
						return
					}

					
					if [json exists $scene acquisition angular_steps] {
						# Format version 0.3:
						setnProjections [json get $scene acquisition angular_steps]
					} elseif [json exists $scene acquisition number_of_projections] {
						# Format version >=0.4:
						setnProjections [json get $scene acquisition number_of_projections]
					} else {
						fail "Number of resulting projections not specified."
						return
					}

					if [json exists $scene acquisition direction] {
						setScanDirection [json get $scene acquisition direction]
					} else {
						fail "Scan direction not specified."
						return
					}

					if [json exists $scene acquisition include_final_angle] {
						# Format version >=0.4:
						puts "Include final angle:"
						puts [from_bool [json get $scene acquisition include_final_angle]]
						setIncludeFinalAngle [from_bool [json get $scene acquisition include_final_angle]]
					} elseif [json exists $scene acquisition projection_at_final_angle] {
						# Format version 0.3:
						puts "Include final angle:"
						puts [from_bool [json get $scene acquisition projection_at_final_angle]]
						setIncludeFinalAngle [from_bool [json get $scene acquisition projection_at_final_angle]]
					} else {
						setIncludeFinalAngle 0
					}

					setProjNr 0

					# Source setup
					showInfo "Setting source parameters..."
					# Spectrum
					if [json exists $scene source spectrum monochromatic] {
						if {[from_bool [json get $scene source spectrum monochromatic]] == 1} {
							set ::Xsource(Tube) Mono
						}
					}

					if [json exists $scene source spectrum bremsstrahlung] {
						if {[from_bool [json get $scene source spectrum bremsstrahlung]] == 1} {
							set ::Xsource(Tube) General
						}
					}

					if [json exists $scene source spectrum characteristic] {
						if {[from_bool [json get $scene source spectrum characteristic]] == 1} {
							set ::Xsource(Tube) General
						}
					}

					set ::Xsource(Resolution) 0.5


					# Voltage and Current
					set current 0
					if [json exists $scene source current] {
						set current [in_mA [json extract $scene source current]]
						set ::Xsource(Exposure) $current
					}

					set voltage 0
					if [json exists $scene source voltage] {
						set voltage [in_kV [json extract $scene source voltage]]
						set ::Xsource(Voltage) $voltage
					}

					# Target
					if [json exists $scene source target type] {
						if { [json get $scene source target type] == "transmission" } {
							set ::Xsource(Transmission) 1
						} else {
							set ::Xsource(Transmission) 0
						}
					}
					
					if [json exists $scene source target material_id] {
						set ::Xsource(TargetMaterial) [getMaterialID [json get $scene source target material_id]]
					}

					if [json exists $scene source target thickness] {
						if {[isNullOrZero_jsonObject [json extract $scene source target thickness]] == 0} {
							set ::Xsource(TargetThickness) [in_mm [json extract $scene source target thickness]]
						}
					}

					if [json exists $scene source target angle incidence value] {
						set ::Xsource(AngleIn) [in_deg [json extract $scene source target angle incidence]]
					}

					if [json exists $scene source target angle emission value] {
						set ::Xsource(TargetAngle) [in_deg [json extract $scene source target angle emission]]
					}

					set tubeName $scenarioName
					append tubeName " Tube"
					set tubeManufacturer ""
					set tubeModel ""
					if {[json exists $scene source manufacturer]} {
						set tubeManufacturer [json get $scene source manufacturer]
					}
					if {[json exists $scene source model]} {
						set tubeModel [json get $scene source model]
					}
					if { $tubeManufacturer != "" } {
						set tubeName $tubeManufacturer
					}
					if { $tubeModel != "" } {
						if { $tubeManufacturer != "" } {
							append tubeName " "
							append tubeName $tubeModel
						} else {
							set tubeName $tubeModel
						}
					}
					puts "Setting tube name to $tubeName"
					set ::Xsource(Name) $tubeName

					# Source filters
					# Generate filter list:
					set xraySourceFilters {}
					set windowFilters {}

					if {$version_major == 0 && ( $version_minor == 3 || $version_minor == 4 || $version_minor == 5)} {
						if [json exists $scene source filters] {
							set i 0
							json foreach mat [json extract $scene source filters] {
								if { $mat != "null" } {
									if {$i == 0} {
										# First material in the source filters list is the window:
										if [json exists $mat material_id] {
											set ::Xsource(WindowMaterial) [getMaterialID [json get $mat material_id]]
											if [json exists $mat thickness value] {
												set ::Xsource(WindowThickness) [in_mm [json extract $mat thickness]]
												lappend windowFilters [getMaterialID [json get $mat material_id]]
												lappend windowFilters [in_mm [json extract $mat thickness]]
											}
										}
										
									} elseif { $i == 1 } {
										# Second material in the source filters list is the filter material:
										if [json exists $mat material_id] {
											set ::Xsource(FilterMaterial) [getMaterialID [json get $mat material_id]]
											if [json exists $mat thickness value] {
												set ::Xsource(FilterThickness) [in_mm [json extract $mat thickness]]
												lappend xraySourceFilters [getMaterialID [json get $mat material_id]]
												lappend xraySourceFilters [in_mm [json extract $mat thickness]]
											}
										}
									} else {
										# Further filters:
										if [json exists $mat material_id] {
											if [json exists $mat thickness value] {
												lappend xraySourceFilters [getMaterialID [json get $mat material_id]]
												lappend xraySourceFilters [in_mm [json extract $mat thickness]]
											}
										}
									}

									incr i
								}
							}
						}
					} else {
						# From 0.6 on, the window and filters are separate entries.
						if [json exists $scene source window] {
							set i 0
							json foreach mat [json extract $scene source window] {
								if {$i == 0} {
									if [json exists $mat material_id] {
										set ::Xsource(WindowMaterial) [getMaterialID [json get $mat material_id]]
										if [json exists $mat thickness value] {
											set ::Xsource(WindowThickness) [in_mm [json extract $mat thickness]]
										}
									}
								}

								if [json exists $mat material_id] {
									if [json exists $mat thickness value] {
										lappend windowFilters [getMaterialID [json get $mat material_id]]
										lappend windowFilters [in_mm [json extract $mat thickness]]
									}
								}

								incr i
							}
						}

						if [json exists $scene source filters] {
							set i 0
							json foreach mat [json extract $scene source filters] {
								if {$i == 0} {
									if [json exists $mat material_id] {
										set ::Xsource(FilterMaterial) [getMaterialID [json get $mat material_id]]
										if [json exists $mat thickness value] {
											set ::Xsource(FilterThickness) [in_mm [json extract $mat thickness]]
										}
									}								
								}

								if [json exists $mat material_id] {
									if [json exists $mat thickness value] {
										lappend xraySourceFilters [getMaterialID [json get $mat material_id]]
										lappend xraySourceFilters [in_mm [json extract $mat thickness]]
									}
								}

								incr i
							}
						}
					}

					# New spectrum: use from file?
					set usingSpectrumFile 0
					if [json exists $scene source spectrum file] {
						set filename [json get $scene source spectrum file]
						if {$filename != "null" } {
							set fullpath $jsonfiledir
							append fullpath "/$filename"
							
							set usingSpectrumFile 1
							showInfo "Loading spectrum file..."

							if {$version_major == 0 && ( $version_minor == 3 || $version_minor == 4 || $version_minor == 5)} {
								# File versions prior to 0.6 assume that spectrum from file
								# is already filtered by all filters and the source window.
								::XSource::LoadSpectrum $fullpath
							} else {
								# File versions from 0.6 on assume that spectrum file is only filtered by window material.
								# Filter by any additional filters (JSON supports more than one filter)
								LoadSpectrum $fullpath $windowFilters $xraySourceFilters
							}
						}
					}

					# Compute new spectrum
					if {$usingSpectrumFile == 0} {
						showInfo "Computing spectrum..."
						ComputeSpectrum $windowFilters $xraySourceFilters
					}

					# Spot size
					showInfo "Setting spot intensity profile..."

					set sigmaX    [getValueInMM $scene {source spot sigma u}]
					set sigmaY    [getValueInMM $scene {source spot sigma v}]
					set spotSizeX [getValueInMM $scene {source spot size u}]
					set spotSizeY [getValueInMM $scene {source spot size v}]

					# If a finite spot size is provided, but no Gaussian sigmas,
					# the spot size is assumed to be the Gaussian width.
					if { [isNullOrZero_value $sigmaX] } {
						aRTist::Info { "sigmaX is null or 0, retreating to spotSizeX." }
						set sigmaX $spotSizeX
					}
					if { [isNullOrZero_value $sigmaY] } {
						aRTist::Info { "sigmaY is null or 0, retreating to spotSizeY." }
						set sigmaY $spotSizeY
					}

					if { [isNullOrZero_value $sigmaX] || [isNullOrZero_value $sigmaY] } {
						# Point source
						aRTist::Info { "sigmaX=0 or sigmaY=0. Setting point source." }
						
						set Xsource_private(SpotWidth) 0
						set Xsource_private(SpotHeight) 0
						set ::Xsetup_private(SGSx) 0
						set ::Xsetup_private(SGSy) 0
						set ::Xsetup(SourceSampling) point

						::XSource::SelectSpotType

						# Set detector multisampling to achieve partial volume effect:
						set ::Xsetup(DetectorSampling) 3x3
						#set ::Xsetup(DetectorSampling) {source dependent}
					} else {
						# Source multisampling:
						# Create a Gaussian spot profile, and activate source-dependent
						# multisampling for the detector.
						makeGaussianSpotProfile $sigmaX $sigmaY
						set ::Xsetup(DetectorSampling) {source dependent}
					}

					# Override detector and spot multisampling, if defined in JSON:
					set multisampling_detector [getValue $scene {simulation aRTist multisampling_detector}]
					if {$multisampling_detector != "null"} {
						set ::Xsetup(DetectorSampling) $multisampling_detector
					}

					set multisampling_source   [getValue $scene {simulation aRTist multisampling_spot}]
					if {$multisampling_source != "null"} {
						set ::Xsetup(SourceSampling) $multisampling_source
						::XSource::SelectSpotType
					}

					::XSource::SourceSizeModified


					# Scattering
					showInfo "Setting up scattering..."
					if [json exists $scene acquisition scattering] {
						if { [from_bool [json get $scene acquisition scattering]] == 1 } {
							set ::Xscattering(Mode) McRay
							set ::Xscattering(AutoBase) min
							set ::Xscattering(nPhotons) 2e+007
						} else {
							set ::Xscattering(Mode) off
						}
					}

					set scattering_photons [getValue $scene {simulation aRTist scattering_mcray_photons}]
					if {$scattering_photons != "null"} {
						set ::Xscattering(nPhotons) $scattering_photons
					}
					
					

					# Detector setup:
					showInfo "Setting up detector..."

					 # Set frame averaging to 1 for now:
					 set ::Xdetector(NrOfFrames) 1

					Preferences::Set Detector AutoVar Size
					set ::Xsetup_private(DGauto) Size
					::XDetector::SelectAutoQuantity

					set detectorName $scenarioName
					append detectorName " Detector"
					set detectorManufacturer ""
					set detectorModel ""
					if {[json exists $scene source manufacturer]} {
						set detectorManufacturer [json get $scene source manufacturer]
					}
					if {[json exists $scene source model]} {
						set detectorModel [json get $scene source model]
					}
					if { $detectorManufacturer != "" } {
						set detectorName $detectorManufacturer
					}
					if { $detectorModel != "" } {
						if { $detectorManufacturer != "" } {
							append detectorName " "
							append detectorName $detectorModel
						} else {
							set detectorName $detectorModel
						}
					}
					puts "Setting detector name to $detectorName"

					# Detector type:
					set detectorType "real"
					if [json exists $scene detector type] {
						set value [json get $scene detector type]
						if {$value == "ideal"} {
							set detectorType "ideal"
						} elseif {$value == "real"} {
							set detectorType "real"
						} else {
							fail "Unknown detector type: $value"
							return
						}
					}

					set pixelCountU 0
					set pixelCountV 0

					if [json exists $scene detector columns value] {
						set pixelCountU [json get $scene detector columns value]
						set ::Xsetup(DetectorPixelX) $pixelCountU
					}

					if [json exists $scene detector rows value] {
						set pixelCountV [json get $scene detector rows value]
						set ::Xsetup(DetectorPixelY) $pixelCountV
					}

					set ::Xsetup(SquarePixel) 0

					set detPixelSizeU 0
					if [json exists $scene detector pixel_pitch u] {
						set detPixelSizeU [in_mm [json extract $scene detector pixel_pitch u]]
						set ::Xsetup_private(DGdx) $detPixelSizeU
					}

					set detPixelSizeV 0
					if [json exists $scene detector pixel_pitch v] {
						set detPixelSizeV [in_mm [json extract $scene detector pixel_pitch v]]
						set ::Xsetup_private(DGdy) $detPixelSizeV
					}

					set scintillatorMaterialID ""
					if [json exists $scene detector scintillator material_id] {
						set scintillatorMaterialID [getMaterialID [json get $scene detector scintillator material_id]]
					}

					set scintillatorThickness 0
					if [json exists $scene detector scintillator thickness value] {
						set scintillatorThickness [in_mm [json extract $scene detector scintillator thickness]]
					}

					set integrationTime 0
					if [json exists $scene detector integration_time value] {
						set integrationTime [in_s [json extract $scene detector integration_time]]
						set ::Xdetector(AutoD) off
						set ::Xdetector(Scale) $integrationTime
					}

					::XDetector::UpdateGeometry %W

					# Detector Characteristics
					# Deactivate flat field correction (not done in aRTist for the CTSimU project)
					set ::Xdetector(FFCorrRun) 0
					::XDetector::FFCorrClearCmd

					set minEnergy 0
					set maxEnergy 1000
					# the SNR refers to 1 frame, not an averaged frame:
					set nFrames 1

					# Generate filter list:
					set frontPanelFilters {}
					if [json exists $scene detector filters front] {
						if {[isNullOrZero_value [json extract $scene detector filters front]] == 0} {
							json foreach mat [json extract $scene detector filters front] {
								if {$mat != "null"} {
									lappend frontPanelFilters [getMaterialID [json get $mat material_id]]
									lappend frontPanelFilters [in_mm [json extract $mat thickness]]
								}
							}
						}
					}

					# Basic spatial resolution:
					set SRb "null"
					if [json exists $scene detector sharpness basic_spatial_resolution value] {
						set SRb [in_mm [json extract $scene detector sharpness basic_spatial_resolution]]
					}

					# Grey values:
					set bitDepth 16
					if [json exists $scene detector bit_depth value] {
						set bitDepth [json get $scene detector bit_depth value]
					}
					set maxGVfromDetector [expr pow(2, $bitDepth)-1]

					set GVatMin "null"
					if [json exists $scene detector grey_value imin value] {
						set GVatMin [json get $scene detector grey_value imin value]
					}

					set GVatMax "null"
					if [json exists $scene detector grey_value imax value] {
						set GVatMax [json get $scene detector grey_value imax value]
					}

					set GVfactor "null"
					if [json exists $scene detector grey_value factor value] {
						set GVfactor [json get $scene detector grey_value factor value]
					}

					set GVoffset "null"
					if [json exists $scene detector grey_value offset value] {
						set GVoffset [json get $scene detector grey_value offset value]
					}

					# Signal to noise ratio (SNR)
					set SNRatImax "null"
					set FWHMatImax "null"
					if [json exists $scene detector noise snr_at_imax value] {
						set SNRatImax [json get $scene detector noise snr_at_imax value]
					}
					if [json exists $scene detector noise fwhm_at_imax value] {
						set FWHMatImax [json get $scene detector noise fwhm_at_imax value]
					}

					showInfo "Calculating detector characteristics..."

					set detector [generateDetector $detectorName $detectorType $detPixelSizeU $detPixelSizeV $pixelCountU $pixelCountV $scintillatorMaterialID $scintillatorThickness $minEnergy $maxEnergy $current $integrationTime $nFrames $frontPanelFilters $SDDbrightestSpot $SRb $SNRatImax $FWHMatImax $maxGVfromDetector $GVatMin $GVatMax $GVfactor $GVoffset]

					# Set frame averaging:
					set nFramesToAverage [getValue $scene {acquisition frame_average}]
					if {![isNullOrZero_value $nFramesToAverage]} {
						set ::Xdetector(NrOfFrames) $nFramesToAverage
					}

					set nDarkFields [getValue $scene {acquisition dark_field number} ]
					if {![isNullOrZero_value $nDarkFields]} {
						set dfIdeal [from_bool [getValue $scene {acquisition dark_field ideal} ]]
						if { $dfIdeal == 1 } {
							dict set ctsimuSettings takeDarkField 1
						} else {
							fail "aRTist does not support non-ideal dark field images."
						}
					}

					set nFlatFields [getValue $scene {acquisition flat_field number} ]
					if {![isNullOrZero_value $nFlatFields]} {
						dict set ctsimuSettings nFlatFrames $nFlatFields

						set nFlatAvg [getValue $scene {acquisition flat_field frame_average} ]
						if {![isNullOrZero_value $nFlatAvg]} {
							if {$nFlatAvg > 0} {
								dict set ctsimuSettings nFlatAvg $nFlatAvg 
							} else {
								fail "Number of flat field frames to average must be greater than 0."
							}
						} else {
							fail "Number of flat field frames to average must be greater than 0."
						}

						set ffIdeal [from_bool [getValue $scene {acquisition flat_field ideal} ]]
						if {![isNullOrZero_value $ffIdeal]} {
							dict set ctsimuSettings ffIdeal $ffIdeal
						} else {
							dict set ctsimuSettings ffIdeal 0
						}

					} else {
						dict set ctsimuSettings nFlatFrames 0
						dict set ctsimuSettings nFlatAvg 1
						dict set ctsimuSettings ffIdeal 0
					}

					dict set ctsimuSettings startProjNr 0

					# Save and load detector:
					set detectorFilePath [::TempFile::mktmp .aRTdet]
					XDetector::write_aRTdet $detectorFilePath $detector
					Preferences::Set lastopen detectordir [file dirname $detectorFilePath]
					FileIO::OpenAnyGUI $detectorFilePath


					# Drift files.
					if {[json exists $scene drift]} {
						if {![json isnull $scene drift]} {

							# Detector drift:
							if {[json exists $scene drift detector]} {
								if {![json isnull $scene drift detector]} {
									set detectorDriftFile [json get $scene drift detector]
									
								}
							}
						}
					}

					createCERA_RDabcuv
					$ctsimu_scenario setJSONloadStatus 1; # loaded successfully
					
					return 1

				} else {
					fail "File format version number $version_major.$version_minor is not supported."
				}

			} else {
				fail { "Scenario file does not contain any valid file format version number." }
			}
		} else {
			fail { "This does not appear to be a CTSimU scenario file. Did you mistakenly open a metadata file?" }
		}
	} else {
		fail { "This does not appear to be a CTSimU scenario file. Did you mistakenly open a metadata file?" }
	}

	return 0
}

proc projectionMatrix { csSource csStage csDetector mode {psu 0} {psv 0} {nu 0} {nv 0}} {
	# mode: "clFDK" or "CERA" (they have different detector coordinate systems)

	# See dissertation: Matthias Ebert: "Non-ideal projection data in X-ray computed tomography"
	# and:
	# Hartley, Zisserman: "Multiple view geometry in computer vision" (2004), Chapter 6
	variable ctsimuSettings
	variable csWorld

	# Scale of the detector CS in units of the world CS (e.g. mm -> pixel)
	set scale_u  1.0
	set scale_v  1.0
	set scale_w -1.0

	if { $mode=="CERA" } {
		# CERA's detector CS has its origin in the lower left corner instead of the centre.
		# Let's move there:
		set D  [dict get $csDetector centre]
		set uD [dict get $csDetector u]
		set vD [dict get $csDetector v]
		set wD [dict get $csDetector w]
		set halfWidth  [expr $psu*$nu / 2.0]
		set halfHeight [expr $psv*$nv / 2.0]

		set D [vec3Diff $D [vec3Mul $uD $halfWidth]]
		set D [vec3Add  $D [vec3Mul $vD $halfHeight]]

		dict set csDetector centre $D

		# The v axis points up instead of down:
		#set csDetector [rotateCoordinateSystem $csDetector $uD 3.141592653589793]
		set vD [vec3Mul $vD -1]
		set wD [vec3Mul $wD -1]
		dict set csDetector v $vD
		dict set csDetector w $wD

		# The CERA detector also has a pixel CS instead of a mm CS:
		set scale_u [expr 1.0 / $psu]
		set scale_v [expr 1.0 / $psv]
		set scale_w 1.0
	}

	# Save a source CS as seen from the detector CS. This is convenient to
	# later get the SDD, ufoc and vfoc:
	set sourceFromDetector [changeReferenceFrame $csSource $csWorld $csDetector]

	# Make the stage CS the new world CS:
	set csSource [changeReferenceFrame $csSource $csWorld $csStage]
	set csDetector [changeReferenceFrame $csDetector $csWorld $csStage]
	set csStage [changeReferenceFrame $csStage $csWorld $csStage]


	# Centre points in a stage-centric projection coordinate system:
	set S [dict get $csSource centre]
	set O [dict get $csStage centre]

	# Translation vector from stage (O) to source (S):
	set rfoc [vec3Diff $S $O]
	set xfoc [expr [lindex $rfoc 0]]
	set yfoc [expr [lindex $rfoc 1]]
	set zfoc [expr [lindex $rfoc 2]]

	# Focus point on detector: principal, perpendicular ray.
	# In the detector coordinate system, ufoc and vfoc are the u and v coordinates
	# of the source center; SDD (perpendicular to detector plane) is source w coordinate.
	set sourceCenterInDetectorCS [dict get $sourceFromDetector centre]
	set ufoc [lindex $sourceCenterInDetectorCS 0]
	set vfoc [lindex $sourceCenterInDetectorCS 1]

	if { $mode == "CERA" } {
		# mm -> px
		set ufoc [expr $ufoc*$scale_u - 0.5]
		set vfoc [expr $vfoc*$scale_v - 0.5]
	}

	set SDD [lindex $sourceCenterInDetectorCS 2]
	set SDD [expr abs($SDD)]

	# Mirror volume
	set M [makeMatrix_4x4 1 0 0 0  0 1 0 0  0 0 -1 0  0 0 0 1]

	# Translation matrix: stage -> source:
	set F [makeMatrix_4x3 1 0 0 $xfoc 0 1 0 $yfoc 0 0 1 $zfoc]

	# Rotations:
	set R [basisTransformMatrix $csStage $csDetector]

	# Projection onto detector:
	set D [makeMatrix_3x3 [expr -$SDD*$scale_u] 0 0 0 [expr -$SDD*$scale_v] 0 0 0 $scale_w ]

	# Shift in detector CS: (ufoc and vfoc must be in scaled units)
	set V [makeMatrix_3x3 1 0 $ufoc 0 1 $vfoc 0 0 1 ]

	# Multiply all together:
	set P [::math::linearalgebra::matmul $V [::math::linearalgebra::matmul $D [::math::linearalgebra::matmul $R [::math::linearalgebra::matmul $F $M ]]]]

	# Renormalize
	set p23 [lindex $P 2 3 ]
	if {$p23 != 0} {
		set P [::math::linearalgebra::scale_mat [expr {1.0/$p23}] $P]
	}
	return $P
}

proc Tclmatrix2CERA {mat} {
	return [join $mat \n]
}

proc setupProjectionInternally { projNr } {
	# Sets internal coordinate systems without applying transformations to aRTist scene.
	# For calculation of projection matrices.

	variable ctsimuSettings
	variable ctsimuSamples
	variable moduleNamespace

	setProjNr $projNr

	if {[loadedSuccessfully] == 1} {
		set startAngle    [expr double([dict get $ctsimuSettings startAngle])]
		set stopAngle     [expr double([dict get $ctsimuSettings stopAngle])]
		set nPositions    [dict get $ctsimuSettings nProjections]
		set includeFinalAngle  [dict get $ctsimuSettings includeFinalAngle]
		set scanDirection [dict get $ctsimuSettings scanDirection]

		set csStage [dict get $ctsimuSettings csStage]
		set csSource [dict get $ctsimuSettings csSource]
		set csDetector [dict get $ctsimuSettings csDetector]

		# If the final projection is taken at the stop angle (and not one step before),
		# the number of positions has to be decreased by 1, resulting in one less
		# angular step being performed.
		if {$includeFinalAngle == 1} {
			if {$nPositions > 0} {
				set nPositions [expr $nPositions - 1]
			}
		}

		set angularRange 0.0
		if {$startAngle <= $stopAngle} {
			set angularRange [expr $stopAngle - $startAngle]
		} else {
			fail "The start angle cannot be greater than the stop angle. Scan direction must be specified by the acquisition \'direction\' keyword (CCW or CW)."
			return
		}

		set angularPosition $startAngle 
		if {$nPositions != 0} {
			set angularPosition [expr $startAngle + $projNr*$angularRange / $nPositions]
		}

		# Mathematically negative:
		if {$scanDirection == "CW"} {
			set angularPosition [expr -$angularPosition]
		}

		# Rotate stage to projection angle:
		set axis [dict get $csStage w]
		set csStage [rotateCoordinateSystem $csStage $axis [::Math::DegToRad $angularPosition]]

		dict set ctsimuSettings csStage_current $csStage
		dict set ctsimuSettings csSource_current $csSource
		dict set ctsimuSettings csDetector_current $csDetector
	}

	return $angularPosition
}

proc setupProjection { projNr renderPreview } {
	variable ctsimuSettings
	variable ctsimuSamples
	variable moduleNamespace

	setProjNr $projNr
	${moduleNamespace}::fillCurrentParameters

	if {[loadedSuccessfully] == 1} {
		set angularPosition [setupProjectionInternally $projNr]

		set csStage [dict get $ctsimuSettings csStage_current]
		set csSource [dict get $ctsimuSettings csSource_current]
		set csDetector [dict get $ctsimuSettings csDetector_current]

		# Rotation axis
		set wx [cs_wx $csStage]
		set wy [cs_wy $csStage]
		set wz [cs_wz $csStage]

		# Rotation centre
		set cx [cs_cx $csStage]
		set cy [cs_cy $csStage]
		set cz [cs_cz $csStage]

		# Transform samples:
		set nSamples [llength $ctsimuSamples]

		for {set i 0} {$i < $nSamples} {incr i} {
			set cs [dict get [lindex $ctsimuSamples $i] coordinates]
			set aRTistSampleID [expr $i+1]

			if {[dict get $cs attachedToStage] == 1} {
				# Place object at its original position, in the initial position of the stage:
				aRTist_placeObjectInCoordinateSystem $aRTistSampleID $cs

				# Rotate sample around stage rotation centre:
				::PartList::Invoke $aRTistSampleID SetRefPos $cx $cy $cz
				::PartList::Invoke $aRTistSampleID Rotate world $angularPosition $wx $wy $wz
			}
		}

		if {$renderPreview == 1} {
			Engine::RenderPreview
		}
	}
}

proc stopScan { {withInfo 1} } {
	variable ctsimu_scenario
	$ctsimu_scenario setRunning 0
	if {$withInfo == 1} {
		showInfo "Scan stopped."
	}
}

proc takeProjection { projNr fileNameSuffix } {
	variable ctsimuSettings

	set projectionFolder [dict get $ctsimuSettings projectionFolder]
	set outputBaseName [dict get $ctsimuSettings outputBaseName]

	setupProjection $projNr 1

	set Scale [vtkImageShiftScale New]
	$Scale SetOutputScalarTypeToUnsignedInt
	$Scale ClampOverflowOn

	update
	if {[dict get $ctsimuSettings running] == 0} {return}

	set imglist [::Engine::Go]
	::Image::Show $imglist
	lassign $imglist img

	$Scale SetInput [$img GetImage]

	# Write TIFF or RAW:
	set currFile "$projectionFolder/$outputBaseName"
	append currFile "_$fileNameSuffix"
	if {[dict get $ctsimuSettings fileFormat] == "raw"} {
		append currFile ".raw"
	} else {
		append currFile ".tif"
	}

	puts "Saving $currFile"
	set tmp [Image::aRTistImage %AUTO%]
	if { [catch {
		$Scale Update
		$tmp ShallowCopy [$Scale GetOutput]
		$tmp SetMetaData [$img GetMetaData]
		if {[dict get $ctsimuSettings dataType] == "32bit"} {
			set convtmp [::Image::ConvertToFloat $tmp]
		} else {
			set convtmp [::Image::ConvertTo16bit $tmp]
		}

		if {[dict get $ctsimuSettings fileFormat] == "raw"} {
			::Image::SaveRawFile $convtmp $currFile true . "" 0
		} else {
			::Image::SaveTIFF $convtmp $currFile true . NoCompression
		}

		$tmp Delete
		$convtmp Delete
	} err errdict] } {
		Utils::nohup { $tmp Delete }
		return -options $errdict $err
	}

	#aRTist::SignalProgress
	update

	foreach img $imglist { $img Delete }
	if { [info exists Scale] } { $Scale Delete }

	::xrEngine ClearOutput
	::xrEngine ClearObjects
}

proc createMetadataFile { } {
	variable ctsimu_scenario
	variable moduleNamespace

	set jsonFilename [file tail [dict get $ctsimuSettings jsonFilename]]
	set nProjections [dict get $ctsimuSettings nProjections]
	set projectionFolder [dict get $ctsimuSettings projectionFolder]
	set outputBaseName [dict get $ctsimuSettings outputBaseName]
	set takeDarkField [dict get $ctsimuSettings takeDarkField]
	set nFlatFrames [dict get $ctsimuSettings nFlatFrames]
	set nFlatAvg [dict get $ctsimuSettings nFlatAvg]
	set ffIdeal [dict get $ctsimuSettings ffIdeal]
	set ffRescaleFactor [dict get $ctsimuSettings ffRescaleFactor]

	set detectorX $::Xsetup(DetectorPixelX)
	set detectorY $::Xsetup(DetectorPixelY)
	set pixelSizeX $::Xsetup_private(DGdx)
	set pixelSizeY $::Xsetup_private(DGdy)

	set systemTime [clock seconds]
	set today [clock format $systemTime -format %Y-%m-%d]

	set aRTistVersion [aRTist::GetVersion]
	set moduleInfo [${moduleNamespace}::Info]
	set modulename [dict get $moduleInfo Description]
	set moduleversion [dict get $moduleInfo Version]

	set dataType "uint16"
	if {[dict get $ctsimuSettings dataType] == "32bit"} {
		set dataType "float32"
	}

	set fileExtension ".tif"
	set headerSizeValid 0
	if {[dict get $ctsimuSettings fileFormat] == "raw"} {
		set fileExtension ".raw"
		set headerSizeValid 1
	}
	set projFilename "$outputBaseName"
	append projFilename "_"
	append projFilename [$ctsimu_scenario projectionCounterFormat]
	append projFilename $fileExtension

	set metadataFilename "$projectionFolder/$outputBaseName"
	append metadataFilename "_metadata.json"

	set fileId [open $metadataFilename "w"]

	puts $fileId "\{"
	puts $fileId "	\"file\":"
	puts $fileId "	\{"
	puts $fileId "		\"name\": \"$outputBaseName\","
	puts $fileId "		\"description\": \"\","
	puts $fileId "		"
	puts $fileId "		\"contact\": \"\","
	puts $fileId "		\"date_created\": \"$today\","
	puts $fileId "		\"date_changed\": \"$today\","
	puts $fileId "		\"version\": {\"major\": 1, \"minor\": 0}"
	puts $fileId "	\},"
	puts $fileId "	"
	puts $fileId "	\"output\":"
	puts $fileId "	\{"
	puts $fileId "		\"system\": \"aRTist $aRTistVersion, $modulename $moduleversion\","
	puts $fileId "		\"date_measured\": \"$today\","
	puts $fileId "		\"projections\":"
	puts $fileId "		\{"
	puts $fileId "			\"filename\":   \"$projFilename\","
	puts $fileId "			\"datatype\":   \"$dataType\","
	puts $fileId "			\"byteorder\":  \"little\","

	if {$headerSizeValid == 1} {
		puts $fileId "			\"headersize\": \{\"file\": 0, \"image\": 0\},"
	} else {
		puts $fileId "			\"headersize\": null,"
	}
	

	puts $fileId "			"
	puts $fileId "			\"number\": $nProjections,"
	puts $fileId "			\"dimensions\": \{"
	puts $fileId "				\"x\": \{\"value\": $detectorX, \"unit\": \"px\"\},"
	puts $fileId "				\"y\": \{\"value\": $detectorY, \"unit\": \"px\"\}"
	puts $fileId "			\},"
	puts $fileId "			\"pixelsize\": \{"
	puts $fileId "				\"x\": \{\"value\": $pixelSizeX, \"unit\": \"mm\"\},"
	puts $fileId "				\"y\": \{\"value\": $pixelSizeY, \"unit\": \"mm\"\}"
	puts $fileId "			\},"

	set dfNumber 0
	set dfFrameAverage "null"
	set dfFilename "null"
	if {$takeDarkField == 1} {
		set dfNumber 1
		set dfFrameAverage 1
		set dfFilename "\"$outputBaseName"
		append dfFilename "_dark$fileExtension\""

	}
	puts $fileId "			\"dark_field\": \{"
	puts $fileId "				\"number\": $dfNumber,"
	puts $fileId "				\"frame_average\": $dfFrameAverage,"
	puts $fileId "				\"filename\": $dfFilename,"
	puts $fileId "				\"projections_corrected\": false"
	puts $fileId "			\},"

	set ffFrameAverage "null"
	set ffFilename "null"
	set ffCorrected "false"
	if {$::Xdetector(FFCorrRun) == 1} {
		set ffCorrected "true"
	}
	if {$nFlatFrames > 0} {
		set ffNumber $nFlatFrames
		set ffFrameAverage $nFlatAvg
		set ffFilename "\"$outputBaseName"
		append ffFilename "_flat"
		if {$nFlatFrames > 1} {
			append ffFilename "_"
			append ffFilename [$ctsimu_scenario projectionCounterFormat]
		}
		append ffFilename "$fileExtension\""
	}
	puts $fileId "			\"flat_field\": \{"
	puts $fileId "				\"number\": $nFlatFrames,"
	puts $fileId "				\"frame_average\": $ffFrameAverage,"
	puts $fileId "				\"filename\": $ffFilename,"
	puts $fileId "				\"projections_corrected\": $ffCorrected"
	puts $fileId "			\}"
	puts $fileId "		\},"
	puts $fileId "		\"tomogram\": null,"
	puts $fileId "		\"reconstruction\": null,"
	puts $fileId "		\"acquisitionGeometry\":"
	puts $fileId "		\{"
	puts $fileId "			\"path_to_CTSimU_JSON\": \"$jsonFilename\""
	puts $fileId "		\}"
	puts $fileId "	\}"
	puts $fileId "\}"

	close $fileId

	set ffFilename "$projectionFolder/$outputBaseName"
	append ffFilename "_flat.py"

	if {$nFlatFrames > 0} {
		# Add a FF correction Python script:
		set ffContent "from ctsimu.toolbox import Toolbox\n"
		append ffContent "Toolbox(\"correction\", \""
		append ffContent $outputBaseName
		append ffContent "_metadata.json"
		append ffContent "\", rescaleFactor="
		append ffContent $ffRescaleFactor
		append ffContent ")"

		fileutil::writeFile -encoding utf-8 $ffFilename $ffContent
	}
}

proc Tclmatrix2json {mat} {
	# From the advanCT module.
	# assume that mat is a nested list of lists
	# of numbers
	set jmat [json new array]
	foreach line $mat {
		set jline [json new array]
		foreach el $line {
			json set jline end+1 $el
		}
		json set jmat end+1 $jline
	}

	return $jmat

}

proc createCERA_RDabcuv { } {
	variable ctsimuSettings
	variable csWorld

	set csSource [dict get $ctsimuSettings csSource]
	set csStage [dict get $ctsimuSettings csStage]
	set csDetector [dict get $ctsimuSettings csDetector]

	set nu $::Xsetup(DetectorPixelX)
	set nv $::Xsetup(DetectorPixelY)
	set psu $::Xsetup_private(DGdx)
	set psv $::Xsetup_private(DGdy)

	set startAngle [dict get $ctsimuSettings startAngle]

	# CERA's detector CS has its origin in the lower left corner instead of the centre.
	# Let's move there:
	set D  [dict get $csDetector centre]
	set uD [dict get $csDetector u]
	set vD [dict get $csDetector v]
	set halfWidth  [expr $psu*$nu / 2.0]
	set halfHeight [expr $psv*$nv / 2.0]

	set D [vec3Diff $D [vec3Mul $uD $halfWidth]]
	set D [vec3Add  $D [vec3Mul $vD $halfHeight]]

	dict set csDetector centre $D

	# The v axis points up instead of down:
	set csDetector [rotateCoordinateSystem $csDetector $uD 3.141592653589793]

	set S [dict get $csSource centre]
	set O [dict get $csStage centre]
	set D [dict get $csDetector centre]

	# Construct the CERA world coordinate system:
	# z axis points in v direction of our detector CS:
	set cera_z [dict get $csDetector v]
	set z0 [lindex $cera_z 0]
	set z1 [lindex $cera_z 1]
	set z2 [lindex $cera_z 2]

	set O0 [lindex $O 0]
	set O1 [lindex $O 1]
	set O2 [lindex $O 2]

	set S0 [lindex $S 0]
	set S1 [lindex $S 1]
	set S2 [lindex $S 2]

	set w0 [lindex [dict get $csStage w] 0]
	set w1 [lindex [dict get $csStage w] 1]
	set w2 [lindex [dict get $csStage w] 2]

	# x axis points from source to stage (inverted), and perpendicular to cera_z (det v):
	set t [expr -($z0*($O0-$S0) + $z1*($O1-$S1) + $z2*($O2-$S2))/($z0*$w0 + $z1*$w1 + $z2*$w2)]
	set d [vec3Dist $S $O]
	set SOD [expr sqrt($d*$d - $t*$t)]

	if {$SOD > 0} {
		set x0 [expr -($O0 - $S0 + $t*$w0)/$SOD]
		set x1 [expr -($O1 - $S1 + $t*$w1)/$SOD]
		set x2 [expr -($O2 - $S2 + $t*$w2)/$SOD]
	} else {
		set x0 -1
		set x1 0
		set x2 0
	}

	set cera_x [vec3Unit [list $x0 $x1 $x2]]

	set csCERA [makeCoordinateSystemFromVectors $S $cera_x $cera_z 0]

	set stageInCERA [changeReferenceFrame $csStage $csWorld $csCERA]
	set detectorInCERA [changeReferenceFrame $csDetector $csWorld $csCERA]
	set sourceInCERA [changeReferenceFrame $csSource $csWorld $csCERA]

	set S [dict get $sourceInCERA centre]
	set O [dict get $stageInCERA centre]
	set D [dict get $detectorInCERA centre]		

	# Source:
	set xS [lindex $S 0]
	set yS [lindex $S 1]
	set zS [lindex $S 2]

	# Stage:
	set xO [lindex $O 0]
	set yO [lindex $O 1]
	set zO [lindex $O 2]
	set uO [vec3Unit [dict get $stageInCERA u]]
	set vO [vec3Unit [dict get $stageInCERA v]]
	set wO [vec3Unit [dict get $stageInCERA w]]
	set wOx [lindex $wO 0]
	set wOy [lindex $wO 1]
	set wOz [lindex $wO 2]

	# Detector:
	set xD [lindex $D 0]
	set yD [lindex $D 1]
	set zD [lindex $D 2]
	set uD [vec3Unit [dict get $detectorInCERA u]]
	set vD [vec3Unit [dict get $detectorInCERA v]]
	set wD [vec3Unit [dict get $detectorInCERA w]]
	# Detector normal:
	set nx [lindex $wD 0]
	set ny [lindex $wD 1]
	set nz [lindex $wD 2]

	# Intersection of CERA's x axis with the stage rotation axis = ceraVolumeMidpoint (new center of stage)
	set xaxis [list 1 0 0]
	set ceraVolumeMidpoint [vec3Add $S [vec3Mul $xaxis [expr -$SOD]]]

	puts "CERA volume midpoint:"
	printVector $ceraVolumeMidpoint

	set worldVolumeMidpoint [pointChangeReferenceFrame $ceraVolumeMidpoint $csCERA $csWorld ]

	puts "World volume midpoint:"
	printVector $worldVolumeMidpoint

	set ceraVolumeRelativeMidpoint [vec3Diff $O $ceraVolumeMidpoint]
	set midpointX [lindex $ceraVolumeRelativeMidpoint 0]
	set midpointY [lindex $ceraVolumeRelativeMidpoint 1]
	set midpointZ [lindex $ceraVolumeRelativeMidpoint 2]

	set c [lindex $uD 0];   # x component of detector u vector is c-tilt
	set a $wOx;             # x component of stage w vector is a-tilt
	set b $wOy;             # y component of stage w vector is b-tilt

	# Intersection of x axis with detector (in px):
	set efoc_x [lindex $xaxis 0]
	set efoc_y [lindex $xaxis 1]
	set efoc_z [lindex $xaxis 2]

	set E [expr $nx*$xD + $ny*$yD + $nz*$zD]
	set dv [expr ($nx*$efoc_x + $ny*$efoc_y + $nz*$efoc_z)]
	if {$dv > 0} {
		set SDDcera [expr ($E - $xS*$nx - $yS*$ny - $zS*$nz)/$dv]
	} else {
		set SDDcera 1
	}
	set SDDcera [expr abs($SDDcera)]
	set SODcera [vec3Dist $S $ceraVolumeMidpoint]

	set SOD $SODcera
	set SDD $SDDcera
	if {$SDD != 0} {
		set voxelsizeU [expr {$psu * $SOD / $SDD}]
		set voxelsizeV [expr {$psv * $SOD / $SDD}]
	} else {
		set voxelsizeU 1
		set voxelsizeV 1
	}

	set detectorIntersectionPoint [vec3Mul $xaxis [expr -$SDDcera]]
	set stageOnDetector [vec3Diff $detectorIntersectionPoint $D]

	set ufoc [vec3Dot $stageOnDetector $uD]
	set vfoc [vec3Dot $stageOnDetector $vD]
	set wfoc [vec3Dot $stageOnDetector $wD]

	if {$psu > 0} {
		set ufoc_px [expr $ufoc/$psu]
	}
	
	if {$psv > 0} {
		set vfoc_px [expr $vfoc/$psv]
	}

	set offu [expr $ufoc_px - 0.5]
	set offv [expr $vfoc_px - 0.5]

	# The start angle can be calculated from theta in the first projection matrix.
#		set P0 [projectionMatrix $csSource $csStage $csDetector "CERA" $psu $psv $nu $nv]
#		set c22 [lindex [lindex $P0 2] 2]
#		set c22sod [expr $c22*$SOD]
#
#		set phi 0
#		if { $c22sod <= 1.0 && $c22sod >= -1.0 } {
#			set phi [expr asin($c22sod)]
#		}
#
#		set theta 0
#		set c20 [lindex [lindex $P0 2] 0]
#		if { $c20 != 0 } {
#			set c21 [lindex [lindex $P0 2] 1]
#			set thetaTan [expr $c21 / $c20]
#			set theta [expr atan($thetaTan)]
#		} else {
#			if { $c21 < 0 } {
#				set theta [expr -3.1415926535897932384626433832795028841971/2.0]
#			} else {
#				set theta [expr 3.1415926535897932384626433832795028841971/2.0]
#			}
#		}

	#set vOonD [vec3Add [vec3Mul $uD [vec3Dot $vO $uD]]  [vec3Mul $vD [vec3Dot $vO $vD]]]
	set cera_x [list 1 0 0]
	set cera_y [list 0 1 0]
	set vInXYplane [vec3Add [vec3Mul $cera_x [vec3Dot $vO $cera_x]]  [vec3Mul $cera_y [vec3Dot $vO $cera_y]]]
	set rot [vec3Angle $vInXYplane $cera_y]
	
	# Add this start angle to the user-defined start angle:
	set startAngle [expr $startAngle + [expr 180 - $rot*180.0/3.1415926535897932384626433832795028841971]]

	dict set ctsimuSettings cera_R $SOD
	dict set ctsimuSettings cera_D $SDD
	dict set ctsimuSettings cera_ODD [expr $SDD-$SOD]
	dict set ctsimuSettings cera_a $a
	dict set ctsimuSettings cera_b $b
	dict set ctsimuSettings cera_c $c
	dict set ctsimuSettings cera_u0 $offu
	dict set ctsimuSettings cera_v0 $offv
	dict set ctsimuSettings cera_startAngle $startAngle
	dict set ctsimuSettings cera_volumeMidpointX $midpointX
	dict set ctsimuSettings cera_volumeMidpointY $midpointY
	dict set ctsimuSettings cera_volumeMidpointZ $midpointZ
	dict set ctsimuSettings cera_voxelSizeU $voxelsizeU
	dict set ctsimuSettings cera_voxelSizeV $voxelsizeV
	dict set ctsimuSettings cera_stageCenterInWorld $worldVolumeMidpoint
}

proc saveCERAconfigFile { projectionMatrices } {
	variable ctsimu_scenario
	variable csWorld

	set reconFolder [dict get $ctsimuSettings reconFolder]
	set outputBaseName [dict get $ctsimuSettings outputBaseName]
	set ffProjShortPath [dict get $ctsimuSettings ffProjectionShortPath]

	set projTableFilename $outputBaseName
	append projTableFilename "_recon_cera_projtable.txt"

	set configFilename $outputBaseName
	append configFilename "_recon_cera.config"

	set nProjections [llength $projectionMatrices]
	set configtemplate {#CERACONFIG

[Projections]
NumChannelsPerRow = $nu
NumRows = $nv
PixelSizeU = $psu
PixelSizeV = $psv
Rotation = None
FlipU = false
FlipV = true
Padding = 0
BigEndian = false
CropBorderRight = 0
CropBorderLeft = 0
CropBorderTop = 0
CropBorderBottom = 0
BinningFactor = None
SkipProjectionInterval = 1
ProjectionDataDomain = Intensity
RawHeaderSize = 0

[Volume]
SizeX = $nSizeX
SizeY = $nSizeY
SizeZ = $nSizeZ
# Midpoints are only necessary for reconstructions
# without projection matrices.
MidpointX = 0 # $midpointX
MidpointY = 0 # $midpointY
MidpointZ = 0 # $midpointZ
VoxelSizeX = $voxelsizeU
VoxelSizeY = $voxelsizeU
VoxelSizeZ = $voxelsizeV
Datatype = float

[CustomKeys]
NumProjections = $N	
ProjectionFileType = $ftype
VolumeOutputPath = $CERAoutfile
ProjectionStartNum = 0
ProjectionFilenameMask = ../$ffProjShortPath/$CERAfnmask

[CustomKeys.ProjectionMatrices]
SourceObjectDistance = $SOD
SourceImageDistance = $SDD
DetectorOffsetU = $offu
DetectorOffsetV = $offv
StartAngle = $startAngle
ScanAngle = $totalAngle
AquisitionDirection = $scanDirection
a = $a
b = $b
c = $c
ProjectionMatrixFilename = $projectionMatrixFilename

[Backprojection]
ClearOutOfRegionVoxels = false
InterpolationMode = bilinear
FloatingPointPrecision = half
Enabled = true

[Filtering]
Enabled = true
Kernel = shepp

[I0Log]
Enabled = true
Epsilon = 1.0E-5
GlobalI0Value = $globalI0
}

	set nu $::Xsetup(DetectorPixelX)
	set nv $::Xsetup(DetectorPixelY)
	set psu $::Xsetup_private(DGdx)
	set psv $::Xsetup_private(DGdy)

	set globalI0 [dict get $ctsimuSettings GVmax]

	set scanDir [dict get $ctsimuSettings scanDirection]
	# Flip: we assume object scan direction, CERA assumes gantry scan direction.
	if { $scanDir == "CCW" } {
		set scanDirection "CW"
	} else {
		set scanDirection "CCW"
	}

	# Cropping doesn't work this way and might not even be necessary?
	# Going back to full volume for the moment...
	#set nSize [lmap x [vec3Div $size $voxelsize] {expr {int(ceil($x))}}]
	#lassign $nSize nSizeX nSizeY nSizeZ
	set nSizeX $nu
	set nSizeY $nu
	set nSizeZ $nv
	
	set N [dict get $ctsimuSettings nProjections]

	set projFilename "$outputBaseName"
	append projFilename "_"
	append projFilename [$ctsimu_scenario projectionCounterFormat]
	if {[dict get $ctsimuSettings fileFormat] == "raw"} {
		set ftype "raw_uint16"
		append projFilename ".raw"
	} else {
		set ftype "tiff"
		append projFilename ".tif"
	}

	set CERAoutfile "${outputBaseName}_recon_cera.raw"
	set CERAfnmask $projFilename

	set CERAvgifile "$reconFolder/${outputBaseName}_recon_cera.vgi"
	set CERAvginame "${outputBaseName}_recon_cera"
	set vsu [dict get $ctsimuSettings cera_voxelSizeU]
	set vsv [dict get $ctsimuSettings cera_voxelSizeV]
	saveVGI $CERAvginame $CERAvgifile $CERAoutfile 0 $vsu $vsv

	set SOD  [dict get $ctsimuSettings cera_R]
	set SDD  [dict get $ctsimuSettings cera_D]
	set a    [dict get $ctsimuSettings cera_a]
	set b    [dict get $ctsimuSettings cera_b]
	set c    [dict get $ctsimuSettings cera_c]
	set offu [dict get $ctsimuSettings cera_u0]
	set offv [dict get $ctsimuSettings cera_v0]
	set midpointX  [dict get $ctsimuSettings cera_volumeMidpointX]
	set midpointY  [dict get $ctsimuSettings cera_volumeMidpointY]
	set midpointZ  [dict get $ctsimuSettings cera_volumeMidpointZ]
	set voxelsizeU [dict get $ctsimuSettings cera_voxelSizeU]
	set voxelsizeV [dict get $ctsimuSettings cera_voxelSizeV]

	set startAngle [dict get $ctsimuSettings startAngle]
	set stopAngle  [dict get $ctsimuSettings stopAngle]
	set totalAngle [expr $stopAngle - $startAngle]

	# In CERA, we compensate in-matrix rotations by providing a different start angle:
	set startAngle [dict get $ctsimuSettings cera_startAngle]

	# Projection Matrices
	set projectionMatrixFilename $projTableFilename

	set configFilePath "$reconFolder/$configFilename"
	fileutil::writeFile $configFilePath [subst -nocommands $configtemplate]

	
	set projTablePath "$reconFolder/$projTableFilename"
	set projt [open $projTablePath w]
	puts $projt "projtable.txt version 3"
	#to be changed to date
	puts $projt "[clock format [clock scan now] -format "%a %b %d %H:%M:%S %Y"]\n" 
	# or: is this a fixed date? "Wed Dec 07 09:58:01 2005\n" 
	puts $projt "# format: angle / entries of projection matrices"
	puts $projt $nProjections
	
	set step 0
	foreach matrix $projectionMatrices {
		# concat all numbers into one
		set matrixCERA [Tclmatrix2CERA $matrix]

		# Cera expects @Stepnumber to start at 1
		set ceraStep [expr $step+1]
		
		puts $projt "\@$ceraStep\n0.0 0.0"
		puts $projt "$matrixCERA\n"
		incr step
	}
	
	close $projt

}

proc saveCLFDKconfigFile { projectionFilenames projectionMatrices csStage } {
	variable ctsimuSettings
	variable csWorld

	set reconFolder [dict get $ctsimuSettings reconFolder]
	set outputBaseName [dict get $ctsimuSettings outputBaseName]

	set batFilename "$reconFolder/$outputBaseName"
	append batFilename "_recon_clFDK.bat"

	set configFilename "$reconFolder/$outputBaseName"
	append configFilename "_recon_clFDK.json"

	set ffProjShortPath [dict get $ctsimuSettings ffProjectionShortPath]

	set batFileContent "CHCP 65001\n"
	set batFileContent "clfdk $outputBaseName"
	append batFileContent "_recon_clFDK.json $outputBaseName"
	append batFileContent "_recon_clFDK iformat json"

	#set xoff [expr -[dict get $ctsimuSettings cera_volumeMidpointX]]
	#set yoff [expr -[dict get $ctsimuSettings cera_volumeMidpointY]]
	#set zoff [expr -[dict get $ctsimuSettings cera_volumeMidpointZ]]

	#append batFileContent " xoff $xoff yoff $yoff zoff $zoff"

	fileutil::writeFile -encoding utf-8 $batFilename $batFileContent

	set reconVolumeFilename "$outputBaseName"
	append reconVolumeFilename "_recon_clFDK.img"

	set CLFDKvgifile "$reconFolder/${outputBaseName}_recon_clFDK.vgi"
	set CLFDKvginame "${outputBaseName}_recon_clFDK"

	# match voxel size with CERA
	set vsu [dict get $ctsimuSettings cera_voxelSizeU]
	set vsv [dict get $ctsimuSettings cera_voxelSizeV]
	saveVGI $CLFDKvginame $CLFDKvgifile $reconVolumeFilename 0 $vsu $vsv

	set fileType "TIFF"
	if {[dict get $ctsimuSettings fileFormat] == "raw"} {
		set fileType "RAW"
	}

	set dataType "UInt16"
	if {[dict get $ctsimuSettings dataType] == "32bit"} {
		set dataType "Float32"
	}

	set nProjections [llength $projectionFilenames]

	set startAngle [dict get $ctsimuSettings startAngle]
	set stopAngle  [dict get $ctsimuSettings stopAngle]
	set totalAngle [expr $stopAngle - $startAngle]

	set geomjson {
		{
			"version": {"major":1, "minor":0},
			"volumeName": "",
			"projections": {
				"numProjections": 0,
				"intensityDomain": true,
				"images": {
					"directory": "",
					"dataType": "",
					"fileType": "",
					"files": []},
				"matrices": []
				}, 
			"geometry": {
				"totalAngle": null,
				"skipAngle": 0,
				"detectorPixel": [],
				"detectorSize": [],
				"mirrorDetectorAxis": "",
				"distanceSourceObject": null,
				"distanceObjectDetector": null,
				"objectBoundingBox": []
				},
			 "corrections":{
				"brightImages":{
				  "directory": "",
				  "dataType":"",
				  "fileType":"",
				  "files":[]
				},

				"darkImage":{
				  "file":"",
				  "dataType":"",
				  "fileType":""
				},

				"badPixelMask":{
				  "file":"",
				  "dataType":"",
				  "fileType":""
				},

				"intensities":[]
			  }
		}
	}

	json set geomjson volumeName [json new string $reconVolumeFilename]
	json set geomjson projections numProjections $nProjections

	json set geomjson projections images directory [json new string "."]
	json set geomjson projections images fileType [json new string $fileType]
	json set geomjson projections images dataType [json new string $dataType]

	foreach projectionFile $projectionFilenames {
		json set geomjson projections images files end+1 [json new string "../$ffProjShortPath/$projectionFile"]
	}

	foreach P $projectionMatrices {
		json set geomjson projections matrices end+1 [Tclmatrix2json $P]
	}

	set gvmax [dict get $ctsimuSettings GVmax]
	foreach projectionFile $projectionFilenames {
		json set geomjson corrections intensities end+1 [json new number $gvmax]
	}

	json set geomjson geometry totalAngle $totalAngle

	json set geomjson geometry detectorSize end+1 $::Xsetup_private(DGSx)
	json set geomjson geometry detectorSize end+1 $::Xsetup_private(DGSy)

	json set geomjson geometry detectorPixel end+1 $::Xsetup(DetectorPixelX)
	json set geomjson geometry detectorPixel end+1 $::Xsetup(DetectorPixelY)

	set bbSizeXY [expr $::Xsetup(DetectorPixelX) * $vsu]
	set bbSizeZ  [expr $::Xsetup(DetectorPixelY) * $vsv]

	# Scale the unit cube to match the bounding box:
	set S [makeMatrix_4x4 $bbSizeXY 0 0 0  0 $bbSizeXY 0 0  0 0 $bbSizeZ 0  0 0 0 1]

	# Rotate the bounding box to the stage CS:
	set R [basisTransformMatrix $csWorld $csStage 1]

	set RS [::math::linearalgebra::matmul $R $S]
	json set geomjson geometry objectBoundingBox [Tclmatrix2json $RS]

	json set geomjson geometry distanceSourceObject [dict get $ctsimuSettings cera_R]
	json set geomjson geometry distanceObjectDetector [dict get $ctsimuSettings cera_ODD]

	fileutil::writeFile -encoding utf-8 $configFilename [json pretty $geomjson]
}

proc saveVGI { name filename volumeFilename zMirror voxelsizeU voxelsizeV } {
	variable ctsimuSettings

	set vgiTemplate {\{volume1\}
[representation]
size = $nSizeX $nSizeY $nSizeZ
mirror = 0 0 0 0 
resamplemode = not activated
indexedcolormode = false
datatype = float
datarange = -1 1
bitsperelement = 32
[file1]
RegionOfInterestStart = 0 0 0 
RegionOfInterestEnd = $roiEndX $roiEndY $roiEndZ
Endian = little
SkipHeader = 0
FileFormat = raw
Size = $nSizeX $nSizeY $nSizeZ
Mirror = 0 0 $zMirror 
Name = $volumeFilename
Datatype = float
datarange = -1 1
BitsPerElement = 32
[description]
text = $name
\{volumeprimitive12\}
[wallthicknessinfo]
detected = false
thickness = -1
numberintervals = 1
tolerance = -1
detectmode = 3D
backgroundmax = 0
materialmin = -1
calibrated = false
processed = false
[geometry]
clipplane1 = -1 0 0 $roiEndZ
clipbox =  0 0 0 $roiEndX $roiEndY $roiEndZ
position = 0 0 0 
status = visible
relativeposition = 0 0 0 
resolution = $voxelsizeU $voxelsizeU $voxelsizeV
center = 0.0 0.0 0.0
scale = 1 1 1 
rotate = 1 0 0 0 1 0 0 0 1 
unit = mm
[volume]
volume = volume1
[description]
text = $name
[segment1]
opacityvalue = -0.00018309057 6.1035155e-05 1.999939 
status = activated
redvalue = 255 255 
bluex = 1.4901161e-08 250.00001 
greenvalue = 255 255 
description = Segment 1
opacityx = 1.4901161e-08 70.999998 250.00001 
redx = 1.4901161e-08 250.00001 
greenx = 1.4901161e-08 250.00001 
bluevalue = 255 255 
[processinfo]
minimumdefectsize = 0
maximumdefectsize = 0
logarithmicsizemapping = false
[defectinfo]
detected = false
numberruns = 1
centerartifactsignored = false
defectmaxsize2d = 0
defectmaxsize3d = 0
background = 0
detectmode = 3D
beamartifactsignored = false
qualitymapused = false
material = 0
quality = 1
calibrated = false
circularartifactsignored = false
neighborhoodcheck = false
defectminsize2d = 0
defectminsize3d = 0
processed = false
algorithm = default
[measurementinfo]
formheaderpreferedorientation = 1 0 0 0 1 0 0 0 1 
formheaderdate = 2007-06-24
{{default}}
[version]
release = VGStudioMax 1.2.1 (build 357)
}
	set nu $::Xsetup(DetectorPixelX)
	set nv $::Xsetup(DetectorPixelY)
	set psu $::Xsetup_private(DGdx)
	set psv $::Xsetup_private(DGdy)

	set nSizeX $nu
	set nSizeY $nu
	set nSizeZ $nv

	set roiEndX [expr $nSizeX-1]
	set roiEndY [expr $nSizeY-1]
	set roiEndZ [expr $nSizeZ-1]

	fileutil::writeFile $filename [subst -nocommands $vgiTemplate]
}

proc preparePostprocessingConfigs { } {
	# Flat field correction Python file, config files for various reconstruction softwares.
	variable ctsimu_scenario

	set projCtrFmt [$ctsimu_scenario projectionCounterFormat]

	if {[loadedSuccessfully] == 1} {
		if {[dict exists $ctsimuSettings running] == 0} {
			dict set ctsimuSettings running 0
		}

		if {[dict get $ctsimuSettings running] == 0} {
			# Make projection folder and metadata file:
			set projectionFolder [dict get $ctsimuSettings projectionFolder]

			file mkdir $projectionFolder
			createMetadataFile

			# Recon config files:
			set doCERA  [dict get $ctsimuSettings cfgFileCERA]
			set doCLFDK [dict get $ctsimuSettings cfgFileCLFDK]

			set doRecon 0
			if { [dict get $ctsimuSettings startAngle] != [dict get $ctsimuSettings stopAngle] } {
				if { [dict get $ctsimuSettings nProjections] > 1 } {
					if { $doCERA==1 || $doCLFDK==1} {
						set doRecon 1
					}
				}
			}

			if { $doRecon==1 } {
				dict set ctsimuSettings running 1

				set nProjections [dict get $ctsimuSettings nProjections]
				set reconFolder [dict get $ctsimuSettings reconFolder]
				set outputBaseName [dict get $ctsimuSettings outputBaseName]

				file mkdir $reconFolder			

				set projectionMatricesCLFDK {}
				set projectionMatricesCERA {}
				set projectionFilenames {}

				# Detector size (pixels) and pixel size:
				set nu $::Xsetup(DetectorPixelX)
				set nv $::Xsetup(DetectorPixelY)
				set psu $::Xsetup_private(DGdx)
				set psv $::Xsetup_private(DGdy)

				set csStage_initial [dict get $ctsimuSettings csStage]
				set csSource_initial [dict get $ctsimuSettings csSource]
				set csDetector_initial [dict get $ctsimuSettings csDetector]
			
				if {$nProjections > 0} {
					aRTist::Info { "Calculating projection matrices..."}
			
					for {set projNr 0} {$projNr < $nProjections} {incr projNr} {
						set pnr [expr $projNr+1]
						showInfo "Calculating projection matrix $pnr/$nProjections..."
						setupProjectionInternally $projNr
	
						# Get current coordinate systems (positions + orientations)
						set csStage_current [dict get $ctsimuSettings csStage_current]
						set csSource_current [dict get $ctsimuSettings csSource_current]
						set csDetector_current [dict get $ctsimuSettings csDetector_current]
		
						if { $doCLFDK==1} {
							set P_clFDK [projectionMatrix $csSource_current $csStage_current $csDetector_current "clFDK"]
							lappend projectionMatricesCLFDK $P_clFDK
						}
						if { $doCERA==1} {
							set P_CERA [projectionMatrix $csSource_current $csStage_current $csDetector_current "CERA" $psu $psv $nu $nv]
							lappend projectionMatricesCERA $P_CERA
						}
			
						# Projection name:
						set fileNameSuffix [format $projCtrFmt $projNr]
						set currFile "$outputBaseName"
						append currFile "_$fileNameSuffix"
						if {[dict get $ctsimuSettings fileFormat] == "raw"} {
							append currFile ".raw"
						} else {
							append currFile ".tif"
						}
						lappend projectionFilenames $currFile
			
						update
						if {[dict get $ctsimuSettings running] == 0} {return 0}
					}
				}
			
				if { $doCLFDK==1 } {
					saveCLFDKconfigFile $projectionFilenames $projectionMatricesCLFDK $csStage_initial
				}

				if { $doCERA==1 } {
					saveCERAconfigFile $projectionMatricesCERA
				}
			}

			stopScan 0

			return 1
		}
	}
}

proc startScan { } {
	variable ctsimu_scenario

	set projCtrFmt [$ctsimu_scenario projectionCounterFormat]

	if {[loadedSuccessfully] == 1} {
		if {[dict exists $ctsimuSettings running] == 0} {
			dict set ctsimuSettings running 0
		}

		if {[dict get $ctsimuSettings running] == 0} {
			# preparation function sets 'running' to 1 (so it can be stopped by the user as well)
			set ppDone [preparePostprocessingConfigs]

			if {$ppDone == 1} {
				dict set ctsimuSettings running 1

				set nProjections [dict get $ctsimuSettings nProjections]
				set projectionFolder [dict get $ctsimuSettings projectionFolder]
				set outputBaseName [dict get $ctsimuSettings outputBaseName]
				set takeDarkField [dict get $ctsimuSettings takeDarkField]
				set nFlatFrames [dict get $ctsimuSettings nFlatFrames]
				set nFlatAvg [dict get $ctsimuSettings nFlatAvg]
				set ffIdeal [dict get $ctsimuSettings ffIdeal]
				set startProjNr [dict get $ctsimuSettings startProjNr]

				file mkdir $projectionFolder

				SceneView::SetInteractive 1
				set imglist {}

				
				if {$takeDarkField == 1} {
					aRTist::Info { "Taking ideal dark field."}
					showInfo "Taking ideal dark field."

					set savedXrayCurrent $::Xsource(Exposure)
					set savedNoiseFactorOn $::Xdetector(NoiseFactorOn)
					set savedNoiseFactor   $::Xdetector(NoiseFactor)
					set savedNFrames       $::Xdetector(NrOfFrames)
					set savedScatter       $::Xscattering(Mode)
					
					# Take ideal dark image at 0 current and 0 noise:
					set ::Xsource(Exposure) 0
					set ::Xdetector(NoiseFactorOn) 1
					set ::Xdetector(NoiseFactor) 0
					set ::Xdetector(NrOfFrames) 1
					set ::Xscattering(Mode) off
					
					takeProjection 0 "dark"

					set ::Xsource(Exposure) $savedXrayCurrent
					set ::Xdetector(NoiseFactorOn) $savedNoiseFactorOn
					set ::Xdetector(NoiseFactor) $savedNoiseFactor
					set ::Xdetector(NrOfFrames) $savedNFrames
					set ::Xscattering(Mode) $savedScatter
				}

				if {$nFlatFrames > 0} {
					aRTist::Info { "Taking flat field."}

					::PartList::SelectAll
					::PartList::SetVisibility 0
					::PartList::UnselectAll

					if { $ffIdeal == 1 } {
						set savedNoiseFactorOn $::Xdetector(NoiseFactorOn)
						set savedNoiseFactor   $::Xdetector(NoiseFactor)
						set savedNFrames       $::Xdetector(NrOfFrames)

						# Take ideal flat image at 0 noise:
						set ::Xdetector(NoiseFactorOn) 1
						set ::Xdetector(NoiseFactor) 0
						set ::Xdetector(NrOfFrames) 1

						if {$nFlatFrames > 1} {
							# Save all frames as individual images
							for {set flatImgNr 0} {$flatImgNr < $nFlatFrames} {incr flatImgNr} {
								set fnr [expr $flatImgNr+1]
								showInfo "Taking flat field $fnr/$nFlatFrames..."
								aRTist::Info { "-- Flat Image $flatImgNr" }
								set flatFileNameSuffix "flat_[format $projCtrFmt $flatImgNr]"
								takeProjection 0 $flatFileNameSuffix

								if {[dict get $ctsimuSettings running] == 0} {break}
							}
						} elseif {$nFlatFrames == 1} {
							showInfo "Taking flat field..."
							takeProjection 0 "flat"
						} else {
							stopScan
							::PartList::SelectAll
							::PartList::SetVisibility 1
							::PartList::UnselectAll	
							fail "Invalid number of flat field images."
						}

						set ::Xdetector(NoiseFactorOn) $savedNoiseFactorOn
						set ::Xdetector(NoiseFactor) $savedNoiseFactor
						set ::Xdetector(NrOfFrames) $savedNFrames
					} else {
						if {$nFlatAvg > 0} {
							set savedNFrames $::Xdetector(NrOfFrames)
							set ::Xdetector(NrOfFrames) $nFlatAvg

							if {$nFlatFrames > 1} {
								# Save all frames as individual images
								for {set flatImgNr 0} {$flatImgNr < $nFlatFrames} {incr flatImgNr} {
									set fnr [expr $flatImgNr+1]
									showInfo "Taking flat field $fnr/$nFlatFrames..."
									aRTist::Info { "-- Flat Image $flatImgNr" }
									set flatFileNameSuffix "flat_[format $projCtrFmt $flatImgNr]"
									takeProjection 0 $flatFileNameSuffix

									if {[dict get $ctsimuSettings running] == 0} {break}
								}
							} elseif {$nFlatFrames == 1} {
								showInfo "Taking flat field..."
								takeProjection 0 "flat"
							} else {
								stopScan
								::PartList::SelectAll
								::PartList::SetVisibility 1
								::PartList::UnselectAll	
								fail "Invalid number of flat field images."
							}

							set ::Xdetector(NrOfFrames) $savedNFrames
						} else {
							stopScan
							::PartList::SelectAll
							::PartList::SetVisibility 1
							::PartList::UnselectAll	
							fail "Number of flat field averages must be greater than 0."
						}
					}

					::PartList::SelectAll
					::PartList::SetVisibility 1
					::PartList::UnselectAll						
				}

				if {$nProjections > 0} {
					aRTist::Info { "Taking $nProjections projections."}

					#aRTist::InitProgress
					#aRTist::ProgressQuantum $nProjections

					for {set projNr $startProjNr} {$projNr < $nProjections} {incr projNr} {
						set pnr [expr $projNr]
						set prcnt [expr round((100.0*($projNr+1))/$nProjections)]
						showInfo "Taking projection $pnr/$nProjections... ($prcnt%)"
						aRTist::Info { "-- Projection $projNr" }
						set fileNameSuffix [format $projCtrFmt $projNr]
						takeProjection $projNr $fileNameSuffix

						if {[dict get $ctsimuSettings running] == 0} {break}
					}

					#aRTist::ProgressFinished
				}
				stopScan
				showInfo "Ready."
			}
		}
	}
}