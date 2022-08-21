package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_vector.tcl]

namespace eval ::ctsimu {
	::oo::class create matrix {
		constructor { nCols nRows } {
			# Create a matrix with the given number of rows and columns.
			my variable _rows _n_cols _n_rows
			set _n_cols $nCols
			set _n_rows $nRows

			for { set r 0 } { $r < $_n_rows} { incr r } {
				set row [::ctsimu::vector new]
				for { set c 0 } { $c < $_n_cols} { incr c } {
					# insert $_n_cols zeros into the row
					$row add_element 0
				}

				# append row vector to matrix:
				lappend _rows $row
			}
		}

		destructor {
			# Destroy stored row vectors that contain the matrix data.
			my variable _rows			
			foreach vec $_rows {
				$vec destroy
			}
		}
		
		method print { } {
			# Return a printable string for this matrix.
			my variable _rows _n_cols _n_rows

			set s "\["
			set row 0
			for { set row 0 } { $row < $_n_rows} { incr row } {
				if { $row > 0 } {
					# Add line break before each new printed row.
					append s "\n"
				}
				for { set col 0 } { $col < $_n_cols} { incr col } {
					append s "\t"
					append s [[my get_row_vector $row] element $col]
				}
			}
			append s "\]"
			return $s
		}

		method n_rows { } {
			# Return number of rows
			my variable _n_rows
			return $_n_rows
		}

		method n_cols { } {
			# Return number of columns
			my variable _n_cols
			return $_n_cols
		}
		
		method size { } {
			# Get the total number of matrix elements (n_cols * n_rows).
			my variable _n_rows _n_cols
			return [expr $_n_rows*$_n_cols]
		}
		
		# Getters
		# -------------------------
		# Getters currently perform no checks for valid row and col numbers
		# to improve speeds during calculations. Maybe add later...?
		
		method element { col_index row_index } {
			# Return the matrix element at the requested column and row.
			return [[my get_row_vector $row_index] element $col_index]
		}
		
		method get_row_vector { row_index } {
			# Return the vector of the requested row index.
			my variable _rows _n_rows
			return [lindex $_rows $row_index]
		}
		
		method get_col_vector { col_index } {
			# Return a new vector object for the requested column index.
			my variable _rows
			set column_vector [::ctsimu::vector new]
			foreach row $_rows {
				$column_vector add_element [$row element $col_index]
			}
			
			return $column_vector
		}

		# Setters
		# -------------------------
		method set_element { col_index row_index value } {
			# Set matrix element in given column and row to value.
			my variable _n_cols _n_rows _rows

			if { $_n_rows > $row_index } {
				if { $_n_cols > $col_index } {
					[lindex $_rows $row_index] set_element $col_index $value
				} else {
					error "::ctsimu::matrix::set_element: Cannot set element at column index $col_index for a matrix that only has $_n_cols columns."
				}
			} else {
				error "::ctsimu::matrix::set_element: Cannot set element at row index $row_index for a matrix that only has $_n_rows rows."
			}
		}

		method set_row { index row_vector } {
			# Set row at index to another row_vector.
			my variable _n_cols _n_rows _rows
			if {$_n_rows > $index} {
				if {[$row_vector size] == $_n_cols} {
					[lindex $_rows $index] destroy
					lset _rows $index $row_vector
				} else {
					error "::ctsimu::matrix::set_row: Cannot set row vector with [$row_vector size] elements for a matrix that has $_n_cols columns."
				}
			} else {
				error "::ctsimu::matrix::set_row: Cannot set row at index $index for a matrix that only has $_n_rows rows."
			}
		}
		
		method set_col { index col_vector } {
			# Set column at index to another col_vector.
			my variable _n_cols _n_rows _rows
			if {$_n_cols > $index} {
				if {[$col_vector size] == $_n_rows} {
					for {set row 0} {$row < $_n_rows} {incr row} {
						my set_element $index $row [$col_vector element $row]
					}
				} else {
					error "::ctsimu::matrix::set_col: Cannot set column vector with [$col_vector size] elements for a matrix that has $_n_rows rows."
				}
			} else {
				error "::ctsimu::matrix::set_col: Cannot set column at index $index for a matrix that only has $_n_cols columns."
			}
		}

		method add_row { row_vector } {
			# Add another row (must be a vector with _n_cols elements)
			my variable _n_rows _n_cols _rows
			if {[$row_vector size] == $_n_cols} {
				lappend _rows $row_vector
				set _n_rows [expr $_n_rows + 1]
			} else {
				error "::ctsimu::matrix::add_row: Cannot add row vector with [$row_vector size] elements to a matrix that has $_n_cols columns."
			}
		}

		method add_col { col_vector } {
			# Add another column (must be a vector with _n_rows elements)
			my variable _n_rows _n_cols _rows
			if {[$col_vector size] == $_n_rows} {
				for { set r 0 } { $r < $_n_rows} { incr r } {
					[lindex $_rows $r] add_element [$col_vector element $r]
				}
				set _n_cols [expr $_n_cols + 1]
			} else {
				error "::ctsimu::matrix::add_col: Cannot add column vector with [$col_vector size] elements to a matrix that has $_n_rows rows."
			}
		}

		method multiply_vector { col_vector } {
			# Return the result of Matrix*Vector
			my variable _n_cols _n_rows _rows
			set vecNElements [$col_vector size]
			if {$_n_cols == $vecNElements} {
				set result [::ctsimu::vector new]
				foreach row $_rows {
					$result add_element [$row dot $col_vector]
				}
				return $result
			} else {
				error "::ctsimu::matrix::multiply_vector: Cannot multiply matrix with $nCol columns and $nRow rows with vector of $vecNElements rows."
			}
		}
	}


	proc rotation_matrix { axis angle_in_rad } {
		# Creates a matrix that performs a 3D vector rotation around the
		# given axis vector by the given angle (in rad).
		set unitAxis [$axis get_unit_vector]

		set cs [expr cos($angle_in_rad)]
		set sn [expr sin($angle_in_rad)]

		set nx [$unitAxis x]
		set ny [$unitAxis y]
		set nz [$unitAxis z]

		$unitAxis destroy

		# New rotation matrix
		set R [::ctsimu::matrix new 3 0]

		# Row 0
		set c00 [expr $nx*$nx*(1-$cs)+$cs]
		set c01 [expr $nx*$ny*(1-$cs)-$nz*$sn]
		set c02 [expr $nx*$nz*(1-$cs)+$ny*$sn]
		$R add_row [::ctsimu::vector new [list $c00 $c01 $c02]]

		# Row 1
		set c10 [expr $ny*$nx*(1-$cs)+$nz*$sn]
		set c11 [expr $ny*$ny*(1-$cs)+$cs]
		set c12 [expr $ny*$nz*(1-$cs)-$nx*$sn]
		$R add_row [::ctsimu::vector new [list $c10 $c11 $c12]]

		# Row 2
		set c20 [expr $nz*$nx*(1-$cs)-$ny*$sn]
		set c21 [expr $nz*$ny*(1-$cs)+$nx*$sn]
		set c22 [expr $nz*$nz*(1-$cs)+$cs]
		$R add_row [::ctsimu::vector new [list $c20 $c21 $c22]]

		return $R
	}
}