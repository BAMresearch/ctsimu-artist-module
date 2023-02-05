source [file join ../CTSimU/ctsimu_main.tcl]

set S [ctsimu::scenario new]
$S load_json_scene "scenario/example.json"
$S set_frame_for_real 0
$S start_scan
