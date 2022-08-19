package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_parameter.tcl]

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create coordinate_system {
		constructor { } {
			# Define center and direction vectors u, v, w and initialize to world coordinate system.
			my variable center u v w attachedToStage

			set center [::ctsimu::vector new]
			set u      [::ctsimu::vector new]
			set v      [::ctsimu::vector new]
			set w      [::ctsimu::vector new]
		}

		destructor {
			$center destroy
			$u destroy
			$v destroy
			$w destroy
		}

		method reset { } {
			my variable center u v w attachedToStage

			$center setValues [list 0 0 0]
			$u      setValues [list 1 0 0]
			$v      setValues [list 0 1 0]
			$w      setValues [list 0 0 1]

			set attachedToStage 0; # for now, this is not a sub-coordinate system of the sample stage.
		}

		method print { } {
			my variable center u v w

			set s "Center: "
			append s [$center print]

			append s "\nu: "
			append s [$u print]

			append s "\nv: "
			append s [$v print]

			append s "\nw: "
			append s [$w print]

			return $s
		}

		method getCopy { } {
			# Return a copy of this coordinate system.
			my variable center u v w
			set C [::ctsimu::coordinate_system new]

			$C setCenter [$center getCopy]
			$C setu      [$u getCopy]
			$C setv      [$v getCopy]
			$C setw      [$w getCopy]

			return $C
		}

		method center { } {
			my variable center
			return $center
		}

		method setCenter { c } {
			my variable center
			$center destroy
			set $center $c
		}

		method u { } {
			my variable u
			return $u
		}

		method setu { _u } {
			my variable u
			$u destroy
			set $u $_u
		}

		method v { } {
			my variable v
			return $v
		}

		method setv { _v } {
			my variable v
			$v destroy
			set $v $_v
		}

		method w { } {
			my variable w
			return $w
		}

		method setw { _w } {
			my variable w
			$w destroy
			set $w $_w
		}

		method isAttachedToStage { } {
			# Return the 'attached to stage' property.
			my variable attachedToStage
			return $attachedToStage
		}

		method attachToStage { attached } {
			# 0: not attached, 1: attached to stage.
			my variable attachedToStage
			set attachedToStage $attached
		}

		method makeUnitCoordinateSystem { } {
			# Make coordinate system base unit vectors.
			my variable u v w
			$u toUnitVector
			$v toUnitVector
			$w toUnitVector
		}

		method translate { vec } {
			# Shift center by vector.
			my variable center
			$center add $vec
		}

		method translateX { dx } {
			# Translate coordinate system in x direction by amount dx.
			set t [::ctsimu::vector new [list $dx 0 0]]; # new translation vector
			my translate $t
		}

		method translateY { dy } {
			# Translate coordinate system in x direction by amount dy.
			set t [::ctsimu::vector new [list 0 $dy 0]]; # new translation vector
			my translate $t
		}

		method translateZ { dz } {
			# Translate coordinate system in x direction by amount dz.
			set t [::ctsimu::vector new [list 0 0 $dz]]; # new translation vector
			my translate $t
		}

		method rotateAroundU { angleInRad } {
			# Rotate coordinate system around u axis by angle.
			my variable u v w

			if {$angleInRad != 0} {
				set R [::ctsimu::rotationMatrix $u $angleInRad]
				$v transform_by_matrix $R
				$w transform_by_matrix $R
				$R destroy
			}
		}

		method rotateAroundV { angleInRad } {
			# Rotate coordinate system around v axis by angle.
			my variable u v w

			if {$angleInRad != 0} {
				set R [::ctsimu::rotationMatrix $v $angleInRad]
				$u transform_by_matrix $R
				$w transform_by_matrix $R
				$R destroy
			}
		}

		method rotateAroundW { angleInRad } {
			# Rotate coordinate system around w axis by angle.
			my variable u v w

			if {$angleInRad != 0} {
				set R [::ctsimu::rotationMatrix $w $angleInRad]
				$u transform_by_matrix $R
				$v transform_by_matrix $R
				$R destroy
			}
		}

		method rotate { axis angleInRad } {
			# Rotate coordinate system around axis by angle.
			my variable u v w

			if {$angleInRad != 0} {
				set R [::ctsimu::rotationMatrix $axis $angleInRad]
				$u transform_by_matrix $R
				$v transform_by_matrix $R
				$w transform_by_matrix $R
				$R destroy
			}
		}

		method rotateAroundPivotPoint { axis angleInRad pivotPoint } {
			# Rotate coordinate system around a pivot point. This will result in a different center position.
			my variable center

			# Move coordinate system such that pivot point is at world origin:
			$center subtract $pivotPoint

			# Rotate center point and transform back into world coordinate system:
			$center rotate $axis $angleInRad
			$center add $pivotPoint

			# Rotate the coordinate system itself:
			my rotate $axis $angleInRad
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
					set rotationAxis [[$csFrom u] getCopy]
				} else {
					# wFrom already points in direction of wTo.
				}
			}

			if { [$rotationAxis length] > 0 } {
				set rotationAngle [$wFrom angle $wTo]
				if { $rotationAngle != 0 } {
					my rotateAroundPivotPoint $rotationAxis $rotationAngle [$csTo center]

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
					set rotationAxis [[$csFrom w] getCopy]
				} else {
					# uFrom already points in direction of uTo.
				}
			}

			if { [$rotationAxis length] > 0 } {
				set rotationAngle [$uFrom angle $uTo]
				if { $rotationAngle != 0 } {
					my rotateAroundPivotPoint $rotationAxis $rotationAngle [$csTo center]
				}
			}
		}

		method changeReferenceFrame { csFrom csTo } {
			# Transform a coordinate system from the csFrom reference frame
			# to the csTo reference frame. Result will be in terms of csTo.

			my variable center u v w

			# Rotate basis vectors into csTo:
			set R [::ctsimu::basisTransformMatrix $csFrom $csTo]; # rotation matrix
			$u transform_by_matrix $R
			$v transform_by_matrix $R
			$w transform_by_matrix $R

			# Move center to csTo:
			# Calculate translation vector that moves the 'to' center to the origin of 'from':
			set translation_centerTo_to_centerFrom [[$csTo center] to [$csFrom center]]

			# Calculate position of 'my' center as seen from 'from' if 'to' were at 'from's origin:
			set new_center_in_from [[my center] to $translation_centerTo_to_centerFrom]

			# Rotate 'my' center into csTo and thus make it 'my' new center:
			set center   [$R multiplyVector $new_center_in_from]

			$R destroy
			$translation_centerTo_to_centerFrom destroy
			$new_center_in_from destroy
		}

		method make_from_vectors { _c _u _w _attached } {
			my setCenter $_c
			my setu      $_u
			my setw      $_w
			my setv      [$_w cross $_u]

			my attachToStage $_attached
		}

		method make { cx cy cz ux uy uz wx wy wz _attached } {
			set _c [::ctsimu::vector new [list $cx $cy $cz]]
			set _u [::ctsimu::vector new [list $ux $uy $uz]]
			set _w [::ctsimu::vector new [list $wx $wy $wz]]

			my make_from_vectors $_c $_u $_w $_attached
		}

		method setupFromJSONgeometry { geometry world stage { obeyKnownToReconstruction 0 } } {
			my variable center u v w
			my reset

			set known_to_recon 0

			# If object is placed in world coordinate system:
			if {[json exists $geometry centre x] && [json exists $geometry centre y] && [json exists $geometry centre z]} {
				# Object is in world coordinate system:
				my attachToStage 0

				# Position
				$center setx [::ctsimu::in_mm [json extract $geometry centre x]]
				$center sety [::ctsimu::in_mm [json extract $geometry centre y]]
				$center setz [::ctsimu::in_mm [json extract $geometry centre z]]

				# Orientation
				if {[json exists $geometry vector_u x] && [json exists $geometry vector_u y] && [json exists $geometry vector_u z] && [json exists $geometry vector_w x] && [json exists $geometry vector_w y] && [json exists $geometry vector_w z]} {
					$u setx [json get $geometry vector_u x]
					$u sety [json get $geometry vector_u y]
					$u setz [json get $geometry vector_u z]
					$w setx [json get $geometry vector_w x]
					$w sety [json get $geometry vector_w y]
					$w setz [json get $geometry vector_w z]
				} elseif {[json exists $geometry vector_r x] && [json exists $geometry vector_r y] && [json exists $geometry vector_r z] && [json exists $geometry vector_t x] && [json exists $geometry vector_t y] && [json exists $geometry vector_t z]} {
					$u setx [json get $geometry vector_r x]
					$u sety [json get $geometry vector_r y]
					$u setz [json get $geometry vector_r z]
					$w setx [json get $geometry vector_t x]
					$w sety [json get $geometry vector_t y]
					$w setz [json get $geometry vector_t z]
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
				my attachToStage 1

				# Position
				$center setx [::ctsimu::in_mm [json extract $geometry centre u]]
				$center sety [::ctsimu::in_mm [json extract $geometry centre v]]
				$center setz [::ctsimu::in_mm [json extract $geometry centre w]]

				# Orientation
				if {[json exists $geometry vector_r u] && [json exists $geometry vector_r v] && [json exists $geometry vector_r w] && [json exists $geometry vector_t u] && [json exists $geometry vector_t v] && [json exists $geometry vector_t w]} {
					$u setx [json get $geometry vector_r u]
					$u sety [json get $geometry vector_r v]
					$u setz [json get $geometry vector_r w]
					$w setx [json get $geometry vector_t u]
					$w sety [json get $geometry vector_t v]
					$w setz [json get $geometry vector_t w]
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

			$u toUnitVector
			$w toUnitVector
			$v destroy
			set v [$w cross $u]
			$v toUnitVector

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
				$center setx [expr [$center x] + $devPosX]
				$center sety [expr [$center y] + $devPosY]
				$center setz [expr [$center z] + $devPosZ]
			}

			if { [my isAttachedToStage] == 1 } {
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
				$u rotate $w $devRotW
				$v rotate $w $devRotW

				# Rotations around v (or sample s) axis:
				$u rotate $v $devRotV
				$w rotate $v $devRotV
				
				# Rotations around u (or sample r) axis:
				$v rotate $u $devRotU
				$w rotate $u $devRotU
			}
		}
	}

	proc basisTransformMatrix { csFrom csTo {m4x4 0} } {
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
		$T setElement 0 0 [$to_u dot $from_u]
		$T setElement 1 0 [$to_u dot $from_v]
		$T setElement 2 0 [$to_u dot $from_w]

		# Row 1:
		$T setElement 0 1 [$to_v dot $from_u]
		$T setElement 1 1 [$to_v dot $from_v]
		$T setElement 2 1 [$to_v dot $from_w]

		# Row 2:
		$T setElement 0 2 [$to_w dot $from_u]
		$T setElement 1 2 [$to_w dot $from_v]
		$T setElement 2 2 [$to_w dot $from_w]

		# Make a 4x4 matrix if necessary:
		if {$m4x4 != 0} {
			$T addRow [::ctsimu::vector new [list 0 0 0]]
			$T addCol [::ctsimu::vector new [list 0 0 0 1]]
		}

		return $T
	}

	proc pointChangeReferenceFrame { point csFrom csTo } {
		# Return point's coordinates, given in csFrom, in terms of csTo.

		# Rotation matrix to rotate base vectors into csTo:
		set R [basisTransformMatrix $csFrom $csTo]

		# Move center to csTo:
		# Calculate translation vector that moves the 'to' center to the origin of 'from':
		set translation_centerTo_to_centerFrom [[$csTo center] to [$csFrom center]]

		# Calculate position of 'point' center as seen from 'from' if 'to' were at 'from's origin:
		set new_center_in_from [[$point center] to $translation_centerTo_to_centerFrom]

		# Rotate 'my' center into csTo and thus make it 'my' new center:
		set pointInTo [$R multiplyVector $new_center_in_from]

		return $pointInTo
	}
}