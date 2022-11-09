package require TclOO
package require csv

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_batchjob.tcl]

# Class for a batch job.

namespace eval ::ctsimu {
	::oo::class create batchmanager {
		variable _properties
		variable _batchjobs
		variable _batchlist; # GUI batch list

		constructor { } {
			my set running 0
			my set restart_aRTist_after_each_run 0
			my set waiting_for_restart 0; # waiting for aRTist to restart?
			my set next_run 0; # next run after aRTist will restart
			
			my set standard_output_fileformat  "tiff"
			my set standard_output_datatype    "uint16"
			
			my set kick_off_done      0
			my set csv_list_to_import ""

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

		method kick_off { global_scenario } {
			# This function is meant to execute only once the
			# batch manager has started. It checks if a CSV list
			# has to be imported from the settings and if 
			# the batch manager was waiting for an aRTist restart,
			# to resume running the batch.
			if { [my get kick_off_done] == 0} {
				my set kick_off_done 1
				my kick_off_import

				if { [my get waiting_for_restart] == 1 } {
					my set waiting_for_restart 0
					my run_batch $global_scenario
				}
			}
		}

		method kick_off_import { } {
			# Import batch list from aRTist preferences
			if { [my get csv_list_to_import] != "" } {
				my import_csv_joblist [my get csv_list_to_import]
				my set csv_list_to_import ""
			}
		}

		# Getters
		# -------------------------
		method get { property } {
			# Returns the value for a given `property`.
			return [dict get $_properties $property]
		}

		method is_running { } {
			return [my get running]
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
			$bj set id [expr [my n_jobs]+1]
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

		method csv_joblist { { newline_escaped 0 } } {
			# Header as comment:
			set csv_string "# JSON File,Output Format,Output Folder,Projection Base Name,Runs,StartRun,StartProjNr,Status"

			foreach bj $_batchjobs {
				if { $newline_escaped == 0 } {
					append csv_string "\n"
				} else {
					# Replace newline character with an alias,
					# to store in aRTist settings.ini
					append csv_string "#%NEWLINE%#"
				}				

				append csv_string [::csv::join [list \
					[$bj get json_file] \
					[$bj format_string] \
					[$bj get output_folder] \
					[$bj get output_basename] \
					[$bj get runs] \
					[$bj get start_run] \
					[$bj get start_proj_nr] \
					[$bj get status] ] ]
			}

			return $csv_string
		}

		method save_batch_jobs { csvFilename } {
			if { $csvFilename != "" } {
				if {[string tolower [file extension $csvFilename]] != ".csv"} {
					append csvFilename ".csv"
				}

				set fileId [open $csvFilename "w"]
				puts $fileId [my csv_joblist]
				close $fileId
			}
		}

		method import_csv_joblist { csvjoblist } {
			# Unescape aliased newlines:
			set csvjoblist [string map {"#%NEWLINE%#" "\n"} $csvjoblist]

			set lines [split $csvjoblist "\n"]
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

		method import_batch_jobs { csvFilename } {
			set csvfile [open $csvFilename r]
			fconfigure $csvfile -encoding utf-8
			set csvstring [read $csvfile]
			close $csvfile

			my import_csv_joblist $csvstring		
		}
		
		method stop_batch { } {
			my set running 0
		}
		
		method set_status { bj index message } {
			$bj set status $message
			if {[::ctsimu::aRTist_available] && $index >= 0} {
				$_batchlist cellconfigure $index,Status -text $message
			}
		}

		method jobs_are_pending { } {
			# Check if there are still pending jobs.
			foreach bj $_batchjobs {
				if { [$bj get status] == "Pending" } {
					return 1
				}
			}

			return 0
		}
		
		method run_batch { global_scenario } {
			my set running 1
			my set waiting_for_restart 0
			
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
							::aRTist::LoadEmptyProject
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
					
					if { [my get next_run] > 0 } {
						$global_scenario set start_proj_nr 0
						set startRun [my get next_run]						
						my set next_run 0
					} else {
						set startRun [$bj get start_run]
					}
					
					for {set run $startRun} {$run <= [$bj get runs]} {incr run} {
						my set waiting_for_restart 0

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

						# Apply current settings, in case the aRTist restart
						# option has been changed during the run.
						if { [::ctsimu::aRTist_available] } {
							${::ctsimu::ctsimu_module_namespace}::applyCurrentParameters
						}
												
						# Restart aRTist after this run?
						if { [my get restart_aRTist_after_each_run] == 1 } {
							if { $run < [$bj get runs] } {
								# There are still pending runs.
								my set next_run [expr $run + 1]
								my set_status $bj $index "Pending"
							} else {
								# This batch job is complete.
								my set next_run 0
								my set_status $bj $index "Done"
							}
														
							my stop_batch

							# Restart aRTist if any more jobs are pending.
							if { [my jobs_are_pending] == 1 } {
								my set waiting_for_restart 1

								if { [::ctsimu::aRTist_available] } {
									# Store current state (again), then restart.
									${::ctsimu::ctsimu_module_namespace}::applyCurrentParameters
									::Preferences::Write

									# Start a new aRTist and tell it
									# to "kick off" the module to continue the batch.
									# (i.e., execute the module's kickOff function in modulemain)
									exec $::Xray(Executable) "$::ctsimu::module_directory/kickoff.tcl" &
									
									# Close this aRTist instance:
									::aRTist::shutdown -force
								}						
								
								return
							}
						}
					}
				}
			}

			my stop_batch
		}
	}
}