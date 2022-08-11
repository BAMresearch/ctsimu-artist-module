source [file join ../CTSimU/ctsimu_main.tcl]

# Create a basis of unit vectors.

# First vector initialized by list passed to constructor:
set e1 [::ctsimu::vector new [list 1 0 0]]

# Second vector initialized using the set function:
set e2 [::ctsimu::vector new]
$e2 set 0 1 0

# Third vector initialized by appending elements:
set e3 [::ctsimu::vector new ]
$e3 addElement 0
$e3 addElement 0
$e3 addElement 1

puts "My hand-made basis:"
puts "e1: [$e1 print]"
puts "e2: [$e2 print]"
puts "e3: [$e3 print]"

