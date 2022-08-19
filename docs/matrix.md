# ::ctsimu::matrix
A basic matrix class.

Initialize a matrix by providing the number of rows and columns to the constructor. The matrix will be filled with zeros.

    set cols 4
    set rows 3
    set M [::ctsimu::matrix new $cols $rows]

Print the matrix with:

    puts [$M print]

## Methods

### General

* `print` — Get a printable string for this matrix.
* `nRows` — Get the number of rows in the matrix.
* `nCols` — Get the number of columns in the matrix.
* `nElements` — Get the total number of matrix elements (nCols × nRows).

### Getter Functions

* `element { col row }` — Returns the matrix element at the requested column and row.
* `getRowVector { row }` — Returns the vector of the requested `row`. This is *not* a copy of the row vector. Manipulating its elements will manipulate the matrix. Use the vector method `getCopy` to get a new, independent copy of the row vector.
* `getColVector { col }` — Returns a vector for the requested column. This is a new vector object and not a copy. Manipulating its elements will *not* manipulate the matrix. This vector should be destroyed independently when not needed anymore.

### Setter Functions

* `setElement { col row value }` — Set matrix element in given column and row to `value`.
* `setRow { index rowVector }` — Set row at given `index` to another `rowVector` (of type `::ctsimu::vector`). Do not delete or manipulate the `rowVector` object after this, as this will directly alter the matrix!
* `setCol { index colVector }` — Set column at given `index` to another `colVector` (of type `::ctsimu::vector`). This will copy the values from the `colVector` to the matrix. Manipulating or deleting the `colVector` object afterwards does *not* alter the matrix.
* `addRow { rowVector }` — Add another row to the matrix. The given `rowVector` must be a `::ctsimu::vector` with `nCols` elements (i.e., the number of matrix columns). Do not delete or manipulate the `rowVector` object after this, as this will directly alter the matrix!
* `addCol { colVector }` — Add another column to the matrix. The given `colVector` must be a `::ctsimu::vector` with `nRows` elements (i.e., the number of matrix rows).

### Arithmetics

* `multiplyVector { colVector }` — Return the result of the multiplication of this matrix with the given `colVector`. The column vector must have `nCols` elements. The returned result vector will have `nRows` elements.