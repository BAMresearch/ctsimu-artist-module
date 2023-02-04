source [file join ../CTSimU/ctsimu_main.tcl]

set bm [::ctsimu::batchmanager new]
$bm add_batch_job_from_json "simple_scan.json"
$bm add_batch_job_from_json "example.json"
$bm sync_batchlist_into_manager

set S [::ctsimu::scenario new]
$bm save_batch_jobs "batch.csv"
$bm clear
$bm import_batch_jobs "batch.csv"
$bm run_batch $S