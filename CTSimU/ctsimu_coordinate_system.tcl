package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_deviation.tcl]

# Class for a coordinate system with three basis vectors.

namespace eval ::ctsimu {
	::oo::class create coordinate_system {
		variable _name
		variable _center
		variable _u
		variable _v
		variable _w
		variable _attachedToStage

		constructor { { name "" } } {
			# Initialize center and direction vectors u, v, w to empty vectors.
			my attach_to_stage 0

			set _name ""
			my set_name $name

			# Current center and basis vectors:
			set _center [::ctsimu::vector new]
			set _u      [::ctsimu::vector new]
			set _v      [::ctsimu::vector new]
			set _w      [::ctsimu::vector new]
		}

		destructor {
			$_center destroy
			$_u destroy
			$_v destroy
			$_w destroy
		}

		method reset { } {
			# Resets the coordinate system to a standard world coordinate system
			$_center set_values [list 0 0 0]
			$_u      set_values [list 1 0 0]
			$_v      set_values [list 0 1 0]
			$_w      set_values [list 0 0 1]

			my attach_to_stage 0; # For now, this is not a sub-coordinate system of the sample stage.
		}

		method print { } {
			# Generates a human-readable info string.
			set s "Center: "
			append s [$_center print]

			append s "\nu: "
			append s [$_u print]

			append s "\nv: "
			append s [$_v print]

			append s "\nw: "
			append s [$_w print]

			return $s
		}

		method make_unit_coordinate_system { } {
			# Make coordinate system base unit vectors.
			try {
				$_u to_unit_vector
				$_v to_unit_vector
				$_w to_unit_vector
			} on error { result } {
				::ctsimu::fail "Cannot make [my name] a unit coordinate system: $result"
			}
		}

		method make_from_vectors { center u w attached } {
			# Set the coordinate system from the ::ctsimu::vector objects
			# center, u (first basis vector) and w (third basis vector).
			# attached should be 1 if the reference coordinate system is
			# the stage ("attached to stage") and 0 if not.

			my set_center $center
			my set_u      $u
			my set_w      $w
			my set_v      [$w cross $u]

			my attach_to_stage $attached
		}

		method make { cx cy cz ux uy uz wx wy wz attached } {
			# Set up the coordinate system from vector components (all floats)
			# for the center (cx, cy, cz), the u vector (first basis vector,
			# ux, uy, uz) and the w vector (third basis vector, wx, wy, wz).
			# attached should be 1 if the reference coordinate system is
			# the stage ("attached to stage") and 0 if not.

			set c [::ctsimu::vector new [list $cx $cy $cz]]
			set u [::ctsimu::vector new [list $ux $uy $uz]]
			set w [::ctsimu::vector new [list $wx $wy $wz]]

			my make_from_vectors $c $u $w $attached
		}

		# Getters
		# -------------------------
		method get_copy { { new_name 0 } } {
			# Return a copy of this coordinate system.
			set C [::ctsimu::coordinate_system new]

			$C set_center [$_center get_copy]
			$C set_u      [$_u get_copy]
			$C set_v      [$_v get_copy]
			$C set_w      [$_w get_copy]

			if { $new_name != 0 } {
				$C set_name $new_name
			} else {
				$C set_name [my name]
			}

			return $C
		}

		method name { } {
			return $_name
		}

		method center { } {
			return $_center
		}

		method u { } {
			return $_u
		}

		method v { } {
			return $_v
		}

		method w { } {
			return $_w
		}

		method is_attached_to_stage { } {
			# Return the 'attached to stage' property.
			return $_attachedToStage
		}

		method in_world { stageCS } {
			# Return a copy of this coordinate system with
			# the reference being the world coordinate system.
			set cs [my get_copy]
			if { [my is_attached_to_stage] == 0 } {
				return $cs
			} else {
				$cs change_reference_frame $stageCS $::ctsimu::world
				return $cs
			}
		}

		# Setters
		# -------------------------
		method set_name { name } {
			set _name $name
		}

		method set_center { c } {
			$_center destroy
			set _center $c
		}

		method set_u { u } {
			$_u destroy
			set _u $u
		}

		method set_v { v } {
			$_v destroy
			set _v $v
		}

		method set_w { w } {
			$_w destroy
			set _w $w
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
			set _attachedToStage $attached
		}

		# Transformations
		# -------------------------
		method translate { translation_vector } {
			# Shift center by given translation vector.
			$_center add $translation_vector
		}
		
		method translate_along_axis { axis distance } {
			# Shift center along `axis` by given `distance`.
			set t [$axis get_unit_vector]
			$t scale $distance
			my translate $t
			$t destroy
		}

		method translate_x { dx } {
			# Translate coordinate system in x direction by distance dx.
			set t [::ctsimu::vector new [list $dx 0 0]]; # new translation vector
			my translate $t
			$t destroy
		}

		method translate_y { dy } {
			# Translate coordinate system in y direction by distance dy.
			set t [::ctsimu::vector new [list 0 $dy 0]]; # new translation vector
			my translate $t
			$t destroy
		}

		method translate_z { dz } {
			# Translate coordinate system in z direction by distance dz.
			set t [::ctsimu::vector new [list 0 0 $dz]]; # new translation vector
			my translate $t
			$t destroy
		}
		
		method translate_u { du } {
			# Translate coordinate system in u direction by distance du.
			my translate_along_axis $_u du
		}
		
		method translate_v { dv } {
			# Translate coordinate system in v direction by distance dv.
			my translate_along_axis $_v dv
		}
		
		method translate_w { dw } {
			# Translate coordinate system in w direction by distance dw.
			my translate_along_axis $_w dw
		}
		
		method rotate { axis angle_in_rad } {
			# Rotate coordinate system around the given axis vector
			# by angle_in_rad. This does not move the center point,
			# as the axis vector is assumed to be attached to
			# the center of the coordinate system.
			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $axis $angle_in_rad]
				$_u transform_by_matrix $R
				$_v transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_pivot_point { axis angle_in_rad pivot_point } {
			# Rotate coordinate system around a pivot point.
			# Generally, this will result in a different center position,
			# as the axis of rotation is assumed to be attached to the
			# pivot point.
			# axis and pivot_point must be given as ::ctsimu::vector objects.

			# Move coordinate system such that pivot point is at world origin:
			$_center subtract $pivot_point

			# Rotate center point and transform back into
			# world coordinate system:
			$_center rotate $axis $angle_in_rad
			$_center add $pivot_point

			# Rotate the coordinate system itself:
			my rotate $axis $angle_in_rad
		}

		method rotate_around_x { angle_in_rad } {
			# Rotate coordinate system around world's x axis by angle.
			if {$angle_in_rad != 0} {
				set x_axis [::ctsimu_vector new [list 1 0 0]]
				my rotate $x_axis $angle_in_rad
				$x_axis destroy
			}
		}

		method rotate_around_y { angle_in_rad } {
			# Rotate coordinate system around world's y axis by angle.
			if {$angle_in_rad != 0} {
				set y_axis [::ctsimu_vector new [list 0 1 0]]
				my rotate $y_axis $angle_in_rad
				$y_axis destroy
			}
		}

		method rotate_around_z { angle_in_rad } {
			# Rotate coordinate system around world's z axis by angle.
			if {$angle_in_rad != 0} {
				set z_axis [::ctsimu_vector new [list 0 0 1]]
				my rotate $z_axis $angle_in_rad
				$z_axis destroy
			}
		}

		method rotate_around_u { angle_in_rad } {
			# Rotate coordinate system around u axis by angle.
			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $_u $angle_in_rad]
				$_v transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_v { angle_in_rad } {
			# Rotate coordinate system around v axis by angle.
			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $_v $angle_in_rad]
				$_u transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_w { angle_in_rad } {
			# Rotate coordinate system around w axis by angle.
			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $_w $angle_in_rad]
				$_u transform_by_matrix $R
				$_v transform_by_matrix $R
				$R destroy
			}
		}

		method transform { csFrom csTo } {
			# Relative transformation in world coordinates
			# from csFrom to csTo, result will be in world coordinates.
			#
			# Detailed description: assuming this CS, csFrom and csTo
			# all three are independent coordinate systems in a common
			# reference coordinate system (e.g. world). This function
			# will calculate the necessary translation and rotation that
			# would have to be done to superimpose csFrom with csTo.
			# This translation and rotation will, however, be applied
			# to this CS, not to csFrom.

			set t [[$csFrom center] to [$csTo center]]
			my translate $t
			$t destroy

			# We need a copy of csFrom and csTo because later on,
			# we might have to transform them and don't want to
			# affect the original csFrom passed to this function.
			# Also, csFrom or csTo could simply be pointers to
			# this coordinate system.
			set csFromCopy [$csFrom get_copy]
			set csToCopy   [$csTo get_copy]

			# -- ROTATIONS	
			# Rotation to bring w axis from -> to
			set wFrom [$csFromCopy w]
			set wTo   [$csToCopy w]
			set rotationAxis [$wFrom cross $wTo]
			
			if { [$rotationAxis length] == 0 } {
				if { [$wTo dot $wFrom] < 0 } {
					# 180° flip; vectors point in opposite direction. Rotation axis is another CS basis vector.
					$rotationAxis destroy
					set rotationAxis [[$csFromCopy u] get_copy]
				} else {
					# wFrom already points in direction of wTo.
				}
			}

			if { [$rotationAxis length] > 0 } {
				set rotationAngle [$wFrom angle $wTo]
				if { $rotationAngle != 0 } {
					my rotate_around_pivot_point $rotationAxis $rotationAngle [$csToCopy center]

					# Also rotate the csFrom to make calculation of rotation around u axis possible (next step):
					$csFromCopy rotate $rotationAxis $rotationAngle
				}
			}

			# Rotation to bring u axis from -> to (around now fixed w axis)
			set uFrom [$csFromCopy u]
			set uTo   [$csToCopy u]

			$rotationAxis destroy
			set rotationAxis [$uFrom cross $uTo]
			if { [$rotationAxis length] == 0 } {
				if { [$uTo dot $uFrom] < 0 } {
					# 180° flip; vectors point in opposite direction. Rotation axis is another CS basis vector.
					$rotationAxis destroy
					set rotationAxis [[$csFromCopy w] get_copy]
				} else {
					# uFrom already points in direction of uTo.
				}
			}

			if { [$rotationAxis length] > 0 } {
				set rotationAngle [$uFrom angle $uTo]
				if { $rotationAngle != 0 } {
					my rotate_around_pivot_point $rotationAxis $rotationAngle [$csToCopy center]
				}
			}

			# Clean up:
			$rotationAxis destroy
			$csFromCopy destroy
			$csToCopy destroy
		}

		method change_reference_frame { csFrom csTo } {
			# Move this coordinate system from the csFrom reference frame
			# to the csTo reference frame. Result will be in terms of csTo.

			# Rotate basis vectors into csTo:
			set R [::ctsimu::basis_transform_matrix $csFrom $csTo]; # rotation matrix
			$_u transform_by_matrix $R
			$_v transform_by_matrix $R
			$_w transform_by_matrix $R
			$R destroy

			# Move center point from 'csFrom' to 'csTo':
			set new_center_in_from [::ctsimu::change_reference_frame_of_point [my center] $csFrom $csTo]
			$_center copy $new_center_in_from
			$new_center_in_from destroy
		}

		method deviate { deviation stage { frame 0 } { nFrames 1 } { only_known_to_reconstruction 0 } } {
			# Apply a ::ctsimu::deviation to this coordinate system.
			# The function arguments are:
			# - deviation:
			#   A ::ctsimu::deviation object.
			# - stage:
			#	A ::ctsimu::coordinate_system that defines the stage CS.
			#   Can be `$::ctsimu::world` when this coordinate system is
			#   not attached to the stage.
			# - frame: (default 0)
			#   Number of frame for which the deviation shall be applied,
			#   because deviations can be subject to drift.
			# - nFrames: (default 1)
			#   Total number of frames in scan.
			# - only_known_to_reconstruction: (default 0)
			#   Pass 1 if the known_to_reconstruction JSON parameter must be obeyed,
			#   so only deviations that are known to the reconstruction software
			#   will be handled. Other deviations will be ignored.
			
			set known_to_recon [$deviation known_to_reconstruction]
			if { ($only_known_to_reconstruction==0) || ($known_to_recon==1) } {
				set value [[$deviation amount] get_value_for_frame $frame $nFrames $only_known_to_reconstruction]
				::ctsimu::info "Apply deviation for [my name] by $value"
				
				if { [$deviation type] == "translation" } {
					if { [$deviation native_unit] == "mm" } {
						if { [my is_attached_to_stage] == 0} {
							# Object in world coordinate system.
							# --------------------------------------
							# The deviation axis can undergo drifts and could
							# be expressed in any coordinate system (world, local, sample).
							# Therefore, the axis is a ::ctsimu::scenevector, which can
							# give us the translation vector for the current frame:
							set translation_axis [[$deviation axis] in_world "direction" \
									[self object] $::ctsimu::world \
									$frame $nFrames $only_known_to_reconstruction]
									
							my translate_along_axis $translation_axis $value
							
							$translation_axis destroy
						} else {
							# Object is in stage coordinate system.
							# --------------------------------------
							set translation_axis [[$deviation axis] in_local "direction" \
									$stage [self object] \
									$frame $nFrames $only_known_to_reconstruction]
									
							my translate_along_axis $translation_axis $value
							
							$translation_axis destroy
						}
					} else {
						::ctsimu::fail "All translational deviations must be given in units of length (e.g., \"mm\")."
					}
				} elseif { [$deviation type] == "rotation" } {
					if { [$deviation native_unit] == "rad" } {
						if { [my is_attached_to_stage] == 0 } {
							# Object in world coordinate system.
							# --------------------------------------
							set rotation_axis [[$deviation axis] in_world "direction" \
									[self object] $::ctsimu::world $frame $nFrames $only_known_to_reconstruction]
							set pivot_point [[$deviation pivot] in_world "point" \
									[self object] $::ctsimu::world $frame $nFrames $only_known_to_reconstruction]

							::ctsimu::info "Pivot Reference: [[$deviation pivot] print]"
							::ctsimu::info "Pivot point in World: [$pivot_point print]"
									
							my rotate_around_pivot_point $rotation_axis $value $pivot_point
							
							$rotation_axis destroy
							$pivot_point destroy								
						} else {
							# Object is in stage coordinate system.
							# --------------------------------------
							set rotation_axis [[$deviation axis] in_local "direction" \
									$stage [self object] \
									$frame $nFrames $only_known_to_reconstruction]
							set pivot_point [[$deviation pivot] in_local "point" \
									$stage [self object] \
									$frame $nFrames $only_known_to_reconstruction]
									
							my rotate_around_pivot_point $rotation_axis $value $pivot_point
							
							$rotation_axis destroy
							$pivot_point destroy	
						}
					} else {
						::ctsimu::fail "All rotational deviations must be given in units of angles (e.g., \"rad\")."
					}
				}
			}
		}
	}



	proc basis_transform_matrix { csFrom csTo {m4x4 0} } {
		# Transformation matrix to transform point coordinates from
		# csFrom to csTo, assuming both coordinate systems share a
		# common point of origin.
		# If m4x4 is set to 1, a 4x4 matrix will be returned
		# instead of a 3x3 matrix.

		set from_u [$csFrom u]
		set from_v [$csFrom v]
		set from_w [$csFrom w]

		set to_u [$csTo u]
		set to_v [$csTo v]
		set to_w [$csTo w]

		# Create a 3x3 transformation matrix:
		set T [::ctsimu::matrix new 3 3]

		# Row 0:
		$T set_element 0 0 [$to_u dot $from_u]
		$T set_element 1 0 [$to_u dot $from_v]
		$T set_element 2 0 [$to_u dot $from_w]

		# Row 1:
		$T set_element 0 1 [$to_v dot $from_u]
		$T set_element 1 1 [$to_v dot $from_v]
		$T set_element 2 1 [$to_v dot $from_w]

		# Row 2:
		$T set_element 0 2 [$to_w dot $from_u]
		$T set_element 1 2 [$to_w dot $from_v]
		$T set_element 2 2 [$to_w dot $from_w]

		# Make a 4x4 matrix if necessary:
		if {$m4x4 != 0} {
			$T add_row [::ctsimu::vector new [list 0 0 0]]
			$T add_col [::ctsimu::vector new [list 0 0 0 1]]
		}

		return $T
	}
	
	proc change_reference_frame_of_direction { vec csFrom csTo } {
		# Returns the direction of vector `vec`, given in `csFrom`,
		# in terms of `csTo` (simple multiplication with the basis transform matrix).
		# `csFrom` and `csTo` must be in the same reference coordinate system.

		# Rotation matrix to rotate base vectors into csTo:
		set R [::ctsimu::basis_transform_matrix $csFrom $csTo]

		# Perform rotation:
		set vecInTo [$R multiply_vector $vec]
		$R destroy

		return $vecInTo
	}

	proc change_reference_frame_of_point { point csFrom csTo } {
		# Return point's coordinates, given in csFrom, in terms of csTo.
		# csFrom and csTo must be in the same reference coordinate system.

		# Place the point in the common reference coordinate system
		# (mathematically, this is always the 'world'):
		set point_in_to [$point get_copy]
		set R_to_world [::ctsimu::basis_transform_matrix $csFrom $::ctsimu::world]
		$point_in_to transform_by_matrix $R_to_world
		$point_in_to add [$csFrom center]

		# Move point to the target coordinate system:
		$point_in_to subtract [$csTo center]
		set R_to_to [::ctsimu::basis_transform_matrix $::ctsimu::world $csTo]
		$point_in_to transform_by_matrix $R_to_to

		$R_to_world destroy
		$R_to_to destroy

		return $point_in_to
	}

	variable world
	set world [::ctsimu::coordinate_system new "World"]
	$world reset
}