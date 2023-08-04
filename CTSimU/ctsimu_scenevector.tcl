package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_parameter.tcl]

# A scene vector is a 3D vector that knows the type of its
# reference coordinate system, given as world, local or sample.
# It provides functions to convert between these coordinate systems
# and it can handle drifts. Therefore, all three vector components
# are stored as ::ctsimu::parameter objects.
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
			set _reference "world"; # "world", local", "sample"
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

		method print { } {
			# Return a human-readable string for the current vector representation.
			return "([$_c0 current_value], [$_c1 current_value], [$_c2 current_value]) in [my reference]"
		}

		method has_drifts { } {
			# Returns 1 if the scene vector drifts during the CT scan, 0 otherwise.
			return [expr [$_c0 has_drifts] || [$_c1 has_drifts] || [$_c2 has_drifts]]
		}

		# Setters
		# -------------------------
		method set_reference { reference } {
			# Set the reference coordinate system.
			# Can be "world", "local" or "sample".
			set valid_refs [list "world" "local" "sample"]
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

			# Deletes all drifts and set parameter's
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
			# this vector in its standard orientation
			# (without any drifts applied).

			# Get vector components, not respecting drifts:
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
			set v1 [$_c1 get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
			set v2 [$_c2 get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]

			# Build a vector:
			set v [::ctsimu::vector new [list $v0 $v1 $v2]]

			return $v
		}

		method vector_for_frame { frame { nFrames 0 } { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector
			# for the given frame, respecting all drifts.

			# Get vector components, respecting drifts:
			set v0 [$_c0 set_frame_and_get_value $frame $nFrames $only_known_to_reconstruction]
			set v1 [$_c1 set_frame_and_get_value $frame $nFrames $only_known_to_reconstruction]
			set v2 [$_c2 set_frame_and_get_value $frame $nFrames $only_known_to_reconstruction]

			# Build a vector:
			set v [::ctsimu::vector new [list $v0 $v1 $v2]]

			return $v
		}

		method point_in_world { local sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector for point coordinates
			# in terms of the world coordinate system
			# for the given frame, respecting all drifts.
			#
			# Parameters
			# ----------
			# - local:
			#   A ::ctsimu::coordinate_system that represents the object's
			#   local CS in terms of world coordinates.
			#
			# - sample:
			#   A ::ctsimu::coordinate_system that represents the sample
			#   in terms of the stage coordinate system.
			#   If you don't want to convert from a sample vector,
			#   it doesn't matter what you pass here (you can pass `0`).
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
				set v_in_world [::ctsimu::change_reference_frame_of_point $v $local $::ctsimu::world]

				$v destroy
				return $v_in_world
			} elseif { $_reference == "sample" } {
				# The sample's "world" is the stage (here: local).
				# To get the sample coordinates in stage coordinates,
				# we therefore transform to the world a first time...
				# ...and a second time to transform it
				# from the stage to the world:
				set v_in_stage [::ctsimu::change_reference_frame_of_point $v $sample $::ctsimu::world]
				set v_in_world [::ctsimu::change_reference_frame_of_point $v_in_stage $local $::ctsimu::world]

				$v destroy
				$v_in_stage destroy
				return $v_in_world
			}
		}

		method point_in_local { local sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector for point coordinates
			# in terms of the local coordinate system
			# for the given frame, respecting all drifts.
			#
			# Parameters
			# ----------
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
				set v_in_local [::ctsimu::change_reference_frame_of_point $v $::ctsimu::world $local]

				$v destroy
				return $v_in_local
			} elseif { $_reference == "local" } {
				# Already in local.
				return $v
			} elseif { $_reference == "sample" } {
				# The sample's "world" is the stage (here: local).
				# To get the sample coordinates in stage coordinates,
				# we therefore transform to the world.
				set v_in_stage [::ctsimu::change_reference_frame_of_point $v $sample $::ctsimu::world]

				$v destroy
				return $v_in_stage
			}
		}

		method point_in_sample { stage sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector for point coordinates
			# in the sample coordinate system
			# for the given frame, respecting all drifts.
			#
			# The sample must be attached to the stage,
			# otherwise, use `in_local` instead.
			# Note that a direct conversion from one sample CS to
			# another is not possible with this function.
			#
			# Parameters
			# ----------
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
				# From world to stage...
				# ...and a second time from world to sample
				# because the stage is the sample's "world":
				set v_in_stage [::ctsimu::change_reference_frame_of_point $v $::ctsimu::world $stage]
				set v_in_sample [::ctsimu::change_reference_frame_of_point $v_in_stage $::ctsimu::world $sample]

				$v destroy
				$v_in_stage destroy
				return $v_in_sample
			} elseif { $_reference == "local" } {
				# Convert from stage to sample. Because
				# the stage is the sample's world, we actually
				# convert from world to sample.
				set v_in_sample [::ctsimu::change_reference_frame_of_point $v $::ctsimu::world $sample]

				$v destroy
				return $v_in_sample
			} elseif { $_reference == "sample" } {
				# Already in sample coordinate system:
				return $v
			}
		}

		method direction_in_world { local sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector for a direction
			# in terms of the world coordinate system
			# for the given frame, respecting all drifts.
			#
			# Parameters
			# ----------
			# - local:
			#   A ::ctsimu::coordinate_system that represents the object's
			#   local CS in terms of world coordinates.
			#
			# - sample:
			#   A ::ctsimu::coordinate_system that represents the sample
			#   in terms of the stage coordinate system.
			#   If you don't want to convert from a sample vector,
			#   it doesn't matter what you pass here (you can pass `0`).
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
				set v_in_world [::ctsimu::change_reference_frame_of_direction $v $local $::ctsimu::world]

				$v destroy
				return $v_in_world
			} elseif { $_reference == "sample" } {
				# The sample's "world" is the stage (here: local).
				# To get the sample coordinates in stage coordinates,
				# we therefore transform to the world a first time...
				# ...and a second time to transform it
				# from the stage to the world:
				set v_in_stage [::ctsimu::change_reference_frame_of_direction $v $sample $::ctsimu::world]
				set v_in_world [::ctsimu::change_reference_frame_of_direction $v_in_stage $local $::ctsimu::world]

				$v destroy
				$v_in_stage destroy
				return $v_in_world
			}
		}

		method direction_in_local { local sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector for a direction
			# in terms of the local coordinate system
			# for the given frame, respecting all drifts.
			#
			# Parameters
			# ----------
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
				set v_in_local [::ctsimu::change_reference_frame_of_direction $v $::ctsimu::world $local]

				$v destroy
				return $v_in_local
			} elseif { $_reference == "local" } {
				# Already in local.
				return $v
			} elseif { $_reference == "sample" } {
				# The sample's "world" is the stage (here: local).
				# To get the sample coordinates in stage coordinates,
				# we therefore transform to the world.
				set v_in_stage [::ctsimu::change_reference_frame_of_direction $v $sample $::ctsimu::world]

				$v destroy
				return $v_in_stage
			}
		}

		method direction_in_sample { stage sample frame nFrames { only_known_to_reconstruction 0 } } {
			# Create and return a ::ctsimu::vector for a direction
			# in the sample coordinate system
			# for the given frame, respecting all drifts.
			#
			# The sample must be attached to the stage,
			# otherwise, use `in_local` instead.
			# Note that a direct conversion from one sample CS to
			# another is not possible with this function.
			#
			# Parameters
			# ----------
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
				# From world to stage...
				# ...and a second time from world to sample
				# because the stage is the sample's "world":
				set v_in_stage [::ctsimu::change_reference_frame_of_direction $v $::ctsimu::world $stage]
				set v_in_sample [::ctsimu::change_reference_frame_of_direction $v_in_stage $::ctsimu::world $sample]

				$v destroy
				$v_in_stage destroy
				return $v_in_sample
			} elseif { $_reference == "local" } {
				# Convert from stage to sample. Because
				# the stage is the sample's world, we actually
				# convert from world to sample.
				set v_in_sample [::ctsimu::change_reference_frame_of_direction $v $::ctsimu::world $sample]

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
			if { [::ctsimu::json_exists_and_not_null $json_object x] && \
				 [::ctsimu::json_exists_and_not_null $json_object y] && \
				 [::ctsimu::json_exists_and_not_null $json_object z] } {
				 	my set_reference "world"
				 	if { [$_c0 set_parameter_from_key $json_object {x}] && \
				 	     [$_c1 set_parameter_from_key $json_object {y}] && \
				 	     [$_c2 set_parameter_from_key $json_object {z}] } {
				 	     	# Success
				 	     	return 1
				 	     }
			} elseif {
				 [::ctsimu::json_exists_and_not_null $json_object u] && \
				 [::ctsimu::json_exists_and_not_null $json_object v] && \
				 [::ctsimu::json_exists_and_not_null $json_object w] } {
				 	my set_reference "local"
				 	if { [$_c0 set_parameter_from_key $json_object {u}] && \
				 	     [$_c1 set_parameter_from_key $json_object {v}] && \
				 	     [$_c2 set_parameter_from_key $json_object {w}] } {
				 	     	# Success
				 	     	return 1
				 	     }
			} elseif {
				 [::ctsimu::json_exists_and_not_null $json_object r] && \
				 [::ctsimu::json_exists_and_not_null $json_object s] && \
				 [::ctsimu::json_exists_and_not_null $json_object t] } {
				 	my set_reference "sample"
				 	if { [$_c0 set_parameter_from_key $json_object {r}] && \
				 	     [$_c1 set_parameter_from_key $json_object {s}] && \
				 	     [$_c2 set_parameter_from_key $json_object {t}] } {
				 	     	# Success
				 	     	return 1
				 	     }
			}

			::ctsimu::fail "Unable to set scene vector from JSON file. A vector must be specified by the three components (x,y,z), (u,v,w) or (r,s,t)."
			return 0
		}
	}
}