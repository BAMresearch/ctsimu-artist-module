source [file join ../CTSimU/ctsimu_main.tcl]

set S [ctsimu::scenario new]
$S load_json_scene "example.json"
$S load_json_scene "../../example_jsons/2D-DW-1_Detektor1_2021-05-26v01r01dp.json"
$S load_json_scene "../../example_jsons/2D-DW-1_Detektor2_2021-05-26v01r01dp.json"