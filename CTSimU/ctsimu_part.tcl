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
		constructor { } {
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

			my variable _rotation_u
			my variable _rotation_v
			my variable _rotation_w

			set _cs_initial [::ctsimu::coordinate_system new];  # frame 0
			set _cs_current [::ctsimu::coordinate_system new];  # current frame

			# Ghost coordinate system to use for the calculation of
			# recon projection matrices. Those only obey drifts 'known_to_reconstruction'.
			set _cs_initial_recon [::ctsimu::coordinate_system new];  # frame 0
			set _cs_current_recon [::ctsimu::coordinate_system new];  # current frame

			# Geometry parameters:
			set _center_x [::ctsimu::parameter new]
			set _center_y [::ctsimu::parameter new]
			set _center_z [::ctsimu::parameter new]

			set _vector_u_x [::ctsimu::parameter new]
			set _vector_u_y [::ctsimu::parameter new]
			set _vector_u_z [::ctsimu::parameter new]

			set _vector_w_x [::ctsimu::parameter new]
			set _vector_w_y [::ctsimu::parameter new]
			set _vector_w_z [::ctsimu::parameter new]

			set _rotation_u [::ctsimu::parameter new]
			set _rotation_v [::ctsimu::parameter new]
			set _rotation_w [::ctsimu::parameter new]
		}

		destructor {
			my variable _cs_initial _cs_current _cs_initial_recon _cs_current_recon

			$_cs_initial destroy
			$_cs_current destroy
			$_cs_initial_recon destroy
			$_cs_current_recon destroy

			$_center_x destroy
			$_center_y destroy
			$_center_z destroy
			$_vector_u_x destroy
			$_vector_u_y destroy
			$_vector_u_z destroy
			$_vector_w_x destroy
			$_vector_w_y destroy
			$_vector_w_z destroy
			$_rotation_u destroy
			$_rotation_v destroy
			$_rotation_w destroy
		}

		method reset { } {
			my variable _cs_initial _cs_current _cs_initial_recon _cs_current_recon

			$_cs_initial reset
			$_cs_current reset
			$_cs_initial_recon reset
			$_cs_current_recon reset
		}

		method set_geometry { jsonGeometry world stage } {
			my variable _cs_initial _cs_initial_recon
			$_cs_initial        set_up_from_json_geometry { $jsonGeometry $world $stage 0 }
			$_cs_initial_recon  set_up_from_json_geometry { $jsonGeometry $world $stage 1 }

			
		}
	}
}