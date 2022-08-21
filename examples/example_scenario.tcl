source [file join ../CTSimU/ctsimu_main.tcl]

#set D [dict create]
#dict set D "blumentopf" 3
#puts "Blumentopf ist: "
#puts [dict get $D "blumentopf"]


set S [ctsimu::scenario new]
$S set Blumentopf 3
puts "Blumentopf ist: "
puts [$S get Blumentopf]