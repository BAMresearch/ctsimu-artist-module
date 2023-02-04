# ::ctsimu::matrix
This submodule provides a basic matrix class and a function to generate a 3D rotation matrix.

## Functions

This module adds the following function to the `::ctsimu` namespace:

* `rotation_matrix { axis angle_in_rad }` — Creates a matrix that performs a 3D vector rotation around the given axis vector by the given angle (in rad).

## Methods of the `::ctsimu::matrix` class

### Constructor

* `constructor { nCols nRows }`

    Initialize a matrix by providing the number of rows and columns to the constructor. The matrix will be filled with zeros.

        set cols 4
        set rows 3
        set M [::ctsimu::matrix new $cols $rows]

    Print the matrix with:

        puts [$M print]

### General

* `print` — Get a printable string for this matrix.
* `n_rows` — Get the number of rows in the matrix.
* `n_cols` — Get the number of columns in the matrix.
* `size` — Get the total number of matrix elements (n_cols × n_rows).

### Getter Functions

* `element { col_index row_index }` — Returns the matrix element at the requested column and row.
* `get_row { row_index }` — Returns the vector of the requested `row` index. This is *not* a copy of the row vector. Manipulating its elements will manipulate the matrix. Use the vector method `get_copy` to get a new, independent copy of the row vector.
* `get_col { col_index }` — Returns a vector for the requested column index. This is a new vector object and not a copy. Manipulating its elements will *not* manipulate the matrix. This vector should be destroyed independently when not needed anymore.

### Setter Functions

* `set_element { col_index row_index value }` — Set matrix element in given column and row to `value`.
* `set_row { index row_vector }` — Set row at given `index` to another `row_vector` (of type `::ctsimu::vector`). Do not delete or manipulate the `row_vector` object after this, as this will directly alter the matrix!
* `set_col { index col_vector }` — Set column at given `index` to another `col_vector` (of type `::ctsimu::vector`). This will copy the values from the `col_vector` to the matrix. Manipulating or deleting the `col_vector` object afterwards does *not* alter the matrix.
* `add_row { row_vector }` — Add another row to the matrix. The given `row_vector` must be a `::ctsimu::vector` with `n_cols` elements (i.e., the number of matrix columns). Do not delete or manipulate the `row_vector` object after this, as this will directly alter the matrix!
* `add_col { col_vector }` — Add another column to the matrix. The given `col_vector` must be a `::ctsimu::vector` with `n_rows` elements (i.e., the number of matrix rows).

### Arithmetics

* `multiply_vector { col_vector }` — Return the result of the multiplication of this matrix with the given `col_vector`. The column vector must have `n_cols` elements. The returned result vector will have `n_rows` elements.