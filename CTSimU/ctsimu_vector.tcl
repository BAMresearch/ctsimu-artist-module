package require TclOO

namespace eval ::ctsimu {
	::oo::class create vector {
		constructor { { valueList {} } } {
			my variable values
			my setValues $valueList
		}

		destructor {

		}

		method print { } {
			# Return a printable string for this vector.
			my variable values

			set s "("
			set i 0
			foreach v $values {
				if {$i>0} {append s ", "}
				incr i
				append s $v
			}
			append s ")"
			return $s
		}

		method nElements { } {
			# Return number of vector elements.
			my variable values
			return [llength $values]
		}
		
		method getCopy { } {
			# Return a copy of this vector
			set newVector [::ctsimu::vector new [list 0]]
			$newVector setValues [my getValues]
			return $newVector
		}

		method matchDimensions { other } {
			# Do vector dimensions match?
			return [expr [my nElements] == [$other nElements]]
		}

		# Getters
		# -------------------------
		# Getters currently perform no checks for valid vector indices
		# to improve speeds during calculations. Maybe add later...?
		method element { i } {
			# Return vector element at position i.
			my variable values
			if {[my nElements] > $i} {
				return [lindex $values $i]
			} else {
				error "Vector element index $i does not exist in vector of [my nElements] elements."
				# return 0
			}
		}

		method getValues { } {
			# Return list of all vector elements.
			my variable values
			return $values
		}

		method x { } {
			# Shortcut for vector element 0
			return [my element 0]
		}

		method y { } {
			# Shortcut for vector element 1
			return [my element 1]
		}

		method z { } {
			# Shortcut for vector element 2
			return [my element 2]
		}
		
		method w { } {
			# Shortcut for vector element 3
			return [my element 3]
		}

		# Setters
		# -------------------------
		# All setters take care that numbers are converted to double
		# when stored in the vector.
		method setValues { l } {
			# Set vector elements to given value list.
			my variable values
			set values $l
			
			# Convert all elements to double to avoid problems:
			for {set i 0} {$i < [my nElements]} {incr i} {
				lset values $i [expr double([my element $i])]
			}
		}
		
		method set { _x {_y "none"} {_z "none"} {_w "none"} } {
			# Make a vector with three components (x, y, z).
			my variable values
			
			set values [list [expr double($_x)]]
			if {$_y != "none"} {
				my addElement $_y
				
				if {$_z != "none"} {
					my addElement $_z
					
					if {$_w != "none"} {
						my addElement $_w
					}
				}
			}
		}

		method addElement { value } {
			# Append another element (i.e. dimension) to the vector with the given value.
			my variable values
			lappend values [expr double($value)]
		}

		method setElement { i value } {
			# Set vector element at index i to the given value.
			my variable values
			if {[my nElements] > $i} {
				lset values $i [expr double($value)]
			}
		}

		method setx { value } {
			# Shortcut to set element 0 to given value.
			my setElement 0 [expr double($value)]
		}

		method sety { value } {
			# Shortcut to set element 1 to given value.
			my setElement 1 [expr double($value)]
		}

		method setz { value } {
			# Shortcut to set element 2 to given value.
			my setElement 2 [expr double($value)]
		}
		
		method setw { value } {
			# Shortcut to set element 3 to given value.
			my setElement 3 [expr double($value)]
		}
		
		method copy { other } {
			# Copy other vector to this vector.
			my setValues [$other getValues]
		}

		# Vector Operations
		# -------------------------

		method add { other } {
			# Add other vector to this vector.
			if {[my matchDimensions $other]} {
				for { set i 0 } { $i < [my nElements]} { incr i } {
					my setElement $i [expr [my element $i] + [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::add: Cannot treat vectors of different dimensions."
			}
		}

		method subtract { other } {
			# Subtract other vector from this vector.
			if {[my matchDimensions $other]} {
				for { set i 0 } { $i < [my nElements]} { incr i } {
					my setElement $i [expr [my element $i] - [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::subtract: Cannot treat vectors of different dimensions."
			}
		}

		method multiply { other } {
			# Multiply other vector to this vector.
			if {[my matchDimensions $other]} {
				for { set i 0 } { $i < [my nElements]} { incr i } {
					my setElement $i [expr [my element $i] * [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::multiply: Cannot treat vectors of different dimensions."
			}
		}

		method divide { other } {
			# Divide this vector by other vector.
			if {[my matchDimensions $other]} {
				for { set i 0 } { $i < [my nElements]} { incr i } {
					my setElement $i [expr [my element $i] / [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::divide: Cannot treat vectors of different dimensions."
			}
		}

		method scale { factor } {
			# Scale this vector's length by the given factor.
			for { set i 0 } { $i < [my nElements]} { incr i } {
				my setElement $i [expr [my element $i] * $factor]
			}
		}

		method invert { } {
			# Point vector in opposite direction.
			for { set i 0 } { $i < [my nElements]} { incr i } {
				my setElement $i [expr -[my element $i]]
			}
		}

		method square { } {
			# Square all vector elements
			for { set i 0 } { $i < [my nElements]} { incr i } {
				my setElement $i [expr [my element $i]**2]
			}
		}

		method to { other } {
			# Returns a vector that points from this point to other point.
			set d [my getCopy]
			$d subtract $other
			return $d
		}

		method sum { } {
			# Return sum of vector elements
			my variable values
			set sum 0.0
			foreach v $values {
				set sum [expr $sum + double($v)]
			}
			return $sum
		}

		method length { } {
			# This vector's absolute length
			my variable values
			set sqSum 0.0
			foreach v $values {
				set sqSum [expr $sqSum + double($v)*double($v)]
			}
			return [expr sqrt($sqSum)]
		}

		method getUnitVector { } {
			# Return a new unit vector based on this vector.
			set u [my getCopy]
			if {[catch {$u toUnitVector} errmsg]} {
				error $errmsg
			}
			return $u
		}

		method toUnitVector { } {
			# Convert this vector into a unit vector.
			set l [my length]
			if {$l != 0} {
				my scale [expr 1.0/$l]
			} else {
				error "Cannot make unit vector: length is zero."
			}
		}

		method distance { other } {
			# Distance between the points where this vector and the other vector point.
			if {[my matchDimensions $other]} {
				set diff [my getCopy]
				$diff subtract $other
				return [$diff length]
			} else {
				error "::ctsimu::vector::distance: Cannot treat vectors of different dimensions."
			}	
		}

		method dot { other } {
			# Return dot product with other vector.
			if {[my matchDimensions $other]} {
				set dotprod 0.0
				for { set i 0 } { $i < [my nElements]} { incr i } {
					set dotprod [expr $dotprod + [my element $i] * [$other element $i]]
				}
				return $dotprod
			} else {
				error "::ctsimu::vector::dot: Cannot calculate dot product of vectors of different dimensions."
			}
		}

		method cross { other } {
			# Return cross product with other vector.
			if {[my matchDimensions $other]} {
				if {[my nElements] > 2} {
					set cx [expr [my y]*[$other z] - [my z]*[$other y]]
					set cy [expr [my z]*[$other x] - [my x]*[$other z]]
					set cz [expr [my x]*[$other y] - [my y]*[$other x]]

					set v [::ctsimu::vector new [list $cx $cy $cz]]

					return $v
				}
			} else {
				error "::ctsimu::vector::cross: Cannot calculate cross product of vectors of different dimensions."
			}
		}

		method angle { other } {
			# Calculate angle between this vector and other vector, using the dot product definition.
			set dotprod [my dot $other]
			set n1 [my length]
			set n2 [$other length]

			set norm [expr $n1*$n2]

			if {$norm > 0} {
				set cs [expr $dotprod / $norm]
				set angle 0

				if {$cs >= 1.0} {
					set angle 0
				} elseif {$cs <= -1.0} {
					set angle 3.1415926535897932384626433832795028841971
				} else {
					set angle [expr acos($cs)]
				}

				return $angle
			}

			return 0
		}

		method rotate { axis angleInRad } {
			# Rotate this vector around given axis vector by given angle (in rad).
			if {$angleInRad != 0} {
				set rotation_matrix [::ctsimu::rotationMatrix $axis $angleInRad]
				my transform_by_matrix $rotation_matrix
				$rotation_matrix destroy
			}
		}

		method transform_by_matrix { M } {
			# Multiply matrix M to this vector v: r=Mv,
			# and set this vector to the result r of this transformation.
			set r [$M multiplyVector [self]]		
			my copy $r
			$r destroy
		}
	}
}