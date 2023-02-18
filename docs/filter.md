# ::ctsimu::filter
Filters define a material and thickness.

## Methods of the `::ctsimu::filter` class

### Constructor

* `constructor { { material_id "Fe" } { thickness 1.0 } }`

    Initialized the material. Standard contructor parameters: Iron (Fe) of 1.0 mm thickness.

### General

* `set_frame { frame nFrames }` — Prepares the thickness parameter for the given `frame` number (out of a total of `nFrames`). Handles possible drifts.

### Getters

* `material_id` — ID of the material for the filter, as referenced in the JSON file.
* `thickness` — Current filter thickness in mm.

### Setters

* `set_material_id { mat_id }`
* `set_thickness { thickness }`
* `set_from_json { jsonobj }` — Sets the filter properties from a given JSON filter object.