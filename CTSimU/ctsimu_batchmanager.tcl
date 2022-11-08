package require TclOO
package require csv

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_batchjob.tcl]

# Class for a batch job.

namespace eval ::ctsimu {
	::oo::class create batchmanager {
		variable _running
		variable _properties
		variable _batchjobs
		variable _batchlist; # GUI batch list

		constructor { } {
			my set standard_output_fileformat  "tiff"
			my set standard_output_datatype    "uint16"

			set _batchjobs [list ]
		}

		destructor {
			foreach bj $_batchjobs {
				$bj destroy
			}
		}
		
		method reset { } {
			foreach bj $_batchjobs {
				$bj destroy
			}
			set _batchjobs [list ]
		}

		# Getters
		# -------------------------
		method get { property } {
			# Returns the value for a given `property`.
			return [dict get $_properties $property]
		}

		method is_running { } {
			return $_running
		}

		
		# Setters
		# -------------------------
		method set { property value } {
			# Set a settings value in the settings dict
			dict set _properties $property $value
		}

		method set_batch_list { bl } {
			set _batchlist $bl
		}

		method n_jobs { } {
			return [llength $_batchjobs]
		}

		method sync_batchlist_into_manager { } {
			variable _batchlist
			
			if { ![::ctsimu::aRTist_available] } {
				return
			}
			
			# Apply values from GUI list to batch jobs stored in this manager.
			# Takes care of user's changes to values.
			set i 0

			foreach index [$_batchlist childkeys root] {
				if { $i >= [my n_jobs] } {
					# There are more jobs in the GUI list than in the
					# manager's list. Add another job:
					set bj [::ctsimu::batchjob new]
					lappend _batchjobs $bj
				} else {
					# We can update an existing batch job
					# in the manager's list:
					set bj [lindex $_batchjobs $i]
				}				
				
				$bj set id              [$_batchlist cellcget $index,Job  -text]
				$bj set json_file       [$_batchlist cellcget $index,JSONFile  -text]
				$bj set_format          [$_batchlist cellcget $index,OutputFormat  -text]
				$bj set output_folder   [$_batchlist cellcget $index,OutputFolder  -text]
				$bj set output_basename [$_batchlist cellcget $index,ProjectionBaseName  -text]
				$bj set runs            [$_batchlist cellcget $index,Runs  -text]
				$bj set start_run       [$_batchlist cellcget $index,StartRun  -text]
				$bj set start_proj_nr   [$_batchlist cellcget $index,StartProjNr  -text]
				$bj set status          [$_batchlist cellcget $index,Status  -text]
				
				incr i
			}
			
			# Remove any remaining jobs that are not in the GUI list:
			if { $i < [my n_jobs] } {
				for {set j $i} {$j < [my n_jobs]} {incr j} {
					[lindex $_batchjobs $j] destroy
				}
				
				set _batchjobs [lrange $_batchjobs 0 [expr $i-1]]
			}
		}

		method add_batch_job { bj } {
			lappend _batchjobs $bj
			my add_batch_job_to_GUIlist $bj
		}

		method add_batch_job_to_GUIlist { bj } {
			if { [::ctsimu::aRTist_available] } {
				set colEntries [list [$bj get id] [$bj get status]]
				lappend colEntries [$bj get runs]
				lappend colEntries [$bj get start_run]
				lappend colEntries [$bj get start_proj_nr]
				lappend colEntries [$bj get json_file]
				lappend colEntries [$bj format_string]
				lappend colEntries [$bj get output_folder]
				lappend colEntries [$bj get output_basename]

				$_batchlist insert end $colEntries
			}
		}

		method add_batch_job_from_json { jsonfile } {
			if { $jsonfile != "" } {
				set bj [::ctsimu::batchjob new]
				$bj set_from_json $jsonfile
				$bj set output_fileformat [my get standard_output_fileformat]
				$bj set output_datatype [my get standard_output_datatype]
				$bj set id [expr [my n_jobs]+1]

				my add_batch_job $bj
			}
		}
		
		method clear { } {
			# Clear GUI list:
			if { [::ctsimu::aRTist_available] } {
				foreach index [$_batchlist childkeys root] {
					$_batchlist delete $index
				}
			}
			
			# Clear manager's own list:
			my reset
		}

		method save_batch_jobs { csvFilename } {
			if { $csvFilename != "" } {
				if {[string tolower [file extension $csvFilename]] != ".csv"} {
					append csvFilename ".csv"
				}

				set fileId [open $csvFilename "w"]
				
				# Header as comment:
				puts $fileId "# JSON File,Output Format,Output Folder,Projection Base Name,Runs,StartRun,StartProjNr,Status"

				foreach bj $_batchjobs {
					set csvLine [::csv::join [list \
						[$bj get json_file] \
						[$bj format_string] \
						[$bj get output_folder] \
						[$bj get output_basename] \
						[$bj get runs] \
						[$bj get start_run] \
						[$bj get start_proj_nr] \
						[$bj get status] ] ]

					puts $fileId $csvLine
				}

				close $fileId
			}
		}

		method import_batch_jobs { csvFilename } {
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
					set bj [::ctsimu::batchjob new]
					
					# Get number of jobs so far...
					set id [expr [my n_jobs]+1]
					$bj set id $id					

					set i 0
					foreach entry $entries {
						if {$i == 0} { $bj set json_file $entry }
						if {$i == 1} { $bj set_format $entry}
						if {$i == 2} { $bj set output_folder $entry}
						if {$i == 3} { $bj set output_basename $entry}
						if {$i == 4} { $bj set runs $entry}
						if {$i == 5} { $bj set start_run $entry}
						if {$i == 6} { $bj set start_proj_nr $entry}
						if {$i == 7} { $bj set status $entry}

						incr i
					}
					
					my add_batch_job $bj
				}
			}
		}
		
		method stop_batch { } {
			set _running 0
		}
		
		method set_status { bj index message } {
			$bj set status $message
			if {[::ctsimu::aRTist_available] && $index >= 0} {
				$_batchlist cellconfigure $index,Status -text $message
			}
		}
		
		method run_batch { global_scenario } {
			set _running 1
			
			set index -1
			foreach bj $_batchjobs {
				incr index
				if { [$bj get status] == "Pending" } {
					if {[$bj get runs] <= 0} {
						my set_status $bj $index "Done"
						continue
					}
					
					$global_scenario reset
					if { [catch {
						if { [::ctsimu::aRTist_available] } {
							aRTist::LoadEmptyProject
						}
						$global_scenario load_json_scene [$bj get json_file] 1
					} err] } {
						my set_status $bj $index "ERROR"
						continue
					}
					$global_scenario set output_fileformat [$bj get output_fileformat]
					$global_scenario set output_datatype [$bj get output_datatype]
					$global_scenario set output_basename [$bj get output_basename]
					$global_scenario set output_folder [$bj get output_folder]
					$global_scenario set start_proj_nr [$bj get start_proj_nr]
					
					if { [::ctsimu::aRTist_available] } {
						${::ctsimu::ctsimu_module_namespace}::fillCurrentParameters
						::SceneView::ViewAllCmd
						${::ctsimu::ctsimu_module_namespace}::showProjection
					}
					
					for {set run [$bj get start_run]} {$run <= [$bj get runs]} {incr run} {
						my set_status $bj $index "Stopped"
						if {[my is_running] == 0} {
							return
						}
						my set_status $bj $index "Running $run/[$bj get runs]"
						
						if { [catch {
							$global_scenario start_scan $run [$bj get runs]
							my set_status $bj $index "Stopped"
						} err] } {
							my set_status $bj $index "ERROR"
						}
						
						if {[my is_running] == 0} {
							return
						}
						my set_status $bj $index "Done"
						
						my sync_batchlist_into_manager
						$global_scenario set start_proj_nr 0
					}
				}
			}
			
			my stop_batch
		}
	}
}