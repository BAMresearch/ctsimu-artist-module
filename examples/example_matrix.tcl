source [file join ../CTSimU/ctsimu_main.tcl]

set cols 4
set rows 3
set M [::ctsimu::matrix new $cols $rows]

# Fill matrix with a sequential list of numbers from 1 to 12:
for {set i 0} {$i < [$M size]} {incr i} {
	set col [expr int($i % $cols)]
	set row [expr int(floor($i/$cols))]
	
	$M set_element $col $row [expr $i+1]
}

puts [$M print]

# Print row vectors:
for {set row 0} {$row < [$M n_rows]} {incr row} {
	puts "Row vector $row: [[$M get_row_vector $row] print]"
}

# Print column vectors:
for {set col 0} {$col < [$M n_cols]} {incr col} {
	# Each column vector is new vector object
	# and should be destroyed when not used anymore.
	set col_vector [$M get_col_vector $col]
	puts "Col vector $col: [$col_vector print]"
	$col_vector destroy
}

# All elements in a list:
for {set i 0} {$i < [$M size]} {incr i} {
	set col [expr int($i % $cols)]
	set row [expr int(floor($i/$cols))]
	
	puts "Element $i: [$M element $col $row]"
}

# Set a matrix element to pi:
$M set_element 2 0 3.14159

# Manipulate a row in the matrix:
$M set_row 1 [::ctsimu::vector new [list 50 60 70 80]]

# Manipulate a column in the matrix:
$M set_col 3 [::ctsimu::vector new [list 40 800 120]]

puts [$M print]