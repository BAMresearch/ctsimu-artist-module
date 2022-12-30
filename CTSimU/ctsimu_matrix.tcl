package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_vector.tcl]

namespace eval ::ctsimu {
	::oo::class create matrix {
		variable _rows;   # lists for the elements of each row
		variable _n_cols; # number of columns
		variable _n_rows; # number of rows

		constructor { nCols nRows } {
			# Create a matrix with the given number of rows and columns.
			set _n_cols $nCols
			set _n_rows $nRows

			for { set r 0 } { $r < $_n_rows} { incr r } {
				set row [list]
				for { set c 0 } { $c < $_n_cols} { incr c } {
					# insert $_n_cols zeros into the row
					lappend row 0
				}

				# append row vector to matrix:
				lappend _rows $row
			}
		}

		destructor {
			
		}
		
		method print { } {
			# Return a printable string for this matrix.
			set s "\["
			set row 0
			for { set row 0 } { $row < $_n_rows} { incr row } {
				if { $row > 0 } {
					# Add line break before each new printed row.
					append s "\n"
				}
				for { set col 0 } { $col < $_n_cols} { incr col } {
					append s "\t"
					append s [lindex $_rows $row $col]
				}
			}
			append s "\]"
			return $s
		}
		
		method format_json { } {
			set jmatrix [::rl_json::json new array]
			foreach row $_rows {
				set jrow [::rl_json::json new array]
				foreach element $row {
					::rl_json::json set jrow end+1 $element
				}
				::rl_json::json set jmatrix end+1 $jrow
			}
			
			return $jmatrix
		}
		
		method format_CERA { } {
			return [join $_rows \n]
		}

		method n_rows { } {
			# Return number of rows
			return $_n_rows
		}

		method n_cols { } {
			# Return number of columns
			return $_n_cols
		}
		
		method size { } {
			# Get the total number of matrix elements (n_cols * n_rows).
			return [expr $_n_rows*$_n_cols]
		}
		
		# Getters
		# -------------------------
		# Getters currently perform no checks for valid row and col numbers
		# to improve speeds during calculations. Maybe add later...?
		
		method element { col_index row_index } {
			# Return the matrix element at the requested column and row.
			return [lindex $_rows $row_index $col_index]
		}
		
		method get_row { row_index } {
			# Return the vector of the requested row index.
			return [lindex $_rows $row_index]
		}
		
		method get_col { col_index } {
			# Return a new vector object for the requested column index.
			set column_vector [list]
			foreach row $_rows {
				lappend column_vector [lindex $row $col_index]
			}
			
			return $column_vector
		}

		# Setters
		# -------------------------
		method set_element { col_index row_index value } {
			# Set matrix element in given column and row to value.
			if { $_n_rows > $row_index } {
				if { $_n_cols > $col_index } {
					lset _rows $row_index $col_index $value
				} else {
					::ctsimu::fail "::ctsimu::matrix::set_element: Cannot set element at column index $col_index for a matrix that only has $_n_cols columns."
				}
			} else {
				::ctsimu::fail "::ctsimu::matrix::set_element: Cannot set element at row index $row_index for a matrix that only has $_n_rows rows."
			}
		}

		method set_row { index row_value_list } {
			# Set row at index to another row vector, given by the value list.
			if {$_n_rows > $index} {
				if {[llength $row_value_list] == $_n_cols} {
					lset _rows $index $row_value_list
				} else {
					::ctsimu::fail "::ctsimu::matrix::set_row: Cannot set row vector with [llength $row_vector] elements for a matrix that has $_n_cols columns."
				}
			} else {
				::ctsimu::fail "::ctsimu::matrix::set_row: Cannot set row at index $index for a matrix that only has $_n_rows rows."
			}
		}
		
		method set_col { index col_value_list } {
			# Set column at index to another col_vector.
			if {$_n_cols > $index} {
				if {[llength $col_value_list] == $_n_rows} {
					for {set row 0} {$row < $_n_rows} {incr row} {
						lset _rows $row $index [lindex $col_value_list $row]
					}
				} else {
					::ctsimu::fail "::ctsimu::matrix::set_col: Cannot set column vector with [llength $col_vector] elements for a matrix that has $_n_rows rows."
				}
			} else {
				::ctsimu::fail "::ctsimu::matrix::set_col: Cannot set column at index $index for a matrix that only has $_n_cols columns."
			}
		}

		method add_row { row_value_list } {
			# Add another row (must be a list with _n_cols elements)
			if {[llength $row_value_list] == $_n_cols} {
				lappend _rows $row_value_list
				set _n_rows [expr $_n_rows + 1]
			} else {
				::ctsimu::fail "::ctsimu::matrix::add_row: Cannot add row vector with [llength $row_value_list] elements to a matrix that has $_n_cols columns."
			}
		}

		method add_col { col_value_list } {
			# Add another column (must be a list with _n_rows elements)
			if {[llength $col_value_list] == $_n_rows} {
				for { set r 0 } { $r < $_n_rows} { incr r } {
					lset _rows $r end+1 [lindex $col_value_list $r]
				}
				set _n_cols [expr $_n_cols + 1]
			} else {
				::ctsimu::fail "::ctsimu::matrix::add_col: Cannot add column vector with [llength $col_value_list] elements to a matrix that has $_n_rows rows."
			}
		}
		
		method scale { factor } {
			for {set r 0} {$r < $_n_rows} {incr r} {
				for {set c 0} {$c < $_n_cols} {incr c} {
					lset _rows $r $c [expr [lindex $_rows $r $c]*$factor]
				}				
			}
		}

		method multiply_vector { col_vector } {
			# Return the result of Matrix*Vector
			set vecNElements [$col_vector size]
			if {$_n_cols == $vecNElements} {
				set result [::ctsimu::vector new]
				foreach row $_rows {
					set s 0
					for {set i 0} {$i < $_n_cols} {incr i} {
						# manual computation of dot product: row_vector * col_vector
						set s [expr $s + [lindex $row $i]*[$col_vector element $i]]
					}
					$result add_element $s
				}
				return $result
			} else {
				::ctsimu::fail "::ctsimu::matrix::multiply_vector: Cannot multiply matrix with $_n_cols columns and $_n_rows rows with vector of $vecNElements rows."
			}
		}
		
		method multiply { M } {
			# Return the matrix product of this*M.
			set result_rows [my n_rows]
			set result_cols [$M n_cols]
			
			set result [::ctsimu::matrix new $result_cols $result_rows]
			
			for {set row 0} {$row < $result_rows} {incr row} {
				for {set col 0} {$col < $result_cols} {incr col} {
					set s 0
					for {set i 0} {$i < [expr min($_n_cols, [$M n_rows])]} {incr i} {
						set s [expr $s + [lindex $_rows $row $i]*[$M element $col $i]]
					}
					
					$result set_element $col $row $s
				}
			}
			
			return $result
		}
	}


