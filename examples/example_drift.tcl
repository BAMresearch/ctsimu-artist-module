source [file join ../CTSimU/ctsimu_main.tcl]

set drift1 [::ctsimu::drift new "mm"]
$drift1 set_interpolation 0
$drift1 