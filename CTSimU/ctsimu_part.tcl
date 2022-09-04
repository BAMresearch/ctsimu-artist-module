package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_coordinate_system.tcl]

# Parts are objects in the scene: detector, source, stage and samples.
#
# They have a coordinate system and can define deviations from their
# standard geometries (translations and rotations around given axes).
# The center, vectors and deviations can all have drifts,
# allowing for an evolution through time.
#
# Each part has its own coordinate system, and a parallel "ghost"
# coordinate system for calculating projection matrices for the
# reconstruction. This is necessary because the user is free
# not to pass any deviations to the reconstruction.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create part {
		constructor { { name "" } } {
			# Is this object attached to the stage coordinate sytem?
			my variable _attachedToStage
			my attach_to_stage 0

			# Coordinate system for current frame:
			my variable _cs_current

			# Ghost coordinate system to use for the calculation of
			# recon projection matrices. Those only obey drifts that are
			# 'known_to_reconstruction':
			my variable _cs_recon

			# The coordinates and orientation must be kept as
			# ::ctsimu::parameter objects to properly handle drifts.
			# These parameters are used to assemble a coordinate
			# system for each frame.
			my variable _center_x
			my variable _center_y
			my variable _center_z

			my variable _vector_u_x
			my variable _vector_u_y
			my variable _vector_u_z

			my variable _vector_w_x
			my variable _vector_w_y
			my variable _vector_w_z

			# Translational and rotational deviations
			# (themselves including drifts):
			my variable _deviations

			# A name for this part:
			my variable _name

			# Initialize the coordinate systems:
			set _cs_current [::ctsimu::coordinate_system new];  # current frame
			set _cs_recon   [::ctsimu::coordinate_system new];  # current frame

			# The object's name will be passed on to the coordinate
			# system via the set_name function.
			set _name ""
			my set_name $name

			# Geometry parameters:
			set _center_x [::ctsimu::parameter new "mm"]
			set _center_y [::ctsimu::parameter new "mm"]
			set _center_z [::ctsimu::parameter new "mm"]

			set _vector_u_x [::ctsimu::parameter new]
			set _vector_u_y [::ctsimu::parameter new]
			set _vector_u_z [::ctsimu::parameter new]

			set _vector_w_x [::ctsimu::parameter new]
			set _vector_w_y [::ctsimu::parameter new]
			set _vector_w_z [::ctsimu::parameter new]

			set _deviations [list]
		}

		destructor {
			my variable _cs_current _cs_recon

			$_cs_current destroy
			$_cs_recon destroy

			my variable _deviations
			foreach dev $_deviations {
				$dev destroy
			}
			set _deviations [list]		
		}

		method reset { } {
			# Reset to the default (such as after the
			# object is constructed). Will result in
			# standard alignment with the world coordinate system.
			# Any geometrical deviations are deleted.
			my attach_to_stage 0

			my variable _cs_current _cs_recon

			$_cs_current reset
			$_cs_recon reset

			my variable _deviations
			foreach dev $_deviations {
				$dev destroy
			}
			set _deviations [list]
		}

		# Getters
		# -------------------------
		method name { } {
			my variable _name
			return $_name
		}
		
		method is_attached_to_stage { } {
			# Return the 'attached to stage' property.
			my variable _attachedToStage
			return $_attachedToStage
		}
		
		
		# Setters
		# -------------------------
		method set_name { name } {
			my variable _name
			set _name $name
			my set_cs_names
		}

		method set_cs_names { } {
			# Uses this object's name to give names to the
			# proper coordinate systems.
			# Invoked by default by the set_name function.
			my variable _name _cs_current _cs_recon

			append cs_current_name $_name "_current"
			$_cs_current set_name $cs_current_name

			append cs_recon_name $_name "_recon"
			$_cs_recon set_name $cs_recon_name
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
			my variable _attachedToStage
			set _attachedToStage $attached
		}

		# General
		# -------------------------
		method set_geometry { geometry world stage } {
			# Sets up the part from a JSON geometry definition.
			# `geometry` must be an `rl_json` object.
			# The `world` and `stage` have to be given as
			# `::ctsimu::coordinate_system` objects.
			my reset

			my variable _center_x _center_y _center_z
			my variable _vector_u_x _vector_u_y _vector_u_z
			my variable _vector_w_x _vector_w_y _vector_w_z
			my variable _deviations
			
			# Try to set up the parameter from world coordinate notation (x, y, z).
			# We also have to support legacy spelling of "centre" ;-)
			if { ([json exists $geometry center x] || [json exists $geometry centre x]) && \
				 ([json exists $geometry center y] || [json exists $geometry centre y]) && \
				 ([json exists $geometry center z] || [json exists $geometry centre z]) } {
				# *******************************
				#           Part is in
				#     WORLD COORDINATE SYSTEM
				# *******************************

				# Object is in world coordinate system:
				my attach_to_stage 0

				# Center
				# ---------------
				$_center_x set_from_possible_keys $geometry [list {center x} {centre x}]
				$_center_y set_from_possible_keys $geometry [list {center y} {centre y}]
				$_center_z set_from_possible_keys $geometry [list {center z} {centre z}]

				# Orientation
				# ---------------
				# Vectors can be either u, w (for source, stage, detector) or r, t (for samples).
				if { [$_vector_u_x set_from_possible_keys $geometry [list {vector_u x} {vector_r x}]] && \
					 [$_vector_u_y set_from_possible_keys $geometry [list {vector_u y} {vector_r y}]] && \
					 [$_vector_u_z set_from_possible_keys $geometry [list {vector_u z} {vector_r z}]] && \
					 [$_vector_w_x set_from_possible_keys $geometry [list {vector_w x} {vector_t x}]] && \
					 [$_vector_w_y set_from_possible_keys $geometry [list {vector_w y} {vector_t y}]] && \
					 [$_vector_w_z set_from_possible_keys $geometry [list {vector_w z} {vector_t z}]] } {
					# success
				} else {
					error "Part \'$_name\' is placed in world coordinate system, but its vectors u and w (or r and t, for samples) are not properly defined (each with an x, y and z component)."
					return 0
				}
			} elseif { ([json exists $geometry center u] || [json exists $geometry centre u]) && \
				       ([json exists $geometry center v] || [json exists $geometry centre v]) && \
				       ([json exists $geometry center w] || [json exists $geometry centre w]) } {
				# *******************************
				#           Part is in
				#     STAGE COORDINATE SYSTEM
				# *******************************

				# Object is in stage coordinate system:
				my attach_to_stage 1

				# Center
				# ---------------
				$_center_x set_from_possible_keys $geometry [list {center u} {centre u}]
				$_center_y set_from_possible_keys $geometry [list {center v} {centre v}]
				$_center_z set_from_possible_keys $geometry [list {center w} {centre w}]

				# Orientation
				# ---------------
				# Vectors can only be r, t
				# (because only samples can be attached to the stage).
				if { [$_vector_u_x set_from_key $geometry {vector_r u}] && \
					 [$_vector_u_y set_from_key $geometry {vector_r v}] && \
					 [$_vector_u_z set_from_key $geometry {vector_r w}] && \
					 [$_vector_w_x set_from_key $geometry {vector_t u}] && \
					 [$_vector_w_y set_from_key $geometry {vector_t v}] && \
					 [$_vector_w_z set_from_key $geometry {vector_t w}] } {
					# success
				} else {
					error "Part \'$_name\' is placed in stage system, but its vectors r and t are not properly defined (each with a u, v and w component)."
					return 0
				}
			}

			# *******************************
			#     DEVIATIONS
			# *******************************
			if {[json exists $geometry deviations]} {
				set jsonType [json type $geometry deviations]
				if { $jsonType == "array"} {
					# Go over all elements in the deviations array
					# and add them to this part's list of deviations.
					set jsonDevArray [::ctsimu::extract_json_object $geometry {deviations}]
					json foreach jsonDev $jsonDevArray {
						set dev [::ctsimu::deviation new]
						if { [$dev set_from_json $jsonDev] } {
							lappend _deviations $dev
						}
					}
				} elseif { $jsonType == "object"} {
					# Only one drift defined as a direct object?
					# Actually not supported by file system,
					# but let's be generous.
					set dev [::ctsimu::deviation new]
					if { [$dev set_from_json [::ctsimu::extract_json_object $geometry {deviations}]] } {
						lappend _deviations $dev
					}
				}
			}

			# Support for legacy deviations, prior to
			# file format version 0.9:
			# ------------------------------------------
			if {[json exists $geometry deviation]} {
				set known_to_recon 1
				if {[json exists $geometry deviation known_to_reconstruction]} {
					set known_to_recon [::ctsimu::get_value_in_unit "bool" $geometry {deviation known_to_reconstruction}]
				}

				foreach axis $::ctsimu::valid_axes {
					# Deviations in position
					# -------------------------------------
					# Positional deviations along sample axes r, s, t
					# have not been part of the legacy file formats
					# prior to version 0.9, but we still add them here
					# because now we easily can... ;-)
					if {[json exists $geometry deviation position $axis]} {
						set pos_dev [::ctsimu::deviation new]
						$pos_dev set_type "translation"
						$pos_dev set_axis "$axis"
						$pos_dev set_known_to_reconstruction $known_to_recon
						[$pos_dev amount] set_from_json [::ctsimu::extract_json_object $geometry {deviation position $axis}]
						lappend _deviations $pos_dev
					}
					
					# Deviations in rotation
					# -------------------------------------
					# File formats prior to version 0.9 only supported
					# rotations around u, v and w, in the order wv'u'',
					# and ts'r'' for samples. We need to take care
					# to keep this order here. We also add support
					# for x, y, z (zy'x''), just because we can.
					# The list ::ctsimu::valid_axes is already in the
					# correct order for legacy rotations.
					if {[json exists $geometry deviation rotation $axis]} {
						set rot_dev [::ctsimu::deviation new]
						$rot_dev set_type "rotation"
						$rot_dev set_axis "$axis"
						$rot_dev set_known_to_reconstruction $known_to_recon
						[$rot_dev amount] set_from_json [::ctsimu::extract_json_object $geometry {deviation rotation $axis}]
						lappend _deviations $rot_dev
					}
				}
			}

			my set_frame $world $stage 0 1 0
		}
			
		method set_frame_cs { cs world stage frame nFrames { only_known_to_reconstruction 0 } { w_rotation_in_rad 0 } } {
			# Set up the given coordinate system 'cs' such
			# that it complies with the 'frame' number
			# and all necessary drifts and deviations.
			# (assuming a total number of 'nFrames').
			#
			# This function is used by `set_frame` and is
			# usually not called from outside the object.
			my variable _center_x
			my variable _center_y
			my variable _center_z

			my variable _vector_u_x
			my variable _vector_u_y
			my variable _vector_u_z

			my variable _vector_w_x
			my variable _vector_w_y
			my variable _vector_w_z

			my variable _deviations
			
			# Set up standard coordinate system at frame zero:
			set center [::ctsimu::vector new [list \
				[$_center_x standard_value] \
				[$_center_y standard_value] \
				[$_center_z standard_value] ]]
			set u [::ctsimu::vector new [list \
				[$_vector_u_x standard_value] \
				[$_vector_u_y standard_value] \
				[$_vector_u_z standard_value] ]]
			set w [::ctsimu::vector new [list \
				[$_vector_w_x standard_value] \
				[$_vector_w_y standard_value] \
				[$_vector_w_z standard_value] ]]
			
			$cs make_from_vectors $center $u $w [my is_attached_to_stage]
			$cs make_unit_coordinate_system

			# Potential stage rotation:
			# ------------------------------------
			# Potential rotation around the w axis (in rad).
			$cs rotate_around_w $w_rotation_in_rad
			
			# Deviations:
			# ------------------------------------
			foreach deviation $_deviations {
				$cs deviate $deviation $world $stage $frame $nFrames $only_known_to_reconstruction
			}

			# Drifts (center and vector components):
			# -----------------------------------------------
			# Build a translation vector for the center point
			# from the total drift for this frame, and apply
			# the translation:
			set center_drift [::ctsimu::vector new [list \
				[$_center_x get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_center_y get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
				[$_center_z get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction] ]]
			$cs translate $center_drift

			set vector_u_drift [::ctsimu::vector new [list \
				[$_vector_u_x get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_vector_u_y get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
				[$_vector_u_z get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction] ]]

			set vector_w_drift [::ctsimu::vector new [list \
				[$_vector_w_x get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_vector_w_y get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction]
				[$_vector_w_z get_total_drift_value_for_frame $frame $nFrames $only_known_to_reconstruction] ]]

			if { ([$vector_u_drift length] > 0) || ([$vector_v_drift length] > 0)} {
				set new_u [[$cs u] get_copy]
				set new_w [[$cs w] get_copy]
				$new_u add $vector_drift_u
				$new_w add $vector_drift_w

				set new_center [[$cs center] get_copy]
				$cs make_from_vectors $new_center $new_u $new_w [$cs is_attached_to_stage]
				$cs make_unit_coordinate_system
			}
			
			$center_drift destroy
			$vector_u_drift destroy
			$vector_v_drift destroy
		}
		
		method set_frame { world stage frame nFrames w_rotation_in_rad } {
			# Set up the part for the given frame number, obeying all
			# deviations and drifts.
			#
			# Function arguments:
			# - world:
			#   A ::ctsimu::coordinate_system that represents the world.
			# - stage:
			#   A ::ctsimu::coordinate_system that represents the stage.
			#   Only necessary if the coordinate system will be attached to the
			#   stage. Otherwise, the world coordinate system can be passed as an 
			#   argument.
			# - frame:
			#   Frame number to set up.
			# - nFrames:
			#   Total number of frames in the CT scan.
			# - w_rotation_in_rad:
			#   Possible rotation of the object around its w axis.
			#   Only used for the CT rotation of the sample stage.
			
			my variable _cs_current
			my variable _cs_recon

			# Set up the current CS obeying all drifts:
			my set_frame_cs $_cs_current $world $stage $frame $nFrames 0 $w_rotation_in_rad

			# Set up the recon CS only obeying the drifts 'known to reconstruction':
			my set_frame_cs $_cs_recon   $world $stage $frame $nFrames 1 $w_rotation_in_rad			
		}
	}
}