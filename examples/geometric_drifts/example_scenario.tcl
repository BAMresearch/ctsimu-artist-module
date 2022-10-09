source [file join ../../CTSimU/ctsimu_main.tcl]

set S [ctsimu::scenario new]
$S load_json_scene "detector_center_file.json"
#$S set_frame 0 1
#$S set_frame 1 101
$S set_frame 176 101