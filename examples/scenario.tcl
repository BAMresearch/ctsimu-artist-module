source [file join ../CTSimU/ctsimu_main.tcl]

set S [ctsimu::scenario new]
$S load_json_scene "scenario/example.json"
$S set_frame 0 1
$S start_scan
