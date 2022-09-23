package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_parameter.tcl]

# A scene vector is a 3D vector that knows the type of its
# reference coordinate sytem, given as world, local or sample.
# It provides functions to convert between these coordinate systems
# and it can handle drifts.
# Therefore, all three vector components are of type ::ctsimu::parameter.
#
# Useful for vectors that can change due to drifts,
# such as rotation axis and pivot point of a deviation,
# or, in general, the coordinate system vectors.

namespace eval ::ctsimu {
	::oo::class create scenevector {
		variable _c0; # 1st vector component
		variable _c1; # 2nd vector component
		variable _c2; # 3rd vector component

		# reference coordinate system string:
		# "world", "local", "sample"
		variable _reference

		constructor { { native_unit "" } } {
			set _c0 [::ctsimu::parameter new]
			set _c1 [::ctsimu::parameter new]
			set _c2 [::ctsimu::parameter new]
			my set_native_unit $native_unit

			# Reference coordinate system:
			set _reference "world"; # "local", "sample"
		}

		destructor {
			$_c0 destroy
			$_c1 destroy
			$_c2 destroy
		}

		# Getters
		# -------------------------
		method reference { } {
			# Return the string that identifies
			# the scenevector's reference coordinate system:
			return $_reference
		}	
		
		# Setters
		# -------------------------
		method set_reference { reference } {
			# Set the reference coordinate system.
			# Can be "world", "local" or "stage".
			set valid_refs [list "world" "local" "stage"]
			if { [::ctsimu::is_valid $reference $valid_refs] == 1 } {
				set _reference $reference
			} else {
				::ctsimu::fail "{$reference} is not a valid reference string. Should be any of: {$valid_refs}."
			}
		}
		
		method set_native_unit { native_unit } {
			# Set native unit of vector components.
			# Necessary for the location of points such as 
			# the center points of coordinate systems,
			# usually given in "mm" as native unit.
			$_c0 set_native_unit $native_unit
			$_c1 set_native_unit $native_unit
			$_c2 set_native_unit $native_unit
		}
		
		method set_simple { c0 c1 c2 } {
			# Set a simple scene vector from three numbers,
			# results in a scene vector without drifts.
			$_c0 set_standard_value $c0
			$_c1 set_standard_value $c1
			$_c2 set_standard_value $c2

			# Deletes all drifts and sets parameter's
			# current value to standard value:
			$_c0 reset
			$_c1 reset
			$_c2 reset
		}
		
		method set_component { i parameter } {
			# Set the `i`th vector component to
			# `parameter` (which must be a `::ctsimu::parameter`).
			if {$i == 0} {
				$_c0 destroy
				set _c0 $parameter
			} elseif {$i == 1} {
				$_c1 destroy
				set _c1 $parameter
			} elseif {$i == 2} {
				$_c2 destroy
				set _c2 $parameter
			}
		}
		
		# General
		# -------------------------
		method standard_vector { } {
			# Create a ::ctsimu::vector that represents
			# this vector without any drifts.

			# Get vector components, respecting drifts:
			set v0 [$_c0 standard_value]
			set v1 [$_c1 standard_value]
			set v2 [$_c2 standard_value]
			
			# Build a vector:
			set v [::ctsimu::vector new [list $v0 $v1 $v2]]
			
			return $v
		}
		
		method drift_vector { frame nFrames { only_known_to_reconstruction 0 } } {
			# Create a ::ctsimu::vector that represents
			# only the drift values for the given
			# frame number.
			# Can later be added to the standard
			# value to get the resulting vector respecting
			# all drifts.
			
			# Get vector components, respecting drifts:
			set v0 [$_c0 get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			set v1 [$_c0 get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			set v2 [$_c0 get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			
			# Build a vector:
			set v [::ctsimu::vector new [list $v0 $v1 $v2]]
			
			return $v
		}
		
		method vector_for_frame { frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector
			# for the given frame, respecting all drifts.
			
			# Get vector components, respecting drifts:
			set v0 [$_c0 get_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			set v1 [$_c1 get_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			set v2 [$_c2 get_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			
			# Build a vector:
			set v [::ctsimu::vector new [list $v0 $v1 $v2]]
			
			return $v
		}
		
		method in_world { point_or_direction local sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector
			# in terms of the world coordinate system
			# for the given frame, respecting all drifts.
			#
			#
			# Function arguments:
			# -------------------------
			# - point_or_direction:
			#   A string that specifies whether you need
			#   to convert point coordinates ("point") or
			#   a direction ("direction").
			#
			# - local:
			#   A ::ctsimu::coordinate_system that represents the object's
			#   local CS in terms of world coordinates.
			#
			# - sample:
			#   A ::ctsimu::coordinate_system that represents the sample
			#   in terms of the stage coordinate system.
			#   If you don't want to convert from a sample vector,
			#   it doesn't matter what you pass here (pass `0`).
			#
			# - frame:
			#   The number of the current frame.
			#
			# - nFrames:
			#   The total number of frames.
			#
			# - only_known_to_reconstruction:
			#   Only handle drifts that are known to the recon software.
			
			set v [my vector_for_frame $frame $nFrames $only_known_to_reconstruction]
			
			if { $_reference == "world" } {
				# Already in world.
				return $v
			} elseif { $_reference == "local" } {
				# Convert from local to world.
				if { $point_or_direction == "point" } {
					set v_in_world [::ctsimu::change_reference_frame_of_point $v $local $::ctsimu::world]
				} elseif { $point_or_direction == "direction" } {
					set v_in_world [::ctsimu::change_reference_frame_of_direction $v $local $::ctsimu::world]
				} else {
					::ctsimu::fail "Transformation type point_or_direction must be either \"point\" or \"direction\"."
				}
				$v destroy
				return $v_in_world
			} elseif { $_reference == "sample" } {
				# The sample's "world" is the stage (here: local).
				# To get the sample coordinates in stage coordinates,
				# we therefore transform to the world a first time...
				# ...and a second time to transform it
				# from the stage to the world:
				if { $point_or_direction == "point" } {
					set v_in_stage [::ctsimu::change_reference_frame_of_point $v $sample $::ctsimu::world]
					set v_in_world [::ctsimu::change_reference_frame_of_point $v_in_stage $local $::ctsimu::world]
				} elseif { $point_or_direction == "direction" } {
					set v_in_stage [::ctsimu::change_reference_frame_of_direction $v $sample $::ctsimu::world]
					set v_in_world [::ctsimu::change_reference_frame_of_direction $v_in_stage $local $::ctsimu::world]
				} else {
					::ctsimu::fail "Transformation type point_or_direction must be either \"point\" or \"direction\"."
				}
				
				$v destroy
				$v_in_stage destroy
				return $v_in_world
			}
		}
		
		method in_local { point_or_direction local sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector
			# in terms of the local coordinate system
			# for the given frame, respecting all drifts.
			#
			# Function arguments:
			# -------------------------
			# - point_or_direction:
			#   A string that specifies whether you need
			#   to convert point coordinates ("point") or
			#   just a direction ("direction").
			#
			# - local:
			#   A ::ctsimu::coordinate_system that represents the object's
			#   local CS in terms of world coordinates.
			#
			# - sample:
			#   A ::ctsimu::coordinate_system that represents the sample
			#   in terms of the stage coordinate system.
			#   If you don't want to convert from a sample vector,
			#   it doesn't matter what you pass here (pass `0`).
			#
			# - frame:
			#   The number of the current frame.
			#
			# - nFrames:
			#   The total number of frames.
			#
			# - only_known_to_reconstruction:
			#   Only handle drifts that are known to the recon software.
			
			set v [my vector_for_frame $frame $nFrames $only_known_to_reconstruction]
			
			if { $_reference == "world" } {
				# Convert from world to local.
				if { $point_or_direction == "point" } {
					set v_in_local [::ctsimu::change_reference_frame_of_point $v $::ctsimu::world $local]
				} elseif { $point_or_direction == "direction" } {
					set v_in_local [::ctsimu::change_reference_frame_of_direction $v $::ctsimu::world $local]
				} else {
					::ctsimu::fail "Transformation type point_or_direction must be either \"point\" or \"direction\"."
				}
				$v destroy
				return $v_in_local
			} elseif { $_reference == "local" } {
				# Already in local.
				return $v
			} elseif { $_reference == "sample" } {
				# The sample's "world" is the stage (here: local).
				# To get the sample coordinates in stage coordinates,
				# we therefore transform to the world.
				if { $point_or_direction == "point" } {
					set v_in_stage [::ctsimu::change_reference_frame_of_point $v $sample $::ctsimu::world]
				} elseif { $point_or_direction == "direction" } {
					set v_in_stage [::ctsimu::change_reference_frame_of_direction $v $sample $::ctsimu::world]
				}
								
				$v destroy
				return $v_in_stage
			}
		}
		
		method in_sample { point_or_direction stage sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector
			# in the sample coordinate system
			# for the given frame, respecting all drifts.
			#
			# The sample must be attached to the stage.
			# Note that a conversion from one sample CS to
			# another is not possible with this function.
			#
			# Function arguments:
			# -------------------------
			# - point_or_direction:
			#   A string that specifies whether you need
			#   to convert point coordinates ("point") or
			#   just a direction ("direction").
			#
			# - stage:
			#   A ::ctsimu::coordinate_system that represents the local CS
			#   of the stage in terms of world coordinates.
			#
			# - sample:
			#   A ::ctsimu::coordinate_system that represents the sample
			#   in terms of the stage coordinate system.
			#   MUST BE THE SAME SAMPLE TO WHICH THIS SCENE VECTOR REFERS!
			#
			# - frame:
			#   The number of the current frame.
			#
			# - nFrames:
			#   The total number of frames.
			#
			# - only_known_to_reconstruction:
			#   Only handle drifts that are known to the recon software.
			
			set v [my vector_for_frame $frame $nFrames $only_known_to_reconstruction]
			
			if { $_reference == "world" } {
				# From world to local (i.e., the stage)...
				# ...and a second time from world to sample
				# because the stage is the sample's "world":
				if { $point_or_direction == "point" } {
					set v_in_stage [::ctsimu::change_reference_frame_of_point $v $::ctsimu::world $stage]
					set v_in_sample [::ctsimu::change_reference_frame_of_point $v_in_stage $::ctsimu::world $sample]
				} elseif { $point_or_direction == "direction" } {
					set v_in_stage [::ctsimu::change_reference_frame_of_direction $v $::ctsimu::world $stage]
					set v_in_sample [::ctsimu::change_reference_frame_of_direction $v_in_stage $::ctsimu::world $sample]
				} else {
					::ctsimu::fail "Transformation type point_or_direction must be either \"point\" or \"direction\"."
				}
				
				$v destroy
				$v_in_stage destroy
				return $v_in_sample
			} elseif { $_reference == "local" } {
				# Convert from stage to sample. Because
				# the stage is the sample's world, we actually
				# convert from world to sample.
				if { $point_or_direction == "point" } {
					set v_in_sample [::ctsimu::change_reference_frame_of_point $v $::ctsimu::world $sample]
				} elseif { $point_or_direction == "direction" } {
					set v_in_sample [::ctsimu::change_reference_frame_of_direction $v $::ctsimu::world $sample]
				} else {
					::ctsimu::fail "Transformation type point_or_direction must be either \"point\" or \"direction\"."
				}
				$v destroy
				return $v_in_sample
			} elseif { $_reference == "sample" } {
				# Already in sample coordinate system:
				return $v
			}
		}
		
		method set_from_json { json_object } {
			# Sets up the scene vector from a CTSimU JSON
			# object that describes a three-component vector.		
			if { [::ctsimu::json_exists $json_object x] && \
				 [::ctsimu::json_exists $json_object y] && \
				 [::ctsimu::json_exists $json_object z] } {
				 	my set_reference "world"
				 	if { [$_c0 set_from_key $json_object {x}] && \
				 	     [$_c1 set_from_key $json_object {y}] && \
				 	     [$_c2 set_from_key $json_object {z}] } {
				 	     	# Success
				 	     	return 1
				 	     }
			} elseif {
				 [::ctsimu::json_exists $json_object u] && \
				 [::ctsimu::json_exists $json_object v] && \
				 [::ctsimu::json_exists $json_object w] } {
				 	my set_reference "stage"
				 	if { [$_c0 set_from_key $json_object {u}] && \
				 	     [$_c1 set_from_key $json_object {v}] && \
				 	     [$_c2 set_from_key $json_object {w}] } {
				 	     	# Success
				 	     	return 1
				 	     }
			} elseif {
				 [::ctsimu::json_exists $json_object r] && \
				 [::ctsimu::json_exists $json_object s] && \
				 [::ctsimu::json_exists $json_object t] } {
				 	my set_reference "sample"
				 	if { [$_c0 set_from_key $json_object {r}] && \
				 	     [$_c1 set_from_key $json_object {s}] && \
				 	     [$_c2 set_from_key $json_object {t}] } {
				 	     	# Success
				 	     	return 1
				 	     }
			}
			
			return 0
		}
	}
}