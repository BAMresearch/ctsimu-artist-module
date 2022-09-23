# ctsimu_detector
A class to set up and generate a detector. Inherits from [`::ctsimu::part`](part.md).

## Methods of the `::ctsimu::detector` class

### Constructor

* `constructor { { name "Detector" } }`

	A name for the detector can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well. Usually, `"Detector"` is fine.

### General

* `reset` — Reset detector to standard settings. Deletes all previously defined drifts, etc. Called internally before a new detector definition is loaded from a JSON file.
* `set_from_json { jobj world stage }` — Import the detector definition and geometry from the given JSON object (`jobj`). The JSON object should contain the complete content from the scenario definition file (at least the geometry and detector sections).

## Properties

The class keeps a `_properties` dictionary (inherited from [`::ctsimu::part`](part.md)) to store the detector settings. The methods `get` and `set` are used to retrieve and manipulate those properties.

Each property is a [`::ctsimu::parameter`](parameter.md) object that can also handle drifts. They come with standard values and [native units](native_units.md).

The following table gives an overview of the currently used keys, their standard values, native units, and valid options. For their meanings, please refer to the documentation of [CTSimU Scenario Descriptions](https://bamresearch.github.io/ctsimu-scenarios/).

| Property Key                    | Standard Value | Native Unit | Valid Options                                                     |
| :------------------------------ | :------------- | :---------- | :---------------------------------------------------------------- |
| `model`                         | `""`           | `"string"`  |                                                                   |
| manufacturer                    | `""`           | `"string"`  |                                                                   |
| type                            | `"ideal"`      | `"string"`  |                                                                   |
| columns                         | `1000`         | `""`        |                                                                   |
| rows                            | `1000`         | `""`        |                                                                   |
| pitch_u                         | `0.1`          | `"mm"`      |                                                                   |
| pitch_v                         | `0.1`          | `"mm"`      |                                                                   |
| bit_depth                       | `16`           | `""`        |                                                                   |
| integration_time                | `1.0`          | `"s"`       |                                                                   |
| dead_time                       | `0.0`          | `"s"`       |                                                                   |
| image_lag                       | `0.0`          | `""`        |                                                                   |
| gray_value_mode                 | `"imin_imax"`  | `"string"`  | `"imin_imax"`, `"linear"`, `"file"`                               |
| imin                            | `0`            | `""`        |                                                                   |
| imax                            | `60000`        | `""`        |                                                                   |
| factor                          | `1.0`          | `""`        |                                                                   |
| offset                          | `0.0`          | `""`        |                                                                   |
| gv_characteristics_file         | `""`           | `"string"`  |                                                                   |
| efficiency                      | `1.0`          | `""`        |                                                                   |
| efficiency_characteristics_file | `""`           | `"string"`  |                                                                   |
| noise_mode                      | `"off"`        | `"string"`  | `"off"`, `"snr_at_imax"`, `"file"`                                |
| snr_at_imax                     | `100`          | `""`        |                                                                   |
| noise_characteristics_file      | `""`           | `"string"`  |                                                                   |
| unsharpness_mode                | `"off"`        | `"string"`  | `"off"`, `"basic_spatial_resolution"`, `"mtf10freq"`, `"mtffile"` |
| basic_spatial_resolution        | `0.1`          | `"mm"`      |                                                                   |
| mtf10_freq                      | `10.0`         | `"lp/mm"`   |                                                                   |
| mtf_file                        | `""`           | `"string"`  |                                                                   |
| bad_pixel_map                   | `""`           | `"string"`  |                                                                   |
| bad_pixel_map_type              | `""`           | `"string"`  |                                                                   |
| scintillator_material_id        | `""`           | `"string"`  |                                                                   |