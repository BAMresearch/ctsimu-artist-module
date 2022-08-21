package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_parameter.tcl]

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create coordinate_system {
		constructor { } {
			# Define center and direction vectors u, v, w and initialize to world coordinate system.
			my variable _center _u _v _w _attachedToStage

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
			my variable _center _u _v _w _attachedToStage

			$_center set_values [list 0 0 0]
			$_u      set_values [list 1 0 0]
			$_v      set_values [list 0 1 0]
			$_w      set_values [list 0 0 1]

			set _attachedToStage 0; # for now, this is not a sub-coordinate system of the sample stage.
		}

		method print { } {
			my variable _center _u _v _w

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

		method get_copy { } {
			# Return a copy of this coordinate system.
			my variable _center _u _v _w
			set C [::ctsimu::coordinate_system new]

			$C setCenter [$_center get_copy]
			$C setu      [$_u get_copy]
			$C setv      [$_v get_copy]
			$C set_w     [$_w get_copy]

			return $C
		}

		method center { } {
			my variable _center
			return $_center
		}

		method setCenter { c } {
			my variable _center
			$_center destroy
			set _center $c
		}

		method u { } {
			my variable _u
			return $_u
		}

		method setu { u } {
			my variable _u
			$_u destroy
			set _u $u
		}

		method v { } {
			my variable _v
			return $_v
		}

		method setv { v } {
			my variable _v
			$_v destroy
			set _v $v
		}

		method w { } {
			my variable _w
			return $_w
		}

		method set_w { w } {
			my variable _w
			$_w destroy
			set _w $w
		}

		method is_attached_to_stage { } {
			# Return the 'attached to stage' property.
			my variable _attachedToStage
			return $_attachedToStage
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
			my variable _attachedToStage
			set _attachedToStage $attached
		}

		method make_unit_coordinate_system { } {
			# Make coordinate system base unit vectors.
			my variable _u _v _w
			$_u to_unit_vector
			$_v to_unit_vector
			$_w to_unit_vector
		}

		method translate { vec } {
			# Shift center by vector.
			my variable _center
			$_center add $vec
		}

		method translate_x { dx } {
			# Translate coordinate system in x direction by amount dx.
			set t [::ctsimu::vector new [list $dx 0 0]]; # new translation vector
			my translate $t
		}

		method translate_y { dy } {
			# Translate coordinate system in y direction by amount dy.
			set t [::ctsimu::vector new [list 0 $dy 0]]; # new translation vector
			my translate $t
		}

		method translate_z { dz } {
			# Translate coordinate system in z direction by amount dz.
			set t [::ctsimu::vector new [list 0 0 $dz]]; # new translation vector
			my translate $t
		}

		method rotate_around_u { angle_in_rad } {
			# Rotate coordinate system around u axis by angle.
			my variable _u _v _w

			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $_u $angle_in_rad]
				$_v transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_v { angle_in_rad } {
			# Rotate coordinate system around v axis by angle.
			my variable _u _v _w

			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $_v $angle_in_rad]
				$_u transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_w { angle_in_rad } {
			# Rotate coordinate system around w axis by angle.
			my variable _u _v _w

			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $_w $angle_in_rad]
				$_u transform_by_matrix $R
				$_v transform_by_matrix $R
				$R destroy
			}
		}

		method rotate { axis angle_in_rad } {
			# Rotate coordinate system around axis by angle.
			my variable _u _v _w

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
			# Generally, this will result in a different center position.
			my variable _center

			# Move coordinate system such that pivot point is at world origin:
			$_center subtract $pivot_point

			# Rotate center point and transform back into world coordinate system:
			$_center rotate $axis $angle_in_rad
			$_center add $pivot_point

			# Rotate the coordinate system itself:
			my rotate $axis $angle_in_rad
		}

		method transform { csFrom csTo } {
			# Relative transformation in world coordinates
			# from csFrom to csTo, result will be in world coordinates.

			set t [[$csFrom center] to [$csTo center]]
			my translate $t
			$t destroy

			# -- ROTATIONS
			# Rotation to bring w axis from -> to
			set wFrom [$csFrom w]
			set wTo   [$csTo w]
			set rotationAxis [$wFrom cross $wTo]
			
			if { [$rotationAxis length] == 0 } {
				if { [$wTo dot $wFrom] < 0 } {
					# 180° flip; vectors point in opposite direction. Rotation axis is another CS basis vector.
					$rotationAxis destroy
					set rotationAxis [[$csFrom u] get_copy]
				} else {
					# wFrom already points in direction of wTo.
				}
			}

			if { [$rotationAxis length] > 0 } {
				set rotationAngle [$wFrom angle $wTo]
				if { $rotationAngle != 0 } {
					my rotate_around_pivot_point $rotationAxis $rotationAngle [$csTo center]

					# Also rotate the csFrom to make calculation of rotation around u axis possible (next step):
					$csFrom rotate $rotationAxis $rotationAngle
				}
			}

			# Rotation to bring u axis from -> to (around now fixed w axis)
			set uFrom [$csFrom u]
			set uTo   [$csTo u]

			set rotationAxis [$uFrom cross $uTo]
			if { [$rotationAxis length] == 0 } {
				if { [$uTo dot $uFrom] < 0 } {
					# 180° flip; vectors point in opposite direction. Rotation axis is another CS basis vector.
					$rotationAxis destroy
					set rotationAxis [[$csFrom w] get_copy]
				} else {
					# uFrom already points in direction of uTo.
				}
			}

			if { [$rotationAxis length] > 0 } {
				set rotationAngle [$uFrom angle $uTo]
				if { $rotationAngle != 0 } {
					my rotate_around_pivot_point $rotationAxis $rotationAngle [$csTo center]
				}
			}
		}

		method change_reference_frame { csFrom csTo } {
			# Transform a coordinate system from the csFrom reference frame
			# to the csTo reference frame. Result will be in terms of csTo.

			my variable _center _u _v _w

			# Rotate basis vectors into csTo:
			set R [::ctsimu::basis_transform_matrix $csFrom $csTo]; # rotation matrix
			$_u transform_by_matrix $R
			$_v transform_by_matrix $R
			$_w transform_by_matrix $R

			# Move center to csTo:
			# Calculate translation vector that moves the 'to' center to the origin of 'from':
			set translation_centerTo_to_centerFrom [[$csTo center] to [$csFrom center]]

			# Calculate position of 'my' center as seen from 'from' if 'to' were at 'from's origin:
			set new_center_in_from [[my center] to $translation_centerTo_to_centerFrom]

			# Rotate 'my' center into csTo and thus make it 'my' new center:
			set _center   [$R multiply_vector $new_center_in_from]

			$R destroy
			$translation_centerTo_to_centerFrom destroy
			$new_center_in_from destroy
		}

		method make_from_vectors { center u w attached } {
			my setCenter $center
			my setu      $u
			my set_w     $w
			my setv      [$w cross $u]

			my attach_to_stage $attached
		}

		method make { cx cy cz ux uy uz wx wy wz attached } {
			set c [::ctsimu::vector new [list $cx $cy $cz]]
			set u [::ctsimu::vector new [list $ux $uy $uz]]
			set w [::ctsimu::vector new [list $wx $wy $wz]]

			my make_from_vectors $c $u $w $attached
		}

		method set_up_from_json_geometry { geometry world stage { obeyKnownToReconstruction 0 } } {
			my variable _center _u _v _w
			my reset

			set known_to_recon 0

			# If object is placed in world coordinate system:
			if {[json exists $geometry centre x] && [json exists $geometry centre y] && [json exists $geometry centre z]} {
				# Object is in world coordinate system:
				my attach_to_stage 0

				# Position
				$_center set_x [::ctsimu::in_mm [json extract $geometry centre x]]
				$_center set_y [::ctsimu::in_mm [json extract $geometry centre y]]
				$_center set_z [::ctsimu::in_mm [json extract $geometry centre z]]

				# Orientation
				if {[json exists $geometry vector_u x] && [json exists $geometry vector_u y] && [json exists $geometry vector_u z] && [json exists $geometry vector_w x] && [json exists $geometry vector_w y] && [json exists $geometry vector_w z]} {
					$_u set_x [json get $geometry vector_u x]
					$_u set_y [json get $geometry vector_u y]
					$_u set_z [json get $geometry vector_u z]
					$_w set_x [json get $geometry vector_w x]
					$_w set_y [json get $geometry vector_w y]
					$_w set_z [json get $geometry vector_w z]
				} elseif {[json exists $geometry vector_r x] && [json exists $geometry vector_r y] && [json exists $geometry vector_r z] && [json exists $geometry vector_t x] && [json exists $geometry vector_t y] && [json exists $geometry vector_t z]} {
					$_u set_x [json get $geometry vector_r x]
					$_u set_y [json get $geometry vector_r y]
					$_u set_z [json get $geometry vector_r z]
					$_w set_x [json get $geometry vector_t x]
					$_w set_y [json get $geometry vector_t y]
					$_w set_z [json get $geometry vector_t z]
				} else {
					fail "Object $object is put in world coordinate system, but the vectors u and w (or r and t, for samples) are not properly defined (each with an x, y and z component)."
					return
				}

				# Deviations in Position (before file format version 0.9)
				if {[json exists $geometry deviation position x]} {
					set devPosX [::ctsimu::in_mm [json extract $geometry deviation position x]]}

				if {[json exists $geometry deviation position y]} {
					set devPosY [::ctsimu::in_mm [json extract $geometry deviation position y]]}

				if {[json exists $geometry deviation position z]} {
					set devPosZ [::ctsimu::in_mm [json extract $geometry deviation position z]]}

				if {[json exists $geometry deviation position u value] || [json exists $geometry deviation position v value] || [json exists $geometry deviation position w value]} {
					fail "Object $object: Positional deviations u, v, w not allowed for a sample that is fixed to the world coordinate system. "
					return
				}
			} elseif {[json exists $geometry centre u] && [json exists $geometry centre v] && [json exists $geometry centre w]} {
				# Object is in stage coordinate system:
				my attach_to_stage 1

				# Position
				$_center set_x [::ctsimu::in_mm [json extract $geometry centre u]]
				$_center set_y [::ctsimu::in_mm [json extract $geometry centre v]]
				$_center set_z [::ctsimu::in_mm [json extract $geometry centre w]]

				# Orientation
				if {[json exists $geometry vector_r u] && [json exists $geometry vector_r v] && [json exists $geometry vector_r w] && [json exists $geometry vector_t u] && [json exists $geometry vector_t v] && [json exists $geometry vector_t w]} {
					$_u set_x [json get $geometry vector_r u]
					$_u set_y [json get $geometry vector_r v]
					$_u set_z [json get $geometry vector_r w]
					$_w set_x [json get $geometry vector_t u]
					$_w set_y [json get $geometry vector_t v]
					$_w set_z [json get $geometry vector_t w]
				} else {
					fail "Object $object is placed in stage coordinate system, but the vectors r and t are not properly defined (each with an u, v and w component)."
					return
				}

				# Deviations in Position (before file format version 0.9)
				if {[json exists $geometry deviation position u]} {
					set devPosX [::ctsimu::in_mm [json extract $geometry deviation position u]]}

				if {[json exists $geometry deviation position v]} {
					set devPosY [::ctsimu::in_mm [json extract $geometry deviation position v]]}

				if {[json exists $geometry deviation position w]} {
					set devPosZ [::ctsimu::in_mm [json extract $geometry deviation position w]]}

				if {[json exists $geometry deviation position x] || [json exists $geometry deviation position y] || [json exists $geometry deviation position z]} {
					fail "Object $object: Positional deviations x, y, z not allowed for a sample that is placed in the stage coordinate system."
					return
				}
			}

			$_u to_unit_vector
			$_w to_unit_vector
			$_v destroy
			set _v [$_w cross $_u]
			$_v to_unit_vector

			# Prior to file format 0.9:
			if {[json exists $geometry deviation known_to_reconstruction]} {
				set known_to_recon [::ctsimu::from_bool [json extract $geometry deviation known_to_reconstruction]]
			}

			# Starting with file format 0.9:
			if {[json exists $geometry rotation known_to_reconstruction]} {
				set known_to_recon [::ctsimu::from_bool [json extract $geometry rotation known_to_reconstruction]]
			}

			# Apply deviations in position:
			if { ($obeyKnownToReconstruction==0) || ($known_to_recon==1) } {
				$_center set_x [expr [$_center x] + $devPosX]
				$_center set_y [expr [$_center y] + $devPosY]
				$_center set_z [expr [$_center z] + $devPosZ]
			}

			if { [my is_attached_to_stage] == 1 } {
				# Move object to stage coordinate system:
				my transform $world $stage
			}

			# Rotational deviations:
			if { ($obeyKnownToReconstruction == 0) || ($known_to_recon == 1) } {
				# Deviations in rotation (for source, stage, detector, before file format version 0.9):
				if {[json exists $geometry deviation rotation u]} {
					set devRotU [::ctsimu::in_rad [json extract $geometry deviation rotation u]]}

				if {[json exists $geometry deviation rotation v]} {
					set devRotV [::ctsimu::in_rad [json extract $geometry deviation rotation v]]}

				if {[json exists $geometry deviation rotation w]} {
					set devRotW [::ctsimu::in_rad [json extract $geometry deviation rotation w]]}

				# Deviations in Rotation (for samples):
				if {[json exists $geometry deviation rotation r]} {
					set devRotU [::ctsimu::in_rad [json extract $geometry deviation rotation r]]}

				if {[json exists $geometry deviation rotation s]} {
					set devRotV [::ctsimu::in_rad [json extract $geometry deviation rotation s]]}

				if {[json exists $geometry deviation rotation t]} {
					set devRotW [::ctsimu::in_rad [json extract $geometry deviation rotation t]]}


				# Deviations in rotation (for source, stage, detector, starting with file format version 0.9):
				if {[json exists $geometry rotation u]} {
					set devRotU [::ctsimu::in_rad [json extract $geometry rotation u]]}

				if {[json exists $geometry rotation v]} {
					set devRotV [::ctsimu::in_rad [json extract $geometry rotation v]]}

				if {[json exists $geometry rotation w]} {
					set devRotW [::ctsimu::in_rad [json extract $geometry rotation w]]}

				# Deviations in Rotation (for samples):
				if {[json exists $geometry rotation r]} {
					set devRotU [::ctsimu::in_rad [json extract $geometry rotation r]]}

				if {[json exists $geometry rotation s]} {
					set devRotV [::ctsimu::in_rad [json extract $geometry rotation s]]}

				if {[json exists $geometry rotation t]} {
					set devRotW [::ctsimu::in_rad [json extract $geometry rotation t]]}


				# Apply rotations:

				# Rotations around w (or sample t) axis:
				$_u rotate $_w $devRotW
				$_v rotate $_w $devRotW

				# Rotations around v (or sample s) axis:
				$_u rotate $_v $devRotV
				$_w rotate $_v $devRotV
				
				# Rotations around u (or sample r) axis:
				$_v rotate $_u $devRotU
				$_w rotate $_u $devRotU
			}
		}
	}



	proc basis_transform_matrix { csFrom csTo {m4x4 0} } {
		# Transformation matrix to transform point coordinates from csFrom to csTo.
		# If m4x4 is set to 1, a 4x4 matrix will be returned instead of a 3x3 matrix.

		set from_u [$csFrom u]
		set from_v [$csFrom v]
		set from_w [$csFrom w]

		set to_u [$csTo u]
		set to_v [$csTo v]
		set to_w [$csTo w]

		# Create a 3x3 transformation matrix:
		set T [::ctsimu::matrix 3 3]

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

	proc change_reference_frame_of_point { point csFrom csTo } {
		# Return point's coordinates, given in csFrom, in terms of csTo.

		# Rotation matrix to rotate base vectors into csTo:
		set R [basis_transform_matrix $csFrom $csTo]

		# Move center to csTo:
		# Calculate translation vector that moves the 'to' center to the origin of 'from':
		set translation_centerTo_to_centerFrom [[$csTo center] to [$csFrom center]]

		# Calculate position of 'point' center as seen from 'from' if 'to' were at 'from's origin:
		set new_center_in_from [[$point center] to $translation_centerTo_to_centerFrom]

		# Rotate 'my' center into csTo and thus make it 'my' new center:
		set pointInTo [$R multiply_vector $new_center_in_from]

		return $pointInTo
	}
}