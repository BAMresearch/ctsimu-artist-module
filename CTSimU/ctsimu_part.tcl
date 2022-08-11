package require TclOO
package require rl_json

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_coordinate_system.tcl]

# Parts are objects in the scene: detector, source, stage and samples.
# Each part has its own coordinate system, a parallel "ghost" coordinate system
# for calculating projection matrices for the reconstruction.
# This is necessary because the user is free not to pass any deviations to the
# reconstruction.

namespace eval ::ctsimu {
	namespace import ::rl_json::*

	::oo::class create part {
		constructor { } {
			my variable coordinateSystem_initial;  # frame 0
			my variable coordinateSystem_current;  # current frame

			# Ghost coordinate systems to use for the calculation of
			# recon projection matrices. Those only obey drifts 'known_to_reconstruction'.
			my variable coordinateSystemForRecon_initial;  # frame 0
			my variable coordinateSystemForRecon_current;  # current frame

			# Lists of geometric drifts. Initialize to empty lists:
			my variable drifts_center_x
			my variable drifts_center_y
			my variable drifts_center_z

			my variable drifts_vector_u_x
			my variable drifts_vector_u_y
			my variable drifts_vector_u_z

			my variable drifts_vector_w_x
			my variable drifts_vector_w_y
			my variable drifts_vector_w_z

			my variable drifts_rotation_u
			my variable drifts_rotation_v
			my variable drifts_rotation_w

			set coordinateSystem_initial [::ctsimu::coordinate_system new];  # frame 0
			set coordinateSystem_current [::ctsimu::coordinate_system new];  # current frame

			# Ghost coordinate system to use for the calculation of
			# recon projection matrices. Those only obey drifts 'known_to_reconstruction'.
			set coordinateSystemForRecon_initial [::ctsimu::coordinate_system new];  # frame 0
			set coordinateSystemForRecon_current [::ctsimu::coordinate_system new];  # current frame

			# Lists of geometric drifts. Initialize to empty lists:
			set drifts_center_x [list]
			set drifts_center_y [list]
			set drifts_center_z [list]

			set drifts_vector_u_x [list]
			set drifts_vector_u_y [list]
			set drifts_vector_u_z [list]

			set drifts_vector_w_x [list]
			set drifts_vector_w_y [list]
			set drifts_vector_w_z [list]

			set drifts_rotation_u [list]
			set drifts_rotation_v [list]
			set drifts_rotation_w [list]
		}

		method set_geometry { jsonGeometry world stage } {
			my variable coordinateSystem_initial coordinateSystemForRecon_initial
			$coordinateSystem_initial setupFromJSONgeometry { $jsonGeometry $world $stage 0 }
			$coordinateSystemForRecon_initial setupFromJSONgeometry { $jsonGeometry $world $stage 1 }

			# set up drifts:
			if [json exists $jsonGeometry drift] {

			}
		}

		destructor {
			my variable coordinateSystem_initial coordinateSystem_current coordinateSystemForRecon_initial coordinateSystemForRecon_current

			$coordinateSystem_initial destroy
			$coordinateSystem_current destroy
			$coordinateSystemForRecon_initial destroy
			$coordinateSystemForRecon_current destroy
		}

		method reset { } {
			my variable coordinateSystem_initial coordinateSystem_current coordinateSystemForRecon_initial coordinateSystemForRecon_current

			$coordinateSystem_initial reset
			$coordinateSystem_current reset
			$coordinateSystemForRecon_initial reset
			$coordinateSystemForRecon_current reset
		}
	}
}