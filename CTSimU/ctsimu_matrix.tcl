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
				set row [::ctsimu::vector new]
				for { set c 0 } { $c < $nCols} { incr c } {
					# insert $nCols zeros into the row
					$row addElement 0
				}

				# append row vector to matrix:
				lappend rows $row
			}
		}

		destructor {
			# Destroy stored row vectors that contain the matrix data.
			my variable rows			
			foreach vec $rows {
				$vec destroy
			}
		}
		
		method print { } {
			# Return a printable string for this matrix.
			my variable rows nCols nRows

			set s "\["
			set row 0
			for { set row 0 } { $row < $nRows} { incr row } {
				if { $row > 0 } {
					# Add line break before each new printed row.
					append s "\n"
				}
				for { set col 0 } { $col < $nCols} { incr col } {
					append s "\t"
					append s [[my getRowVector $row] element $col]
				}
			}
			append s "\]"
			return $s
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
		
		method nElements { } {
			my variable nRows nCols
			return [expr $nRows*$nCols]
		}
		
		# Getters
		# -------------------------
		# Getters currently perform no checks for valid row and col numbers
		# to improve speeds during calculations. Maybe add later...?
		
		method element { col row } {
			# Return the matrix element at the requested column and row.
			return [[my getRowVector $row] element $col]
		}
		
		method getRowVector { row } {
			# Return the vector of the requested row.
			my variable rows nRows
			return [lindex $rows $row]
		}
		
		method getColVector { col } {
			# Return a new vector object for the requested column.
			my variable rows
			set column_vector [::ctsimu::vector new]
			foreach row $rows {
				$column_vector addElement [$row element $col]
			}
			
			return $column_vector
		}

		# Setters
		# -------------------------
		method setElement { col row value } {
			# Set matrix element in given column and row to value.
			my variable nCols nRows rows

			if { $nRows > $row } {
				if { $nCols > $col } {
					[lindex $rows $row] setElement $col $value
				} else {
					error "::ctsimu::matrix::setElement: Cannot set element at column index $col for a matrix that only has $nCols columns."
				}
			} else {
				error "::ctsimu::matrix::setElement: Cannot set element at row index $row for a matrix that only has $nRows rows."
			}
		}

		method setRow { index rowVector } {
			# Set row at index to another rowVector.
			my variable nCols nRows rows
			if {$nRows > $index} {
				if {[$rowVector nElements] == $nCols} {
					[lindex $rows $index] destroy
					lset rows $index $rowVector
				} else {
					error "::ctsimu::matrix::setRow: Cannot set row vector with [$rowVector nElements] elements for a matrix that has $nCols columns."
				}
			} else {
				error "::ctsimu::matrix::setRow: Cannot set row at index $index for a matrix that only has $nRows rows."
			}
		}
		
		method setCol { index colVector } {
			# Set column at index to another colVector.
			my variable nCols nRows rows
			if {$nCols > $index} {
				if {[$colVector nElements] == $nRows} {
					for {set row 0} {$row < $nRows} {incr row} {
						my setElement $index $row [$colVector element $row]
					}
				} else {
					error "::ctsimu::matrix::setCol: Cannot set column vector with [$colVector nElements] elements for a matrix that has $nRows rows."
				}
			} else {
				error "::ctsimu::matrix::setCol: Cannot set column at index $index for a matrix that only has $nCols columns."
			}
		}

		method addRow { rowVector } {
			# Add another row (must be a vector with nCols elements)
			my variable nRows nCols rows
			if {[$rowVector nElements] == $nCols} {
				lappend rows $rowVector
				set nRows [expr $nRows + 1]
			} else {
				error "::ctsimu::matrix::addRow: Cannot add row vector with [$rowVector nElements] elements to a matrix that has $nCols columns."
			}
		}

		method addCol { colVector } {
			# Add another column (must be a vector with nRows elements)
			my variable nRows nCols rows
			if {[$colVector nElements] == $nRows} {
				for { set r 0 } { $r < $nRows} { incr r } {
					[lindex $rows $r] addElement [$colVector element $r]
				}
				set nCols [expr $nCols + 1]
			} else {
				error "::ctsimu::matrix::addCol: Cannot add column vector with [$colVector nElements] elements to a matrix that has $nRows rows."
			}
		}

		method multiplyVector { colVector } {
			# Return the result of Matrix*Vector
			my variable nCols nRows rows
			set vecNElements [$colVector nElements]
			if {$nCols == $vecNElements} {
				set result [::ctsimu::vector new]
				foreach row $rows {
					$result addElement [$row dot $colVector]
				}
				return $result
			} else {
				error "::ctsimu::matrix::multiplyVector: Cannot multiply matrix with $nCol columns and $nRow rows with vector of $vecNElements rows."
			}
		}
	}


	proc rotationMatrix { axis angleInRad } {
		# Creates a matrix that performs a 3D vector rotation around the
		# given axis vector by the given angle (in rad).
		set unitAxis [$axis getUnitVector]

		set cs [expr cos($angleInRad)]
		set sn [expr sin($angleInRad)]

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
		$R addRow [::ctsimu::vector new [list $c00 $c01 $c02]]

		# Row 1
		set c10 [expr $ny*$nx*(1-$cs)+$nz*$sn]
		set c11 [expr $ny*$ny*(1-$cs)+$cs]
		set c12 [expr $ny*$nz*(1-$cs)-$nx*$sn]
		$R addRow [::ctsimu::vector new [list $c10 $c11 $c12]]

		# Row 2
		set c20 [expr $nz*$nx*(1-$cs)-$ny*$sn]
		set c21 [expr $nz*$ny*(1-$cs)+$nx*$sn]
		set c22 [expr $nz*$nz*(1-$cs)+$cs]
		$R addRow [::ctsimu::vector new [list $c20 $c21 $c22]]

		return $R
	}
}