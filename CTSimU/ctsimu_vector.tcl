package require TclOO

namespace eval ::ctsimu {
	::oo::class create vector {
		constructor { { valueList {} } } {
			my variable _values
			my set_values $valueList
		}

		destructor {

		}

		method print { } {
			# Return a printable string for this vector.
			my variable _values

			set s "("
			set i 0
			foreach v $_values {
				if {$i>0} {append s ", "}
				incr i
				append s $v
			}
			append s ")"
			return $s
		}

		method size { } {
			# Return number of vector elements.
			my variable _values
			return [llength $_values]
		}
		
		method get_copy { } {
			# Return a copy of this vector
			set newVector [::ctsimu::vector new [list 0]]
			$newVector set_values [my get_values]
			return $newVector
		}

		method match_dimensions { other } {
			# Do vector dimensions match?
			return [expr [my size] == [$other size]]
		}

		# Getters
		# -------------------------
		# Getters currently perform no checks for valid vector indices
		# to improve speeds during calculations. Maybe add later...?
		method element { i } {
			# Return vector element at position i.
			my variable _values
			if {[my size] > $i} {
				return [lindex $_values $i]
			} else {
				error "Vector element index $i does not exist in vector of [my size] elements."
				# return 0
			}
		}

		method get_values { } {
			# Return list of all vector elements.
			my variable _values
			return $_values
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
		method set_values { l } {
			# Set vector elements to given value list.
			my variable _values
			set _values $l
			
			# Convert all elements to double to avoid problems:
			for {set i 0} {$i < [my size]} {incr i} {
				lset _values $i [expr double([my element $i])]
			}
		}
		
		method set { x {y "none"} {z "none"} {w "none"} } {
			# Make a vector with three components (x, y, z).
			my variable _values
			
			set _values [list [expr double($x)]]
			if {$y != "none"} {
				my add_element $y
				
				if {$z != "none"} {
					my add_element $z
					
					if {$w != "none"} {
						my add_element $w
					}
				}
			}
		}

		method add_element { value } {
			# Append another element (i.e. dimension) to the vector with the given value.
			my variable _values
			lappend _values [expr double($value)]
		}

		method set_element { i value } {
			# Set vector element at index i to the given value.
			my variable _values
			if {[my size] > $i} {
				lset _values $i [expr double($value)]
			}
		}

		method set_x { value } {
			# Shortcut to set element 0 to given value.
			my set_element 0 [expr double($value)]
		}

		method set_y { value } {
			# Shortcut to set element 1 to given value.
			my set_element 1 [expr double($value)]
		}

		method set_z { value } {
			# Shortcut to set element 2 to given value.
			my set_element 2 [expr double($value)]
		}
		
		method set_w { value } {
			# Shortcut to set element 3 to given value.
			my set_element 3 [expr double($value)]
		}
		
		method copy { other } {
			# Copy other vector to this vector.
			my set_values [$other get_values]
		}

		# Vector Operations
		# -------------------------

		method add { other } {
			# Add other vector to this vector.
			if {[my match_dimensions $other]} {
				for { set i 0 } { $i < [my size]} { incr i } {
					my set_element $i [expr [my element $i] + [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::add: Cannot treat vectors of different dimensions."
			}
		}

		method subtract { other } {
			# Subtract other vector from this vector.
			if {[my match_dimensions $other]} {
				for { set i 0 } { $i < [my size]} { incr i } {
					my set_element $i [expr [my element $i] - [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::subtract: Cannot treat vectors of different dimensions."
			}
		}

		method multiply { other } {
			# Multiply other vector to this vector.
			if {[my match_dimensions $other]} {
				for { set i 0 } { $i < [my size]} { incr i } {
					my set_element $i [expr [my element $i] * [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::multiply: Cannot treat vectors of different dimensions."
			}
		}

		method divide { other } {
			# Divide this vector by other vector.
			if {[my match_dimensions $other]} {
				for { set i 0 } { $i < [my size]} { incr i } {
					my set_element $i [expr [my element $i] / [$other element $i]]
				}
			} else {
				error "::ctsimu::vector::divide: Cannot treat vectors of different dimensions."
			}
		}

		method scale { factor } {
			# Scale this vector's length by the given factor.
			for { set i 0 } { $i < [my size]} { incr i } {
				my set_element $i [expr [my element $i] * $factor]
			}
		}

		method invert { } {
			# Point vector in opposite direction.
			for { set i 0 } { $i < [my size]} { incr i } {
				my set_element $i [expr -[my element $i]]
			}
		}

		method square { } {
			# Square all vector elements
			for { set i 0 } { $i < [my size]} { incr i } {
				my set_element $i [expr [my element $i]**2]
			}
		}

		method to { other } {
			# Returns a vector that points from this point to other point.
			set d [my get_copy]
			$d subtract $other
			return $d
		}

		method sum { } {
			# Return sum of vector elements
			my variable _values
			set sum 0.0
			foreach v $_values {
				set sum [expr $sum + double($v)]
			}
			return $sum
		}

		method length { } {
			# This vector's absolute length
			my variable _values
			set sqSum 0.0
			foreach v $_values {
				set sqSum [expr $sqSum + double($v)*double($v)]
			}
			return [expr sqrt($sqSum)]
		}

		method get_unit_vector { } {
			# Return a new unit vector based on this vector.
			set u [my get_copy]
			if {[catch {$u to_unit_vector} errmsg]} {
				error $errmsg
			}
			return $u
		}

		method to_unit_vector { } {
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
			if {[my match_dimensions $other]} {
				set diff [my get_copy]
				$diff subtract $other
				return [$diff length]
			} else {
				error "::ctsimu::vector::distance: Cannot treat vectors of different dimensions."
			}	
		}

		method dot { other } {
			# Return dot product with other vector.
			if {[my match_dimensions $other]} {
				set dotprod 0.0
				for { set i 0 } { $i < [my size]} { incr i } {
					set dotprod [expr $dotprod + [my element $i] * [$other element $i]]
				}
				return $dotprod
			} else {
				error "::ctsimu::vector::dot: Cannot calculate dot product of vectors of different dimensions."
			}
		}

		method cross { other } {
			# Return cross product with other vector.
			if {[my match_dimensions $other]} {
				if {[my size] > 2} {
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

		method rotate { axis angle_in_rad } {
			# Rotate this vector around given axis vector by given angle (in rad).
			if {$angle_in_rad != 0} {
				set R [::ctsimu::rotation_matrix $axis $angle_in_rad]
				my transform_by_matrix $R
				$R destroy
			}
		}

		method transform_by_matrix { M } {
			# Multiply matrix M to this vector v: r=Mv,
			# and set this vector to the result r of this transformation.
			set r [$M multiply_vector [self]]		
			my copy $r
			$r destroy
		}
	}
}