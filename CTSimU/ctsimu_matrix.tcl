package require TclOO

variable BasePath [file dirname [info script]]
source -encoding utf-8 [file join $BasePath ctsimu_vector.tcl]

namespace eval ::ctsimu {
	::oo::class create matrix {
		constructor { _nCols _nRows } {
			# Create a matrix with the given number of rows and columns.
			my variable rows nCols nRows
			set nCols $_nCols
			set nRows $_nRows

			for { set r 0 } { $r < $nRows} { incr r } {
				set row [list ]
				for { set c 0 } { $c < $nCols} { incr c } {
					lappend row 0
				}

				# append row vector to matrix:
				lappend rows [::ctsimu::vector new $row]
			}
		}

		destructor {
			foreach vec $rows {
				$vec destroy
			}
		}

		method nRows { } {
			# Return number of rows
			my variable nRows
			return $nRows
		}

		method nCols { } {
			# Return number of columns
			my variable nCols
			return $nCols
		}

		method setElement { col row value } {
			my variable nCols nRows rows

			if { $nRows > $row } {
				if { $nCols > $col } {
					[lindex $rows $row] setElement $col $value
				} else {
					error "::ctsimu::matrix::setElement: Cannot set element at row $row for a matrix that only has $nRows rows."
				}
			} else {
				error "::ctsimu::matrix::setElement: Cannot set element at column $col for a matrix that only has $nCols columns."
			}
		}

		method setRowVector { i row } {
			# Set row i to another vector
			my variable nCols nRows rows
			if {[my nRows] > $i} {
				if {[$row nElements] == $nCols} {
					[lindex $rows $row] destroy
					lset rows $i $row
				} else {
					error "::ctsimu::matrix::setRow: Cannot set row vector with [$row nElements] elements for a matrix that has $nCols columns."
				}
			} else {
				error "::ctsimu::matrix::setRow: Cannot set row at index $i for a matrix that only has $nRows rows."
			}
		}

		method addRowVector { row } {
			# Add another row (must be a vector with nCols elements)
			my variable nRows nCols rows
			if {[$row nElements] == $nCols} {
				lappend rows $row
				set nRows [expr $nRows + 1]
			} else {
				error "::ctsimu::matrix::setRow: Cannot add row vector with [$row nElements] elements to a matrix that has $nCols columns."
			}
		}

		method addColVector { col } {
			# Add another column (must be a vector with nRows elements)
			my variable nRows nCols rows
			if {[$row nElements] == $nRows} {
				for { set r 0 } { $r < $nRows} { incr r } {
					[lindex $rows $r] addElement [$col element $r]
				}
				set nCols [expr $nCols + 1]
			} else {
				error "::ctsimu::matrix::addColVector: Cannot add column vector with [$col nElements] elements to a matrix that has $nRows rows."
			}
		}

		method multiplyVector { vec } {
			# Return the result of Matrix*Vector
			my variable nCols nRows
			set vecNElements [$vec nElements]
			if {$nCols == $vecNElements} {
				set result [::ctsimu::vector new [list ]]
				foreach row $rows {
					$result addElement [$row dot $vec]
				}
				return $result
			} else {
				error "::ctsimu::matrix::multiplyVector: Cannot multiply matrix with $nCol columns and $nRow rows with vector of $vecNElements rows."
			}
		}
	}
}