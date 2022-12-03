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
		variable _id; # aRTist's id for the object
		variable _properties

		constructor { { name "" } { id "" } } {
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
			my set_name $name

			# aRTist id for the object:
			my set_id $id
			
			# A general list of properties
			# (all of them are of type ::ctsimu::parameter)
			set _properties [dict create]
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
			
			# Reset all existing properties:
			foreach {key property} $_properties {
				$property reset
			}
		}

		# Getters
		# -------------------------
		method get { property } {
			# Returns the current value for a given `property`.
			return [[dict get $_properties $property] current_value]
		}

		method parameter { property } {
			# Returns the parameter object behind a given `property`
			return [dict get $_properties $property]
		}

		method current_coordinate_system { } {
			return $_cs_current
		}

		method recon_coordinate_system { } {
			return $_cs_recon
		}

		method center { } {
			return $_center
		}

		method u { } {
			return $_vector_u
		}

		method w { } {
			return $_vector_w
		}

		method id { } {
			# Get the aRTist ID of the part.
			return $_id
		}

		method name { } {
			# Get the name of the part.
			return $_name
		}
		
		method is_attached_to_stage { } {
			# Return the 'attached to stage' property.
			return $_attachedToStage
		}
		
		
		# Setters
		# -------------------------
		method set { property value { native_unit "undefined" }} {
			# Set a simple property value in
			# the _properties dict by setting the
			# respective parameter's standard value.
			
			# Check if the property already exists:
			if {[dict exists $_properties $property]} {
				# Already exists in dict.
				# Get parameter, reset it and set its standard value:
				set param [my parameter $property]
				$param reset

				if {$native_unit != "undefined"} {
					$param set_native_unit $native_unit
				}				

				$param set_standard_value $value
			} else {
				# Create new parameter with value:
				if {$native_unit == "undefined"} {
					# If no native unit is specified, set to "no unit".
					set native_unit ""
				}	

				set param [::ctsimu::parameter new $native_unit $value]
				dict set _properties $property $param
			}
		}

		method set_parameter { property parameter } {
			# Sets the object in the internal properties dictionary
			# that is identified by the `property` key to the given
			# `parameter` (should be a `::ctsimu::parameter` object).
			# If there is already an entry under the given `property` key,
			# this old parameter object will be deleted.
			
			# Check if the property already exists:
			if {[dict exists $_properties $property]} {
				# Already exists in dict. Get it and destroy it:
				[my parameter $property] destroy
			}
			
			# Set new property parameter:
			dict set _properties $property $parameter
		}

		method set_parameter_value { property dictionary key_sequence { fail_value 0 } { native_unit "" } } {
			# Sets the value for the parameter that is identified
			# by the `property` key in the internal properties dictionary.
			# The new value is taken from the given JSON `dictionary`,
			# and located by the given `key_sequence`. Optionally,
			# a `fail_value` can be specified if the value cannot be
			# found at the given `key_sequence`. Also, a `native_unit`
			# can be provided in case the `property` does not yet exist
			# in the internal properties dictionary. In this case,
			# a new `::ctsimu::parameter` is created for the `property`
			# and given the `native_unit`. If the parameter already
			# exists in the internal properties dictionary,
			# it is reset (i.e., all drifts are deleted).

			# Check if the property already exists:
			if {![dict exists $_properties $property]} {
				# If not, create a new parameter object
				# and insert it into the _properties dictionary:
				set param [::ctsimu::parameter new $native_unit $fail_value]
				dict set _properties $property $param
			}

			# Extract the value and set it as standard value:
			set value [::ctsimu::get_value $dictionary $key_sequence "null"]
			if { $value != "null" } {
				# Getting the value succeeded. Set and return 1.
				my set $property $value
				return 1
			} else {
				# Getting the value failed or it is
				# not defined in the JSON file. Use
				# the fail_value instead and return 0.
				my set $property $fail_value
				return 0
			}

			return 0
		}

		method set_parameter_from_key { property dictionary key_sequence { fail_value "undefined" } { native_unit "" } } {
			# Set up a parameter object for the given
			# `property` from the `key_sequence` in the given `dictionary`.
			# The object located at the key sequence must at least
			# have a `value` property. Optionally, a `fail_value`
			# can be specified if the value cannot be found at the
			# given `key_sequence` or is set to `null`.

			# Check if the property already exists:
			if {![dict exists $_properties $property]} {
				# If not, create a new parameter object
				# and insert it into the _properties dictionary:
				set param [::ctsimu::parameter new $native_unit $fail_value]
				dict set _properties $property $param
			}

			set p [my parameter $property]
			if { ![$p set_parameter_from_key $dictionary $key_sequence] } {
				if { $fail_value != "undefined" } {
					# Setting from key failed. Set to fail value.
					my set $property $fail_value
				}

				return 0
			}

			return 1
		}

		method set_parameter_from_possible_keys { property dictionary key_sequences { fail_value "undefined" } { native_unit "" } } {
			# Like `set_parameter_from_key`, but a list of multiple possible
			# `key_sequences` can be provided. Uses the first sequence that matches
			# or the `fail_value` if nothing matches.

			# Check if the property already exists:
			if {![dict exists $_properties $property]} {
				set param [::ctsimu::parameter new $native_unit $fail_value]
				dict set _properties $property $param
			}

			set p [my parameter $property]
			if { ![$p set_parameter_from_possible_keys $dictionary $key_sequences] } {
				if { $fail_value != "undefined" } {
					# Setting from key failed. Set to fail value.
					my set $property $fail_value
				}

				return 0
			}

			return 1
		}
		
		method set_name { name } {
			set _name $name
			my set_cs_names
		}

		method set_id { id } {
			# Set the aRTist `id` of the part.
			set _id $id
		}

		method set_cs_names { } {
			# Uses this object's name to give names to the
			# proper coordinate systems.
			# Invoked by default by the set_name function.
			append cs_current_name [my name] "_current"
			$_cs_current set_name $cs_current_name

			append cs_recon_name [my name] "_recon"
			$_cs_recon set_name $cs_recon_name
		}

		method set_center { c } {
			# Set center. Expects a ::ctsimu::scenevector
			$_center destroy
			set _center $c
		}

		method set_u { u } {
			# Set vector u. Expects a ::ctsimu::scenevector
			$_vector_u destroy
			set _vector_u $u
		}

		method set_w { w } {
			# Set vector w. Expects a ::ctsimu::scenevector
			$_vector_w destroy
			set _vector_w $w
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
			set _attachedToStage $attached
		}

		# General
		# -------------------------
		method set_geometry { geometry stageCS } {
			# Sets up the part from a JSON geometry definition.
			# `geometry` must be an `rl_json` object.
			# The `stageCS` must be given as a `::ctsimu::coordinate_system` object.
			# If this part is not attached to the stage,
			# the `$::ctsimu::world` coordinate system can be passed instead.
			my reset
			
			# Try to set up the part from world coordinate notation (x, y, z).
			# We also have to support legacy spelling of "centre" ;-)
			if { ([::ctsimu::json_exists_and_not_null $geometry {center x}] || [::ctsimu::json_exists_and_not_null $geometry {centre x}]) && \
				 ([::ctsimu::json_exists_and_not_null $geometry {center y}] || [::ctsimu::json_exists_and_not_null $geometry {centre y}]) && \
				 ([::ctsimu::json_exists_and_not_null $geometry {center z}] || [::ctsimu::json_exists_and_not_null $geometry {centre z}]) } {
				# *******************************
				#           Part is in
				#     WORLD COORDINATE SYSTEM
				# *******************************

				# Object is in world coordinate system:
				my attach_to_stage 0

				# Center
				# ---------------
				if { [$_center set_from_json [::ctsimu::json_extract_from_possible_keys $geometry {{center} {centre}}]] } {
					# success
				} else {
					::ctsimu::fail "Part \'[my name]\': failed setting the object center from the JSON file."
					return 0
				}

				# Orientation
				# ---------------
				# Vectors can be either u, w (for source, stage, detector) or r, t (for samples).
				if { [$_vector_u set_from_json [::ctsimu::json_extract_from_possible_keys $geometry {{vector_u} {vector_r}}]] && \
					 [$_vector_w set_from_json [::ctsimu::json_extract_from_possible_keys $geometry {{vector_w} {vector_t}}]] } {
					# success
				} else {
					::ctsimu::fail "Part \'[my name]\' is placed in world coordinate system, but its vectors u and w (or r and t, for samples) are not properly defined (each with an x, y and z component)."
					return 0
				}
			} elseif { ([::ctsimu::json_exists_and_not_null $geometry {center u}] || [::ctsimu::json_exists_and_not_null $geometry {centre u}]) && \
				       ([::ctsimu::json_exists_and_not_null $geometry {center v}] || [::ctsimu::json_exists_and_not_null $geometry {centre v}]) && \
				       ([::ctsimu::json_exists_and_not_null $geometry {center w}] || [::ctsimu::json_exists_and_not_null $geometry {centre w}]) } {
				# *******************************
				#           Part is in
				#     STAGE COORDINATE SYSTEM
				# *******************************

				# Object is in stage coordinate system:
				my attach_to_stage 1

				# Center
				# ---------------
				if { [$_center set_from_json [::ctsimu::json_extract_from_possible_keys $geometry {{center} {centre}}]] } {
					# success
				} else {
					::ctsimu::fail "Part \'[my name]\': failed setting the object center from the JSON file."
					return 0
				}

				# Orientation
				# ---------------
				# Vectors can only be r, t
				# (because only samples can be attached to the stage).
				if { [$_vector_u set_from_json [::ctsimu::json_extract $geometry {vector_r}]] && \
					 [$_vector_w set_from_json [::ctsimu::json_extract $geometry {vector_t}]] } {
					# success
				} else {
					::ctsimu::fail "Part \'[my name]\' is placed in stage system, but its vectors r and t are not properly defined (each with a u, v and w component)."
					return 0
				}
			} else {
				::ctsimu::fail "Failed to set geometry for part \'[my name]\'. Found no valid center definition in JSON file."
				return 0
			}

			# *******************************
			#     DEVIATIONS
			# *******************************
			if {[::ctsimu::json_exists_and_not_null $geometry deviations]} {
				set jsonType [::ctsimu::json_type $geometry deviations]
				if { $jsonType == "array"} {
					# Go over all elements in the deviations array
					# and add them to this part's list of deviations.
					set jsonDevArray [::ctsimu::json_extract $geometry {deviations}]
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
					if { [$dev set_from_json [::ctsimu::json_extract $geometry {deviations}]] } {
						lappend _deviations $dev
					}
				}
			}

			# Support for legacy deviations, prior to
			# file format version 0.9:
			# ------------------------------------------
			if {[::ctsimu::json_exists_and_not_null $geometry deviation]} {
				set known_to_recon 1
				if {[::ctsimu::json_exists_and_not_null $geometry {deviation known_to_reconstruction}]} {
					set known_to_recon [::ctsimu::get_value_in_unit "bool" $geometry {deviation known_to_reconstruction}]
				}

				foreach axis $::ctsimu::valid_axes {
					# Deviations in position
					# -------------------------------------
					# Positional deviations along sample axes r, s, t
					# have not been part of the legacy file formats
					# prior to version 0.9, but we still add them here
					# because now we easily can... ;-)
					if {[::ctsimu::json_exists_and_not_null $geometry [list deviation position $axis] ]} {
						set pos_dev [::ctsimu::deviation new "mm"]
						$pos_dev set_type "translation"
						$pos_dev set_axis "$axis"
						$pos_dev set_known_to_reconstruction $known_to_recon
						[$pos_dev amount] set_from_json [::ctsimu::json_extract $geometry [list deviation position $axis]]
						lappend _deviations $pos_dev
					}
				}

				foreach axis $::ctsimu::valid_axes {
					# Deviations in rotation
					# -------------------------------------
					# File formats prior to version 0.9 only supported
					# rotations around u, v and w, in the order wv'u'',
					# and ts'r'' for samples. We need to take care
					# to keep this order here. We also add support
					# for x, y, z (zy'x''), just because we can.
					# The list ::ctsimu::valid_axes is already in the
					# correct order for legacy rotations.
					if {[::ctsimu::json_exists_and_not_null $geometry [list deviation rotation $axis] ]} {
						set rot_dev [::ctsimu::deviation new "rad"]
						$rot_dev set_type "rotation"
						$rot_dev set_axis "$axis"
						$rot_dev set_known_to_reconstruction $known_to_recon
						[$rot_dev amount] set_from_json [::ctsimu::json_extract $geometry [list deviation rotation $axis]]
						lappend _deviations $rot_dev
					}
				}
			}

			my set_frame $stageCS 0 1 0
		}
			
		method set_frame_cs { cs stageCS frame nFrames { only_known_to_reconstruction 0 } { w_rotation_in_rad 0 } } {
			# Set up the given coordinate system 'cs' such
			# that it complies with the 'frame' number
			# and all necessary drifts and deviations.
			# (assuming a total number of 'nFrames').
			#
			# This function is used by `set_frame` and is
			# usually not called from outside the object.

			::ctsimu::debug "Setting frame CS for [$cs name]..."
			
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
				$cs deviate $deviation $stageCS $frame $nFrames $only_known_to_reconstruction
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
		
		method set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } } {
			# Set up the part for the given frame number, obeying all
			# deviations and drifts.
			#
			# Function arguments:
			# - stageCS:
			#   A ::ctsimu::coordinate_system that represents the stage.
			#   Only necessary if the coordinate system will be attached to the
			#   stage. Otherwise, the world coordinate system can be passed as an 
			#   argument.
			# - frame:
			#   Frame number to set up.
			# - nFrames:
			#   Total number of frames in the CT scan.
			# - w_rotation_in_rad:
			#   Possible rotation angle of the object around its w axis
			#   for the given frame. Only used for the CT rotation
			#   of the sample stage.

			# Set up the current CS obeying all drifts:
			my set_frame_cs $_cs_current $stageCS $frame $nFrames 0 $w_rotation_in_rad

			# Set up the recon CS only obeying the drifts 'known to reconstruction':
			my set_frame_cs $_cs_recon   $stageCS $frame $nFrames 1 $w_rotation_in_rad

			# Set the frame for all elements of the properties dict:
			dict for { key value } $_properties {
				[my parameter $key] set_frame $frame $nFrames
			}
		}

		method place_in_scene { stageCS } {
			# Set position and orientation of object in aRTist scene.

			set coordinateSystem [[my current_coordinate_system] in_world $stageCS]

			# Reset object to initial position:
			if { [::ctsimu::aRTist_available] } {
				::PartList::Invoke [my id] SetPosition    0 0 0
				::PartList::Invoke [my id] SetRefPos      0 0 0
				::PartList::Invoke [my id] SetOrientation 0 0 0
			}

			# Position
			set posX [[$coordinateSystem center] x]
			set posY [[$coordinateSystem center] y]
			set posZ [[$coordinateSystem center] z]
			::ctsimu::debug "   Center for [my id]: [[$coordinateSystem center] print]"

			if { [::ctsimu::aRTist_available] } {
				::PartList::Invoke [my id] SetPosition $posX $posY $posZ
				::PartList::Invoke [my id] SetRefPos   $posX $posY $posZ
			}

			# Orientation
			set u [$coordinateSystem u]
			set w [[$coordinateSystem w] get_copy]
			set local_x [::ctsimu::vector new { 1 0 0 }]
			::ctsimu::debug "   Vector u for [my id]: [[$coordinateSystem u] print]"
			::ctsimu::debug "   Vector w for [my id]: [[$coordinateSystem w] print]"

			# aRTist's detector and source coordinate systems do not match CTSimU specification:
			# aRTist's y vector points downwards in a projection; CTSimU's points upwards.
			# -> reverse w vector to solve this.
			if { [my id] == "D" || [my id] == "S"} {
				::ctsimu::debug "Treating detector or source."
				$w invert
			}

			set wx [[$coordinateSystem w] x]
			set wy [[$coordinateSystem w] y]
			set wz [[$coordinateSystem w] z]

			# Rotate object z axis towards w vector
			if { !( ($wx==0 && $wy==0 && $wz==1) ) } {
				# Rotation axis from cross product (0, 0, 1)x(wx, wy, wz)
				set rotAxis [[$::ctsimu::world w] cross $w]

				if { [$rotAxis length] == 0 } {
					if { [$w dot [$::ctsimu::world w]] < 0} {
						# Vectors point in opposite directions. Rotation axis is another stage CS basis vector.
						::ctsimu::debug "   z axis of object and w axis of target coordinate system point in opposite directions. Using u axis as rotation axis."
						$rotAxis destroy
						set rotAxis [$u get_copy]
					} else {
						::ctsimu::debug "   w axis of object [my id] already points in direction z."
					}	
				}

				if { [$rotAxis length] != 0 } {
					set rotAxis_x [$rotAxis x]
					set rotAxis_y [$rotAxis y]
					set rotAxis_z [$rotAxis z]

					# Rotation angle from scalar product (0, 0, 1)*(wx, wy, wz)
					set rotAngle [[$::ctsimu::world w] angle $w]
					set degAngle [::ctsimu::in_deg $rotAngle]
					::ctsimu::debug "   Rotation V for object [my id] around [$rotAxis print] by angle $degAngle °."

					# Perform rotation
					if { [::ctsimu::aRTist_available] } {
						::PartList::Invoke [my id] Rotate world $degAngle $rotAxis_x $rotAxis_y $rotAxis_z
					}

					$local_x rotate $rotAxis $rotAngle
				}

				$rotAxis destroy
			}

			# Rotate object x axis towards u vector (around now fixed w axis of the object)
			::ctsimu::debug "   local x axis is now: [$local_x print]"
			set rotAxisToU [$local_x cross $u]

			if { [$rotAxisToU length] == 0 } {
				if { [$u dot $local_x] < 0} {
					# Vectors point in opposite directions. Rotation axis is stage w.
					::ctsimu::debug "   x\' axis of object and u axis of target coordinate system point in opposite directions. Using w axis as rotation axis."
					$rotAxisToU destroy
					set rotAxisToU [$w get_copy]
				} else {
					::ctsimu::debug "   u axis of object [my id] already points in direction u."
				}	
			}

			if { [$rotAxisToU length] != 0 } {
				set rotAngle [$local_x angle $u]
				set degAngle [::ctsimu::in_deg $rotAngle]

				set rotAxis_x [$rotAxisToU x]
				set rotAxis_y [$rotAxisToU y]
				set rotAxis_z [$rotAxisToU z]

				::ctsimu::debug "   Rotation U for object [my id] around (0, 0, 1) (of object) by angle $degAngle °."

				# Perform rotation
				if { [::ctsimu::aRTist_available] } {
					::PartList::Invoke [my id] Rotate world $degAngle $rotAxis_x $rotAxis_y $rotAxis_z
				}
			} else {
				::ctsimu::debug "   u axis of object [my id] already points in direction u."
			}

			$coordinateSystem destroy
			$w destroy
			$local_x destroy
			$rotAxisToU destroy
		}
	}
}