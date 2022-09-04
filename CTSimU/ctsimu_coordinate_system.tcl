package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_deviation.tcl]

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create coordinate_system {
		constructor { { name "" } } {
			# Define center and direction vectors u, v, w and initialize to world coordinate system.
			my variable _name _center _u _v _w _attachedToStage

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
			my variable _center _u _v _w _attachedToStage

			$_center set_values [list 0 0 0]
			$_u      set_values [list 1 0 0]
			$_v      set_values [list 0 1 0]
			$_w      set_values [list 0 0 1]

			my attach_to_stage 0; # For now, this is not a sub-coordinate system of the sample stage.
		}

		method print { } {
			# Generates a human-readable info string.
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

		method make_unit_coordinate_system { } {
			# Make coordinate system base unit vectors.
			my variable _u _v _w
			$_u to_unit_vector
			$_v to_unit_vector
			$_w to_unit_vector
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
			my variable _center _u _v _w
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
			my variable _name
			return $_name
		}

		method center { } {
			my variable _center
			return $_center
		}

		method u { } {
			my variable _u
			return $_u
		}

		method v { } {
			my variable _v
			return $_v
		}

		method w { } {
			my variable _w
			return $_w
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
		}

		method set_center { c } {
			my variable _center
			$_center destroy
			set _center $c
		}

		method set_u { u } {
			my variable _u
			$_u destroy
			set _u $u
		}

		method set_v { v } {
			my variable _v
			$_v destroy
			set _v $v
		}

		method set_w { w } {
			my variable _w
			$_w destroy
			set _w $w
		}

		method attach_to_stage { attached } {
			# 0: not attached, 1: attached to stage.
			my variable _attachedToStage
			set _attachedToStage $attached
		}

		# Transformations
		# -------------------------
		method translate { translation_vector } {
			# Shift center by given translation vector.
			my variable _center
			$_center add $translation_vector
		}
		
		method translate_axis { axis distance } {
			# Shift center along `axis` by given `distance`.
			my variable _center
			set t [$axis get_unit_vector]
			$t scale $distance
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
			my variable _u
			my translate_axis $_u du
		}
		
		method translate_v { dv } {
			# Translate coordinate system in v direction by distance dv.
			my variable _v
			my translate_axis $_v dv
		}
		
		method translate_w { dw } {
			# Translate coordinate system in w direction by distance dw.
			my variable _w
			my translate_axis $_w dw
		}
		
		method rotate { axis angle_in_rad } {
			# Rotate coordinate system around the given axis vector
			# by angle_in_rad. This does not move the center point,
			# as the axis vector is assumed to be attached to
			# the center of the coordinate system.
			if {$angle_in_rad != 0} {
				my variable _u _v _w
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

			my variable _center

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
				my variable _u _v _w
				set R [::ctsimu::rotation_matrix $_u $angle_in_rad]
				$_v transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_v { angle_in_rad } {
			# Rotate coordinate system around v axis by angle.
			if {$angle_in_rad != 0} {
				my variable _u _v _w
				set R [::ctsimu::rotation_matrix $_v $angle_in_rad]
				$_u transform_by_matrix $R
				$_w transform_by_matrix $R
				$R destroy
			}
		}

		method rotate_around_w { angle_in_rad } {
			# Rotate coordinate system around w axis by angle.
			if {$angle_in_rad != 0} {
				my variable _u _v _w
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
			# Transform this coordinate system from the csFrom reference frame
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


		
		method deviate { deviation world stage { frame 0 } { nFrames 1 } { only_known_to_reconstruction 0 } } {
			# Apply a ::ctsimu::deviation to this coordinate system.
			# The function arguments are:
			# - deviation:
			#   A ::ctsimu::deviation object.
			# - world:
			#	A ::ctsimu::coordinate_system that defines the world CS.
			# - stage:
			#	A ::ctsimu::coordinate_system that defines the stage CS.
			#   Can be the same as `world` when this coordinate system is
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
				
				if { [$deviation type] == "translation" } {
					if { [$deviation unit] == "mm" } {
						if { [my is_attached_to_stage] == 0} {
							# Object in world coordinate system.
							if { [$deviation axis] == "x" } { my translate_x $value }
							if { [$deviation axis] == "y" } { my translate_y $value }
							if { [$deviation axis] == "z" } { my translate_z $value }
							if { [$deviation axis] == "u" } { my translate_u $value }
							if { [$deviation axis] == "v" } { my translate_v $value }
							if { [$deviation axis] == "w" } { my translate_w $value }
							if { [$deviation axis] == "r" } { my translate_u $value }
							if { [$deviation axis] == "s" } { my translate_v $value }
							if { [$deviation axis] == "t" } { my translate_w $value }
						} else {
							# Object is in stage coordinate system.
							my change_reference_frame $stage $world
							if { [$deviation axis] == "x" } { my translate_x $value }
							if { [$deviation axis] == "y" } { my translate_y $value }
							if { [$deviation axis] == "z" } { my translate_z $value }
							if { [$deviation axis] == "u" } { my translate_axis [$stage u] $value }
							if { [$deviation axis] == "v" } { my translate_axis [$stage v] $value }
							if { [$deviation axis] == "w" } { my translate_axis [$stage w] $value }
							if { [$deviation axis] == "r" } { my translate_u $value }
							if { [$deviation axis] == "s" } { my translate_v $value }
							if { [$deviation axis] == "t" } { my translate_w $value }
							my change_reference_frame $wolrd $stage
						}
					} else {
						error "All translational deviations must be given in units of length (e.g., \"mm\")."
					}
				} elseif { [$deviation type] == "rotation" } {
					if { [$deviation unit] == "rad" } {
						if { [my is_attached_to_stage] == 0} {
							# Object in world coordinate system.
							if { [$deviation axis] == "x" } { my rotate [$world x] $value }
							if { [$deviation axis] == "y" } { my rotate [$world y] $value }
							if { [$deviation axis] == "z" } { my rotate [$world z] $value }
							if { [$deviation axis] == "u" } { my rotate_around_u $value }
							if { [$deviation axis] == "v" } { my rotate_around_v $value }
							if { [$deviation axis] == "w" } { my rotate_around_w $value }
							if { [$deviation axis] == "r" } { my rotate_around_u $value }
							if { [$deviation axis] == "s" } { my rotate_around_v $value }
							if { [$deviation axis] == "t" } { my rotate_around_w $value }
						} else {
							# Object is in stage coordinate system.
							my change_reference_frame $stage $world
							if { [$deviation axis] == "x" } { my rotate [$world x] $value }
							if { [$deviation axis] == "y" } { my rotate [$world y] $value }
							if { [$deviation axis] == "z" } { my rotate [$world z] $value }
							if { [$deviation axis] == "u" } { my rotate [$stage u] $value }
							if { [$deviation axis] == "v" } { my rotate [$stage v] $value }
							if { [$deviation axis] == "w" } { my rotate [$stage w] $value }
							if { [$deviation axis] == "r" } { my rotate_around_u $value }
							if { [$deviation axis] == "s" } { my rotate_around_v $value }
							if { [$deviation axis] == "t" } { my rotate_around_w $value }
							my change_reference_frame $wolrd $stage
						}
					} else {
						error "All rotational deviations must be given in units of angles (e.g., \"rad\")."
					}
				}
			}
		}

		method set_up_from_json_geometry { geometry world stage { only_known_to_reconstruction 0 } } {
			# Set up the geometry from a JSON object.
			# This function is currently not used by the aRTist module,
			# because a ::ctsimu::part keeps track of its
			# position and orientation across frames (including drifts
			# and deviations) and sets up the coordinate systems for each
			# frame using the other setter functions.
			#
			# -> CANDIDATE FOR DELETION.
			# 
			# The function arguments are:
			# - geometry:
			#   A JSON object that contains the geometry definition
			#   for this coordinate system, including rotations, drifts and 
			#   translational deviations (the latter are deprecated in the file format).
			# - world:
			#   A ::ctsimu::coordinate_system that represents the world.
			# - stage:
			#   A ::ctsimu::coordinate_system that represents the stage.
			#   Only necessary if the coordinate system will be attached to the
			#   stage. Otherwise, the world coordinate system can be passed as an 
			#   argument.
			# - only_known_to_reconstruction: (default 0)
			#   Pass 1 if the known_to_reconstruction JSON parameter must be obeyed,
			#   so only deviations that are known to the reconstruction software
			#   will be handled. Other deviations will be ignored.

			my variable _name _center _u _v _w
			my reset

			set known_to_recon 0

			# If object is placed in world coordinate system:
			if {[json exists $geometry centre x] && [json exists $geometry centre y] && [json exists $geometry centre z]} {
				# Object is in world coordinate system:
				my attach_to_stage 0

				# Position
				$_center set_x [::ctsimu::get_value_in_unit "mm" $geometry {centre x}]
				$_center set_y [::ctsimu::get_value_in_unit "mm" $geometry {centre y}]
				$_center set_z [::ctsimu::get_value_in_unit "mm" $geometry {centre z}]

				# Orientation
				if {[json exists $geometry vector_u x] && [json exists $geometry vector_u y] && [json exists $geometry vector_u z] && [json exists $geometry vector_w x] && [json exists $geometry vector_w y] && [json exists $geometry vector_w z]} {
					$_u set_x [::ctsimu::get_value $geometry {vector_u x}]
					$_u set_y [::ctsimu::get_value $geometry {vector_u y}]
					$_u set_z [::ctsimu::get_value $geometry {vector_u z}]
					$_w set_x [::ctsimu::get_value $geometry {vector_w x}]
					$_w set_y [::ctsimu::get_value $geometry {vector_w y}]
					$_w set_z [::ctsimu::get_value $geometry {vector_w z}]
				} elseif {[json exists $geometry vector_r x] && [json exists $geometry vector_r y] && [json exists $geometry vector_r z] && [json exists $geometry vector_t x] && [json exists $geometry vector_t y] && [json exists $geometry vector_t z]} {
					$_u set_x [::ctsimu::get_value $geometry {vector_r x}]
					$_u set_y [::ctsimu::get_value $geometry {vector_r y}]
					$_u set_z [::ctsimu::get_value $geometry {vector_r z}]
					$_w set_x [::ctsimu::get_value $geometry {vector_t x}]
					$_w set_y [::ctsimu::get_value $geometry {vector_t y}]
					$_w set_z [::ctsimu::get_value $geometry {vector_t z}]
				} else {
					error "Coordinate system \'$_name\' is placed in world coordinate system, but its vectors u and w (or r and t, for samples) are not properly defined (each with an x, y and z component)."
					return
				}

				# Deviations in position (before file format version 0.9)
				set devPosX [::ctsimu::get_value_in_unit "mm" $geometry {deviation position x}]
				set devPosY [::ctsimu::get_value_in_unit "mm" $geometry {deviation position y}]
				set devPosZ [::ctsimu::get_value_in_unit "mm" $geometry {deviation position z}]

				if {[json exists $geometry deviation position u value] || [json exists $geometry deviation position v value] || [json exists $geometry deviation position w value]} {
					error "Coordinate system \'$_name\': Positional deviations u, v, w not allowed for a sample that is fixed to the world coordinate system."
					return
				}
			} elseif {[json exists $geometry centre u] && [json exists $geometry centre v] && [json exists $geometry centre w]} {
				# Object is in stage coordinate system:
				my attach_to_stage 1

				# Position
				$_center set_x [::ctsimu::get_value_in_unit "mm" $geometry {centre u}]
				$_center set_y [::ctsimu::get_value_in_unit "mm" $geometry {centre v}]
				$_center set_z [::ctsimu::get_value_in_unit "mm" $geometry {centre w}]

				# Orientation
				if {[json exists $geometry vector_r u] && [json exists $geometry vector_r v] && [json exists $geometry vector_r w] && [json exists $geometry vector_t u] && [json exists $geometry vector_t v] && [json exists $geometry vector_t w]} {
					$_u set_x [::ctsimu::get_value $geometry {vector_r u}]
					$_u set_y [::ctsimu::get_value $geometry {vector_r v}]
					$_u set_z [::ctsimu::get_value $geometry {vector_r w}]
					$_w set_x [::ctsimu::get_value $geometry {vector_t u}]
					$_w set_y [::ctsimu::get_value $geometry {vector_t v}]
					$_w set_z [::ctsimu::get_value $geometry {vector_t w}]
				} else {
					error "Coordinate system \'$_name\' is placed in stage coordinate system, but its vectors r and t are not properly defined (each with a u, v and w component)."
					return
				}

				# Deviations in Position (before file format version 0.9)
				set devPosX [::ctsimu::get_value_in_unit "mm" $geometry {deviation position u}]
				set devPosY [::ctsimu::get_value_in_unit "mm" $geometry {deviation position v}]
				set devPosZ [::ctsimu::get_value_in_unit "mm" $geometry {deviation position w}]

				if {[json exists $geometry deviation position x] || [json exists $geometry deviation position y] || [json exists $geometry deviation position z]} {
					error "Coordinate system \'$_name\': Positional deviations x, y, z not allowed for a sample that is placed in the stage coordinate system."
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
				set known_to_recon [::ctsimu::get_value_in_unit "bool" $geometry {deviation known_to_reconstruction} $known_to_recon]
			}

			# Starting with file format 0.9:
			if {[json exists $geometry rotation known_to_reconstruction]} {
				set known_to_recon [::ctsimu::get_value_in_unit "bool" $geometry {rotation known_to_reconstruction} $known_to_recon]
			}

			# Apply deviations in position:
			if { ($only_known_to_reconstruction==0) || ($known_to_recon==1) } {
				$_center set_x [expr [$_center x] + $devPosX]
				$_center set_y [expr [$_center y] + $devPosY]
				$_center set_z [expr [$_center z] + $devPosZ]
			}

			if { [my is_attached_to_stage] == 1 } {
				# Move object to stage coordinate system:
				my transform $world $stage
			}

			# Rotational deviations:
			if { ($only_known_to_reconstruction == 0) || ($known_to_recon == 1) } {
				# Deviations in rotation (for source, stage, detector, before file format version 0.9):
				if {[json exists $geometry deviation rotation u]} {
					set devRotU [::ctsimu::get_value_in_unit "rad" $geometry {deviation rotation u}]}

				if {[json exists $geometry deviation rotation v]} {
					set devRotV [::ctsimu::get_value_in_unit "rad" $geometry {deviation rotation v}]}

				if {[json exists $geometry deviation rotation w]} {
					set devRotW [::ctsimu::get_value_in_unit "rad" $geometry {deviation rotation w}]}

				# Deviations in Rotation (for samples):
				if {[json exists $geometry deviation rotation r]} {
					set devRotU [::ctsimu::get_value_in_unit "rad" $geometry {deviation rotation r}]}

				if {[json exists $geometry deviation rotation s]} {
					set devRotV [::ctsimu::get_value_in_unit "rad" $geometry {deviation rotation s}]}

				if {[json exists $geometry deviation rotation t]} {
					set devRotW [::ctsimu::get_value_in_unit "rad" $geometry {deviation rotation t}]}


				# Deviations in rotation (for source, stage, detector, starting with file format version 0.9):
				if {[json exists $geometry rotation u]} {
					set devRotU [::ctsimu::get_value_in_unit "rad" $geometry {rotation u}]}

				if {[json exists $geometry rotation v]} {
					set devRotV [::ctsimu::get_value_in_unit "rad" $geometry {rotation v}]}

				if {[json exists $geometry rotation w]} {
					set devRotW [::ctsimu::get_value_in_unit "rad" $geometry {rotation w}]}

				# Deviations in rotation (for samples):
				if {[json exists $geometry rotation r]} {
					set devRotU [::ctsimu::get_value_in_unit "rad" $geometry {rotation r}]}

				if {[json exists $geometry rotation s]} {
					set devRotV [::ctsimu::get_value_in_unit "rad" $geometry {rotation s}]}

				if {[json exists $geometry rotation t]} {
					set devRotW [::ctsimu::get_value_in_unit "rad" $geometry {rotation t}]}


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
		set R [::ctsimu::basis_transform_matrix $csFrom $csTo]

		# Move center to csTo:
		# Calculate translation vector that moves the 'to' center to the origin of 'from':
		set translation_centerTo_to_centerFrom [[$csTo center] to [$csFrom center]]

		# Calculate position of 'point' center as seen from 'from' if 'to' were at 'from's origin:
		set new_center_in_from [[$point center] to $translation_centerTo_to_centerFrom]

		# Rotate 'my' center into csTo and thus make it 'my' new center:
		set pointInTo [$R multiply_vector $new_center_in_from]

		$translation_centerTo_to_centerFrom destroy
		$new_center_in_from destroy
		$R destroy

		return $pointInTo
	}
}