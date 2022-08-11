# ::ctsimu::vector
A basic vector class.

Intialize a vector by passing a list to its constructor:

    set e1 [::ctsimu::vector new [list 1 0 0]]

Or create an empty vector and initialize it later:

    set e2 [::ctsimu::vector new]
    $e2 set 0 1 0

Print the vector with:

    $e1 print

## Methods

### General

* `print` — Get a printable string for this vector.
* `nElements` — Get the number of vector elements (i.e., number of dimensions).
* `getCopy` — Get a new vector object that is a copy of this vector. Do not forget to `destroy` when you won't need it anymore ;-)
* `matchDimensions { other }` — Does number of vector elements (dimensions) match with `other` vector? Returns `1` if true, `0` if false.

### Getter Functions

* `element {i}` — Get vector element at position `i`.
* `getValues` — Get list of all vector elements.
* `x` — Shortcut to get vector element `0`.
* `y` — Shortcut to get vector element `1`.
* `z` — Shortcut to get vector element `2`.

### Setter Functions

* `setValues { l }` — Set vector elements to given value list `l`.
* `set { x y z }` — Make a vector with three components (x, y, z).
* `set4vec { x y z w }` — Make a vector with four components (x, y, z, w).
* `addElement { value }` — Append another element to the vector with the given `value`.
* `setElement { i value }` — Set vector element at index `i` to the given `value`.
* `setx { value }` — Shortcut to set vector element at index `0` to given `value`.
* `sety { value }` — Shortcut to set vector element at index `1` to given `value`.
* `setz { value }` — Shortcut to set vector element at index `2` to given `value`.
* `copy { other }` — Make this vector a copy of the `other` vector.

### Arithmetics and Geometry

* `add { other }` — Add `other` vector to this vector.
* `subtract { other }` — Subtract `other` vector from this vector.
* `multiply { other }` — Multiply `other` vector to this vector.
* `divide { other }` — Divide this vector by `other` vector.
* `scale { factor }` — Scale this vector's length by the given `factor`.
* `invert` — Point vector in opposite direction.
* `square` — Square all vector elements.
* `to { other }` — Returns a vector that points from this point to other point.
* `sum` — Return sum of vector elements.
* `length` — Return this vector's absolute length.
* `getUnitVector` — Return a new unit vector based on this vector.
* `toUnitVector` — Convert this vector into a unit vector.
* `distance { other }` — Distance between the points where this vector and the `other` vector point.
* `dot { other }` — Return dot product `with` other vector.
* `cross { other }` — Return cross product with other vector.
* `angle { other }` — Calculate angle between this vector and `other` vector, using the dot product definition.
* `rotate { axis angleInRad }` — Rotate this vector around given `axis` vector by given angle (in rad).
* `transform_by_matrix { M }` — Multiply matrix `M` to this vector `v`: `r=Mv`, and set this vector to the result `r` of this transformation.