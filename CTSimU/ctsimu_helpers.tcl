package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_json_basics.tcl]

namespace eval ::ctsimu {
	proc rotationMatrix { axis angleInRad } {
		set unitAxis [$axis getUnitVector]

		set cs [expr cos($angleInRad)]
		set sn [expr sin($angleInRad)]

		set nx [lindex $unitAxis 0]
		set ny [lindex $unitAxis 1]
		set nz [lindex $unitAxis 2]

		# New rotation matrix
		set R [::ctsimu::matrix new 3 0]

		# Row 0
		set c00 [expr $nx*$nx*(1-$cs)+$cs]
		set c01 [expr $nx*$ny*(1-$cs)-$nz*$sn]
		set c02 [expr $nx*$nz*(1-$cs)+$ny*$sn]
		$R addRowVector [::ctsimu::vector new [list $c00 $c01 $c02]]

		# Row 1
		set c10 [expr $ny*$nx*(1-$cs)+$nz*$sn]
		set c11 [expr $ny*$ny*(1-$cs)+$cs]
		set c12 [expr $ny*$nz*(1-$cs)-$nx*$sn]
		$R addRowVector [::ctsimu::vector new [list $c10 $c11 $c12]]

		# Row 2
		set c20 [expr $nz*$nx*(1-$cs)-$ny*$sn]
		set c21 [expr $nz*$ny*(1-$cs)+$nx*$sn]
		set c22 [expr $nz*$nz*(1-$cs)+$cs]
		$R addRowVector [::ctsimu::vector new [list $c20 $c21 $c22]]

		return $R
	}

	proc rotateVector { vec axis angleInRad } {
		if {$angleInRad != 0} {
			set m [::ctsimu::rotationMatrix $axis $angleInRad]
			set r [$m multiplyVector $vec]
			$m destroy
			return $r
		} else {
			return $vec
		}
	}
}