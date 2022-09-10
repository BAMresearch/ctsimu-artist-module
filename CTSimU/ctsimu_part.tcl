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
	::oo::class create part {
		variable _attachedToStage
		variable _cs_current
		variable _cs_recon
		variable _center
		variable _vector_u
		variable _vector_w
		variable _deviations
		variable _name
		variable _properties

		constructor { { name "" } } {
			# Is this object attached to the stage coordinate sytem?
			my attach_to_stage 0

			# Coordinate system for current frame:
			set _cs_current [::ctsimu::coordinate_system new]

			# Ghost coordinate system to use for the calculation of
			# recon projection matrices. Those only obey drifts that are
			# 'known_to_reconstruction':
			set _cs_recon   [::ctsimu::coordinate_system new]

			# The coordinates and orientation must be kept as
			# ::ctsimu::scenevector objects to properly handle drifts.
			# These are later used to assemble a coordinate
			# system for the current frame.		
			set _center   [::ctsimu::scenevector new "mm"]
			set _vector_u [::ctsimu::scenevector new]
			set _vector_w [::ctsimu::scenevector new]

			# Translational and rotational deviations
			# (themselves including drifts):
			set _deviations [list]

			# A name for this part:
			# The object's name will be passed on to the coordinate
			# system via the set_name function.
			set _name ""
			my set_name $name
			
			# A general list of properties
			# (all of them are of type ::ctsimu::parameter)
			set _properties [list]
		}

		destructor {
			$_cs_current destroy
			$_cs_recon destroy
			
			$_center destroy
			$_vector_u destroy
			$_vector_w destroy

			foreach dev $_deviations {
				$dev destroy
			}
			set _deviations [list]
			
			# Delete all existing properties:
			foreach {key property} $_properties {
				$property destroy
			}
		}

		method reset { } {
			# Reset to the default (such as after the
			# object is constructed). Will result in
			# standard alignment with the world coordinate system.
			# Any geometrical deviations are deleted.
			my attach_to_stage 0

			$_cs_current reset
			$_cs_recon reset

			foreach dev $_deviations {
				$dev destroy
			}
			set _deviations [list]
			
			# Delete all existing properties:
			foreach {key property} $_properties {
				$property destroy
			}
			set _properties [list]
		}

		# Getters
		# -------------------------
		method name { } {
			return $_name
		}
		
		method get { property } {
			# Get a property value from the _properties dict
			return [dict get $_properties $property]
		}
		
		method is_attached_to_stage { } {
			# Return the 'attached to stage' property.
			return $_attachedToStage
		}
		
		
		# Setters
		# -------------------------
		method set { property value { native_unit "" }} {
			# Set a simple property value in
			# the _properties dict by setting the
			# respective parameter's standard value.
			
			# Check if the property already exists:
			if {[dict exists $_properties $property]} {
				# Already exists in dict.
				# Get parameter, reset it and set its standard value:
				set parameter [my get property]
				$parameter reset
				$parameter set_native_unit $native_unit
				$parameter set_standard_value $value
			} else {
				# Create new parameter with value:
				set parameter [::ctsimu::parameter new $native_unit $value]
				dict set _properties $property $parameter
			}
		}
		
		method set_parameter { property parameter } {
			# Set a property value in the _properties dict
			
			# Check if the property already exists:
			if {[dict exists $_properties $property]} {
				# Already exists in dict.
				# Get parameter, reset it and set its standard value:
				set old_parameter [my get property]
				$old_parameter destroy
			}
			
			# Set new property parameter:
			dict set _properties $property $parameter
		}
		
		method set_name { name } {
			set _name $name
			my set_cs_names
		}

		method set_cs_names { } {
			# Uses this object's name to give names to the
			# proper coordinate systems.
			# Invoked by default by the set_name function.
			append cs_current_name $_name "_current"
			$_cs_current set_name $cs_current_name

			append cs_recon_name $_name "_recon"
			$_cs_recon set_name $cs_recon_name
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
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
			
			# Try to set up the parameter from world coordinate notation (x, y, z).
			# We also have to support legacy spelling of "centre" ;-)
			if { ([::ctsimu::json_exists $geometry {center x}] || [::ctsimu::json_exists $geometry {centre x}]) && \
				 ([::ctsimu::json_exists $geometry {center y}] || [::ctsimu::json_exists $geometry {centre y}]) && \
				 ([::ctsimu::json_exists $geometry {center z}] || [::ctsimu::json_exists $geometry {centre z}]) } {
				# *******************************
				#           Part is in
				#     WORLD COORDINATE SYSTEM
				# *******************************

				# Object is in world coordinate system:
				my attach_to_stage 0

				# Center
				# ---------------
				if { [$_center set_from_json [::ctsimu::extract_json_object_from_possible_keys $geometry [list {center} {centre}]]] } {
					# success
				} else {
					error "Part \'$_name\': failed setting the object center from the JSON file. Geometry: $geometry"
					return 0
				}

				# Orientation
				# ---------------
				# Vectors can be either u, w (for source, stage, detector) or r, t (for samples).
				if { [$_vector_u set_from_json [::ctsimu::extract_json_object_from_possible_keys $geometry [list {vector_u} {vector_r}]]] && \
					 [$_vector_w set_from_json [::ctsimu::extract_json_object_from_possible_keys $geometry [list {vector_w} {vector_t}]]] } {
					# success
				} else {
					error "Part \'$_name\' is placed in world coordinate system, but its vectors u and w (or r and t, for samples) are not properly defined (each with an x, y and z component)."
					return 0
				}
			} elseif { ([::ctsimu::json_exists $geometry {center u}] || [::ctsimu::json_exists $geometry {centre u}]) && \
				       ([::ctsimu::json_exists $geometry {center v}] || [::ctsimu::json_exists $geometry {centre v}]) && \
				       ([::ctsimu::json_exists $geometry {center w}] || [::ctsimu::json_exists $geometry {centre w}]) } {
				# *******************************
				#           Part is in
				#     STAGE COORDINATE SYSTEM
				# *******************************

				# Object is in stage coordinate system:
				my attach_to_stage 1

				# Center
				# ---------------
				if { $_center set_from_json [::ctsimu::extract_json_object_from_possible_keys $geometry [list {center} {centre}]] } {
					# success
				} else {
					error "Part \'$_name\': failed setting the object center from the JSON file."
					return 0
				}

				# Orientation
				# ---------------
				# Vectors can only be r, t
				# (because only samples can be attached to the stage).
				if { [$_vector_u set_from_json [::ctsimu::extract_json_object $geometry {vector_r}]] && \
					 [$_vector_w set_from_json [::ctsimu::extract_json_object $geometry {vector_t}]] } {
					# success
				} else {
					error "Part \'$_name\' is placed in stage system, but its vectors r and t are not properly defined (each with a u, v and w component)."
					return 0
				}
			}

			# *******************************
			#     DEVIATIONS
			# *******************************
			if {[::ctsimu::json_exists $geometry deviations]} {
				set jsonType [::ctsimu::json_type $geometry deviations]
				if { $jsonType == "array"} {
					# Go over all elements in the deviations array
					# and add them to this part's list of deviations.
					set jsonDevArray [::ctsimu::extract_json_object $geometry {deviations}]
					::rl_json::json foreach jsonDev $jsonDevArray {
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
			if {[::ctsimu::json_exists $geometry deviation]} {
				set known_to_recon 1
				if {[::ctsimu::json_exists $geometry {deviation known_to_reconstruction}]} {
					set known_to_recon [::ctsimu::get_value_in_unit "bool" $geometry {deviation known_to_reconstruction}]
				}

				foreach axis $::ctsimu::valid_axes {
					# Deviations in position
					# -------------------------------------
					# Positional deviations along sample axes r, s, t
					# have not been part of the legacy file formats
					# prior to version 0.9, but we still add them here
					# because now we easily can... ;-)
					if {[::ctsimu::json_exists $geometry {deviation position $axis}]} {
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
					if {[::ctsimu::json_exists $geometry {deviation rotation $axis}]} {
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
			
			# Set up standard coordinate system at frame zero:
			set center [$_center standard_vector]
			set u [$_vector_u standard_vector]
			set w [$_vector_w standard_vector]
			
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
			set center_drift [$_center drift_vector $frame $nFrames $only_known_to_reconstruction]
			$cs translate $center_drift

			set vector_u_drift [$_vector_u drift_vector $frame $nFrames $only_known_to_reconstruction]
			set vector_w_drift [$_vector_w drift_vector $frame $nFrames $only_known_to_reconstruction]

			if { ([$vector_u_drift length] > 0) || ([$vector_w_drift length] > 0)} {
				set new_u [[$cs u] get_copy]
				set new_w [[$cs w] get_copy]
				$new_u add $vector_u_drift 
				$new_w add $vector_w_drift 

				set new_center [[$cs center] get_copy]
				$cs make_from_vectors $new_center $new_u $new_w [$cs is_attached_to_stage]
				$cs make_unit_coordinate_system
			}
			
			$center_drift destroy
			$vector_u_drift destroy
			$vector_w_drift destroy
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

			# Set up the current CS obeying all drifts:
			my set_frame_cs $_cs_current $world $stage $frame $nFrames 0 $w_rotation_in_rad

			# Set up the recon CS only obeying the drifts 'known to reconstruction':
			my set_frame_cs $_cs_recon   $world $stage $frame $nFrames 1 $w_rotation_in_rad			
		}
	}
}