	proc rotation_matrix { axis angle_in_rad } {
		# Creates a matrix that performs a 3D vector rotation around the
		# given axis vector by the given angle (in rad).
		set unitAxis [$axis get_unit_vector]

		set nx [$unitAxis x]
		set ny [$unitAxis y]
		set nz [$unitAxis z]

		$unitAxis destroy
		
		set cs [expr cos($angle_in_rad)]
		set sn [expr sin($angle_in_rad)]

		# New rotation matrix
		set R [::ctsimu::matrix new 3 0]

		# Row 0
		set c00 [expr $nx*$nx*(1-$cs)+$cs]
		set c01 [expr $nx*$ny*(1-$cs)-$nz*$sn]
		set c02 [expr $nx*$nz*(1-$cs)+$ny*$sn]
		$R add_row [list $c00 $c01 $c02]

		# Row 1
		set c10 [expr $ny*$nx*(1-$cs)+$nz*$sn]
		set c11 [expr $ny*$ny*(1-$cs)+$cs]
		set c12 [expr $ny*$nz*(1-$cs)-$nx*$sn]
		$R add_row [list $c10 $c11 $c12]

		# Row 2
		set c20 [expr $nz*$nx*(1-$cs)-$ny*$sn]
		set c21 [expr $nz*$ny*(1-$cs)+$nx*$sn]
		set c22 [expr $nz*$nz*(1-$cs)+$cs]
		$R add_row [list $c20 $c21 $c22]

		return $R
	}
}