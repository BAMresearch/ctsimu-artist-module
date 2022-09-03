package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_coordinate_system.tcl]

# Parts are objects in the scene: detector, source, stage and samples.
# Each part has its own coordinate system, and a parallel "ghost" coordinate system
# for calculating projection matrices for the reconstruction.
# This is necessary because the user is free not to pass any deviations to the
# reconstruction.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create part {
		constructor { { name "" } } {
			my variable _attachedToStage;  # Is this object attached to the stage coordinate sytem?
			my attach_to_stage 0

			my variable _cs_initial;  # coordinate system for frame 0
			my variable _cs_current;  # coordinate system for current frame

			# Ghost coordinate systems to use for the calculation of
			# recon projection matrices. Those only obey drifts that are
			# 'known_to_reconstruction'.
			my variable _cs_initial_recon;  # frame 0
			my variable _cs_current_recon;  # current frame

			# The coordinates and orientation must be kept as
			# ::ctsimu::parameter objects to properly handle drifts.
			my variable _center_x
			my variable _center_y
			my variable _center_z

			my variable _vector_u_x
			my variable _vector_u_y
			my variable _vector_u_z

			my variable _vector_w_x
			my variable _vector_w_y
			my variable _vector_w_z

			# Translational and rotational deviations:
			my variable _deviations

			set _cs_initial [::ctsimu::coordinate_system new];  # frame 0
			set _cs_current [::ctsimu::coordinate_system new];  # current frame

			# Ghost coordinate system to use for the calculation of
			# recon projection matrices. Those only obey drifts 'known_to_reconstruction'.
			set _cs_initial_recon [::ctsimu::coordinate_system new];  # frame 0
			set _cs_current_recon [::ctsimu::coordinate_system new];  # current frame

			# The object's name will be passed on to the coordinate
			# system via the set_name function.
			my variable _name
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
			my variable _cs_initial _cs_current _cs_initial_recon _cs_current_recon

			$_cs_initial destroy
			$_cs_current destroy
			$_cs_initial_recon destroy
			$_cs_current_recon destroy

			my variable _deviations
			foreach dev $_deviations {
				$dev destroy
			}
			set _deviations [list]
		}

		method reset { } {
			my attach_to_stage 0

			my variable _cs_initial _cs_current _cs_initial_recon _cs_current_recon

			$_cs_initial reset
			$_cs_current reset
			$_cs_initial_recon reset
			$_cs_current_recon reset

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
			# Uses this object's name to give names to the proper coordinate systems.
			# Invoked by default by the set_name function.
			my variable _name _cs_initial _cs_current _cs_initial_recon _cs_current_recon

			append cs_initial_name $_name "_initial"
			$_cs_initial set_name $cs_initial_name

			append cs_current_name $_name "_current"
			$_cs_current set_name $cs_current_name

			append cs_initial_recon_name $_name "_recon_initial"
			$_cs_initial_recon set_name $cs_initial_recon_name

			append cs_current_recon_name $_name "_recon_current"
			$_cs_current_recon set_name $cs_current_recon_name
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
			my variable _attachedToStage
			set _attachedToStage $attached
		}

		method set_geometry { geometry world stage } {
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
						set pos_dev [::ctsimu::deviation new "mm"]
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
						set rot_dev [::ctsimu::deviation new "rad"]
						$rot_dev set_type "rotation"
						$rot_dev set_axis "$axis"
						$rot_dev set_known_to_reconstruction $known_to_recon
						[$rot_dev amount] set_from_json [::ctsimu::extract_json_object $geometry {deviation rotation $axis}]
						lappend _deviations $rot_dev
					}
				}
			}
			
			my variable _cs_initial
			my variable _cs_initial_recon
			
			set frame 0; # Set up frame 0 for all coordinate systems.
			set nFrames 1; # Because for frame zero, it doesn't matter how many frames there are.
			my set_frame_cs $_cs_initial       $world $stage $frame $nFrames 0
			my set_frame_cs $_cs_initial_recon $world $stage $frame $nFrames 1
			my set_frame                       $world $stage $frame $nFrames 0
		}
			
		method set_frame_cs { cs world stage frame nFrames { only_known_to_reconstruction 0 } } {
			# Set up the given coordinate system 'cs' such
			# that is complies with the 'frame' number
			# (assuming a total number of 'nFrames').
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
			
			set center [::ctsimu::vector new [list \
				[$_center_x get_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_center_y get_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_center_z get_value_for_frame $frame $nFrames $only_known_to_reconstruction] ]]
			set u [::ctsimu::vector new [list \
				[$_vector_u_x get_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_vector_u_y get_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_vector_u_z get_value_for_frame $frame $nFrames $only_known_to_reconstruction] ]]
			set w [::ctsimu::vector new [list \
				[$_vector_w_x get_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_vector_w_y get_value_for_frame $frame $nFrames $only_known_to_reconstruction] \
				[$_vector_w_z get_value_for_frame $frame $nFrames $only_known_to_reconstruction] ]]
			
			$cs make_from_vectors $center $u $w [my is_attached_to_stage]
			$cs make_unit_coordinate_system
			
			# Deviations:
			# ------------------------------------
			foreach deviation $_deviations {
				$cs deviate $deviation $world $stage $frame $nFrames $only_known_to_reconstruction
			}
		}
		
		method set_frame { world stage frame nFrames w_rotation_angle } {
			# Set up the 
			# - world:
			#   A ::ctsimu::coordinate_system that represents the world.
			# - stage:
			#   A ::ctsimu::coordinate_system that represents the stage.
			#   Only necessary if the coordinate system will be attached to the
			#   stage. Otherwise, the world coordinate system can be passed as an 
			#   argument.
			# - onlyKnownToReconstruction:
			#   Pass 1 if the known_to_reconstruction JSON parameter must be obeyed,
			#   so only deviations that are known to the reconstruction software
			#   will be handled. Other deviations will be ignored.
			
			my variable _cs_initial
			my variable _cs_initial_recon

			# What needs to be done for normal objects:
			# Apply set_frame_cs to _cs_current and _cs_current_recon.
			
			# What needs to be done for the stage:
			# 1. Get initial stage WITH VECTOR DRIFTS.
			# 2. Apply deviations WITHOUT DEVIATIONAL DRIFTS.
			# 3. Rotate stage by w_rotation_angle.
			# 4. Apply all drifts: for deviations and centre.
		}
		
		method deviate { }
	}
}