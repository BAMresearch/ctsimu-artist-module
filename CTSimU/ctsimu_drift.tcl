package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_helpers.tcl]

# A general class to handle the drift of an arbitrary value
# for a given number of frames, including interpolation.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create drift {
		constructor { _unit } {
			my variable isActive;                 # Is this an active (set) drift?
			my variable known_to_reconstruction;  # Should the projection matrices follow the drift, therefore compensate it during the reconstruction?
			my variable interpolation;            # Interpolate between values if number of drift positions does not match number of frames?
			my variable trajectory;               # List of drift values
			my variable unit;                     # Physical (internal) unit for all list values

			my reset
			set unit $_unit
		}

		method reset { } {
			set isActive                1
			set known_to_reconstruction 1
			set interpolation           0
			set trajectory              [list ]
		}

		# Getters
		method isActive { } {
			my variable isActive
			return $isActive
		}

		method known_to_reconstruction { } {
			my variable known_to_reconstruction
			return $known_to_reconstruction
		}

		method interpolation { } {
			my variable interpolation
			return $interpolation
		}

		method unit { } {
			my variable unit
			return $unit
		}

		# Setters
		method setActive { active } {
			my variable isActive
			set isActive $active
		}

		method set_known_to_reconstruction { known } {
			my variable known_to_reconstruction
			set known_to_reconstruction $known
		}

		method setInterpolation { intpol } {
			my variable interpolation
			set interpolation $intpol
		}

		method setUnit { u } {
			my variable unit
			set unit $u
		}

		method set_from_JSON { jsonParameter } {
			my variable trajectory unit
			my reset
			set success 0

			# Get JSON unit
			set jsonUnit ""
			if { [json exists $jsonParameter unit] } {
				if { ![json isnull $jsonParameter unit] } {
					set jsonUnit [json get $jsonParameter unit]
				}
			}

			# Get drift value(s)
			if { [json exists $jsonParameter value] } {
				if { ![json isnull $value value] } {
					set jsonValue [::ctsimu::getValue $jsonParameter]
					set jsonValueType [json type $jsonValue]

					if {$jsonValueType == "number"} {
						lappend trajectory [::ctsimu::json_convert_to_native_unit $unit $jsonParameter]
					} elseif {$jsonValueType == "array"} {
						json foreach value $jsonValue {
							lappend trajectory [::ctsimu::convert_to_native_unit $jsonUnit $unit $value]
						}
					}
				} else {
					
				}
			}

			set isActive 0
			return $success; # 0 (unsuccessful)
		}

		method getValueForFrame { frame nFrames } {
			# Return a drift value for 'frame', given a total number of 'nFrames'
			my variable interpolation trajectory

			set nTrajectoryPoints [llength $trajectory]

			if { $nTrajectoryPoints > 1 } {
				if { $nFrames > 1 } {
					set lastFrameNr [expr $nFrames - 1]
					set progress [expr double($frame) / double($lastFrameNr) ]   # 0: first frame, 1: last frame

					set lastTrajectoryIndex [expr int($nTrajectoryPoints - 1)]
					set trajectoryIndex [expr $progress * double($lastTrajectoryIndex)]

					if { ($progress >= 0.0) && ($progress <= 1.0) } {
						set leftIndex  [expr floor($trajectoryIndex)]

						if { double($leftIndex) == $trajectoryIndex } {
							# We are exactly at one trajectory point; no need for interpolation.
							return [lindex $trajectory $leftIndex]]
						}

						if { $interpolation } {
							# Linear interpolation...
							set rightIndex [expr ceil($trajectoryIndex)]

							# Weight for the right bin is trunc(trajectoryIndex)
							set rightWeight [expr $trajectoryIndex - floor($trajectoryIndex)]

							# Weight for the left bin is 1 - trunc(trajectoryIndex)
							set leftWeight [expr 1.0 - ($trajectoryIndex - floor($trajectoryIndex))]

							# Linear interpolation between left and right trajectory point:
							return [expr $leftWeight*[lindex $trajectory $leftIndex] + $rightWeight*[lindex $trajectory $rightIndex]]
						} else {
							return [lindex $trajectory $leftIndex]
						}
					} else {
						# Linear interpolation beyond provided trajectory data

						set framesPerTrajectoryPoint [expr double($lastFrameNr) / double($lastTrajectoryIndex)]; # frame 0 does not count

						if { $progress > 1.0 } {
							if { $interpolation } {
								# Linear interpolation beyond last two trajectory points
								set trajectoryValue0 [lindex $trajectory $lastTrajectoryIndex]
								set trajectoryValue1 [lindex $trajectory [expr $lastTrajectoryIndex-1]]
								set xFrame [expr $trajectoryIndex - double($lastTrajectoryIndex)]
							} else {
								# Return last trajectory value
								return [lindex $trajectory $lastTrajectoryIndex]
							}
						} else {
							if { $interpolation } {
								# Linear interpolation previous to first two trajectory points
								set trajectoryValue0 [lindex $trajectory 0]
								set trajectoryValue1 [lindex $trajectory 1]
								set xFrame $trajectoryIndex; # is negative in this case
							} else {
								# Return first trajectory value
								return [lindex $trajectory 0]
							}
						}

						set m [expr double($trajectoryValue1 - $trajectoryValue0) / double($framesPerTrajectoryPoint)]

						return [expr $m*$xFrame + $trajectoryValue1]
					}
				} else {
					# If "scan" only has 1 or 0 frames, simply return the first trajectory value
					return [lindex $trajectory 0]
				}
			} else {
				# trajectory points <= 1
				if { $nTrajectoryPoints > 0 } {
					# Simply check if the trajectory consists of at least 1 point and return this value:
					return [lindex $trajectory 0]
				}
			}

			return 0; # We usually have relative deviations, so 0 is a sane value.
		}
	}
}