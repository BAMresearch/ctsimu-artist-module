source [file join ../CTSimU/ctsimu_main.tcl]

set S [ctsimu::scenario new]
$S load_json_scene "Test3D.json"
$S set_frame 0 1
$S start_scan

#$S load_json_scene "../../example_jsons/2D-DW-1_Detektor1_2021-05-26v01r01dp.json"
#$S set_frame 0 1

#$S load_json_scene "../../example_jsons/2D-DW-1_Detektor2_2021-05-26v01r01dp.json"
#$S set_frame 0 1

#$S load_json_scene "../../example_jsons/2D-HS-1_2021-03-24v02r00dp.json"
#$S set_frame 100 0 1

#$S load_json_scene "simple_scan.json"
#$S set_frame 0 0 1
#$S start_scan 1 1
