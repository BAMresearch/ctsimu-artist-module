# ::ctsimu::image
A class to handle the loading of RAW or TIFF images into aRTist, using the file parameters given in the JSON file.

For RAW files, the following parameters need to be specified:

| Parameter    | Possible values                                                             |
| :----------- | :-------------------------------------------------------------------------- |
| `width`      | Integer number of pixels or voxels.                                         |
| `height`     | Integer number of pixels or voxels.                                         |
| `depth`      | Integer number of pixels or voxels.                                         |
| `datatype`   | `"float32"`, `"float64"`, `"uint8"`, `"int8"`, `"uint16"`, `"int16"`, `"uint32"`, `"int32"` |
| `endian`     | `"little"`, `"big"`                                                         |
| `headersize` | Integer number of bytes to skip at the beginning of the file.               |

## Methods of the `::ctsimu::image` class

### Constructor

* `constructor { file_name { width 0 } { height 0 } { depth 1 } { datatype "float32" } { endian "little" } { headersize 0 } }`

### Getters

* `filename`
* `width`
* `height`
* `depth`
* `datatype`
* `aRTist_datatype` — Returns the datatype string as expected by aRTist's image reader functions.
* `endian`
* `headersize`

### Setters

* `set_filename { file_name }`
* `set_width { width }`
* `set_height { height }`
* `set_depth { depth }`
* `set_datatype { datatype }`
* `set_endian { endian }`
* `set_headersize { headersize }`

### Image Loader

* `load_image` — Load the image and return an image object as used by aRTist.
* `load_raw` — Load a RAW file with the current properties. This function is used by `load_image` when a RAW file needs to be imported.