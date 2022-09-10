package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_helpers.tcl]

# A general class to handle the drift of an arbitrary parameter
# for a given number of frames, including interpolation.

namespace eval ::ctsimu {
	::oo::class create drift {
		# Should the recon projection matrices follow the drift,
		# therefore compensate it during the reconstruction?
		variable _known_to_reconstruction

		# Interpolate between values if number of drift
		# positions does not match number of frames?
		variable _interpolation

		# List of drift values:
		variable _trajectory

		# Physical (internal) unit for all list values:
		variable _native_unit

		constructor { native_unit } {
			my reset
			my set_native_unit $native_unit
		}

		method reset { } {
			# Reset drift object to standard parameters.
			# Clears the trajectory list as well.
			# Used by the constructor as initialization function.
			set _known_to_reconstruction 1
			set _interpolation           0
			set _trajectory              [list ]
		}

		# Getters
		# -------------------------
		method known_to_reconstruction { } {
			# Returns whether this drift must be considered during a
			# reconstruction (1) or not (0). This parameter is used
			# when calculating projection matrices.
			return $_known_to_reconstruction
		}

		method interpolation { } {
			# Returns whether a linear interpolation should take place between
			# drift values (if the number of drift values does not match the number
			# of frames). If no interpolation takes place, there will be discrete
			# steps of drift values (and possibly sudden changes).
			return $_interpolation
		}

		method native_unit { } {
			# Returns the native_unit for the drift values.
			return $_native_unit
		}

		# Setters
		# -------------------------
		method set_known_to_reconstruction { known } {
			# Sets the "known to reconstruction" attribute to
			# true (known = 1) or false (known = 0).
			set _known_to_reconstruction $known
		}

		method set_interpolation { intpol } {
			# Activates linear interpolation between drift values
			# (intpol = 1) or deactivates it (intpol = 0).
			set _interpolation $intpol
		}

		method set_native_unit { native_unit } {
			# Sets the unit of the drift values.
			set _native_unit $native_unit

			if { $_native_unit == "string" } {
				# String drifts (e.g. spectrum files) cannot be interpolated.
				my set_interpolation 0
			}
		}

		method set_from_json { json_object } {
			# Sets the drift from a given JSON drift object.
			my reset
			set success 0

			# Get JSON unit
			set jsonUnit ""
			if { [::ctsimu::json_exists $json_object {unit}] } {
				if { ![::ctsimu::json_isnull $json_object {unit}] } {
					set jsonUnit [::ctsimu::get_value $json_object {unit} "null"]
				}
			}

			# Get drift value(s)
			if { [::ctsimu::json_exists $json_object value] } {
				if { ![::ctsimu::json_isnull $value value] } {
					set jsonValueType [::ctsimu::json_type $json_object value]

					if {$jsonValueType == "number"} {
						set jsonValue [::ctsimu::get_value $json_object {value}]
						lappend _trajectory [::ctsimu::json_convert_to_native_unit $_native_unit $jsonValue]
					} elseif {$jsonValueType == "array"} {
						set jsonValueArray [::ctsimu::extract_json_object $json_object {value}]
						::rl_json::json foreach value $jsonValueArray {
							lappend _trajectory [::ctsimu::convert_to_native_unit $jsonUnit $_native_unit $value]
						}
					}
				} else {
					# TODO: Check if a drift file can be imported (and do import it if possible).
				}
			}

			return $success; # 0 (unsuccessful)
		}

		method get_value_for_frame { frame nFrames } {
			# Returns a drift value for the given frame number,
			# assuming a total number of nFrames. If interpolation
			# is activated, linear interpolation will take place between
			# drift values, but also for frame numbers outside the
			# expected range: 0 < frame > nFrames.
			# Note that the frame number starts at 0.
			set nTrajectoryPoints [llength $_trajectory]

			if { $nTrajectoryPoints > 1 } {
				if { $nFrames > 1 } {
					# We know that we have at least two drift values, so we are
					# on the safe side for linear interpolations.
					# We also know that we have at least two frames in the scan,
					# and can therefore map our "scan progress" (the current frame number)
					# to the array of drift values.

					set lastFrameNr [expr $nFrames - 1];   # Frames start counting at 0.

					# Frame progress on a scale between 0 and 1.
					# 0: first frame (start), 1: last frame (finish)
					set progress [expr double($frame) / double($lastFrameNr) ]

					# Calculate the theoretical array index to get the drift value
					# for the current frame from the array of drift values:
					set lastTrajectoryIndex [expr int($nTrajectoryPoints - 1)]
					set trajectoryIndex [expr $progress * double($lastTrajectoryIndex)]

					if { ($progress >= 0.0) && ($progress <= 1.0) } {
						# We are inside the array of drift values.
						set leftIndex  [expr int(floor($trajectoryIndex))]

						if { double($leftIndex) == $trajectoryIndex } {
							# We are exactly at one trajectory point; no need for interpolation.
							return [lindex $_trajectory $leftIndex]]
						}

						if { $_interpolation } {
							# Linear interpolation...
							set rightIndex [expr int($leftIndex+1)]

							# We return a weighted average of the two drift
							# values where the current frame is "in between".

							# Weight for the right bin is trunc(trajectoryIndex).
							# Tcl doesn't known trunc(), so we need to do a trick.
							# This will remove the number in front of the decimal sign
							# and leave us with all decimal places after the decimal point.
							# e.g. 3.1415 -> 0.1415
							set rightWeight [expr double($trajectoryIndex) - double(floor($trajectoryIndex))]

							# Weight for the left bin is 1 - rightWeight.
							set leftWeight [expr 1.0 - $rightWeight]

							# Linear interpolation between left and right trajectory point:
							return [expr $leftWeight*[lindex $_trajectory $leftIndex] + $rightWeight*[lindex $_trajectory $rightIndex]]
						} else {
							# Return the value at the last drift value index
							# that would apply to this frame position.
							return [lindex $_trajectory $leftIndex]
						}
					} else {
						# Linear interpolation beyond provided trajectory data

						if { $progress > 1.0 } {
							# We are beyond the expected last frame.
							if { $_interpolation } {
								# Linear interpolation beyond last two drift values:
								set trajectoryValue0 [lindex $_trajectory [expr int($lastTrajectoryIndex-1)]]
								set trajectoryValue1 [lindex $_trajectory $lastTrajectoryIndex]
								
								# We assume a linear interpolation function beyond the two
								# last drift values. Taking the last frame as the zero point
								# (i.e., the starting point) of this linear interpolation,
								# the frame's position on the x axis would be:
								set xFrame [expr $trajectoryIndex - double($lastTrajectoryIndex)]
							} else {
								# No interpolation. Return last trajectory value:
								return [lindex $_trajectory $lastTrajectoryIndex]
							}
						} else {
							# We are before the first frame (i.e., before frame 0).
							if { $_interpolation } {
								# Linear interpolation previous to first two drift values:
								set trajectoryValue0 [lindex $_trajectory 0]
								set trajectoryValue1 [lindex $_trajectory 1]

								# We assume a linear interpolation function beyond the two
								# last drift values. Taking the last frame as the zero point
								# (i.e., the starting point) of this linear interpolation,
								# the frame's position on the x axis would be:
								set xFrame $trajectoryIndex; # is negative in this case
							} else {
								# No interpolation. Return first trajectory value:
								return [lindex $_trajectory 0]
							}
						}

						# How many frames do we pass when going from one drift value to the next?
						# Frame 0 does not count here, so we use the $lastFrameNr insted of $nFrames.
						set framesPerTrajectoryPoint [expr double($lastFrameNr) / double($lastTrajectoryIndex)];

						# The slope of our linear interpolation function:
						set m [expr double($trajectoryValue1 - $trajectoryValue0) / double($framesPerTrajectoryPoint)]

						# Return the value from the linear interpolation function. y = m*x + n
						return [expr $m*$xFrame + $trajectoryValue1]
					}
				} else {
					# If "scan" only has 1 or 0 frames, simply return the first trajectory value
					return [lindex $_trajectory 0]
				}
			} else {
				# trajectory points <= 1
				if { $nTrajectoryPoints > 0 } {
					# Simply check if the trajectory consists of at least 1 point and return this value:
					return [lindex $_trajectory 0]
				}
			}

			# Drifts are absolute deviations, so 0 is a sane default value:
			return 0
		}
	}
}