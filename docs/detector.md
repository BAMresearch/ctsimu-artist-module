# ::ctsimu::detector
A class to set up and generate a detector. Inherits from [`::ctsimu::part`](part.md).

## Methods of the `::ctsimu::detector` class

### Constructor

* `constructor { { name "CTSimU_Detector" } { id "D" } }`

	A name for the detector can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well. The `id` designates aRTist's identifier for the object (to find it in the part list).

### General

* `initialize { material_manager { SDD 1000 } { current 1 } }` — Necessary initialization after constructing, when the detector object shall be used fully (not just as a geometrical object). The `SDD` and X-ray tube `current` refer to the conditions at frame zero, and are stored by the detector if a re-calculation of gray value characteristics becomes necessary. The initial frame-zero parameters are kept because the imin/imax method gives the minimum and maximum gray values for free-beam conditions in frame zero.
* `reset` — Reset detector to standard settings. Deletes all previously defined drifts, etc. Called internally before a new detector definition is loaded from a JSON file.
* `set_in_aRTist { xray_kV }` — Set up the detector parameters in aRTist, possibly generate characteristics curves. The parameter `xray_kV` should give the maximum X-ray tube acceleration voltage in kV (or, photon energy in keV). This information is used to only compute the detector's sensitivity for a range that actually occurs in the simulation.
* `generate { SDD xray_source_current xray_kV }` — Generate a detector dictionary for aRTist. Input parameters:
	- `SDD`: source-detector distance at frame zero.
	- `xray_source_current`: X-ray tube current at frame zero.
	- `xray_kV`: maximum tube acceleration voltage in kV (or maximum photon energy in keV) during the simulation.

### Getters

* `physical_width` — Detector's physical width in mm.
* `physical_height` — Detector's physical height in mm.
* `pixel_area_m2` — Area of a pixel in m².
* `max_gray_value` — The maximum grey value that can be stored using the image bit depth.
* `hash` — Returns a hash of all properties that are relevant for the generation of the detector. If one of the parameters changes, the hash changes as well and the detector is re-generated for the new frame.
* `current_temp_file` — Returns the name of the current temporary detector file. Temporary files are used to avoid re-generation of a previously known detector for a given scenario.

### Setters

* `set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set all properties of the detector to match the given `frame` number, given a total of `nFrames`. All drifts are applied, no matter if they are known to the reconstruction software. The `stageCS` and `w_rotation_in_rad` are not relevant for the detector and should be set to `0`. Because this function is inherited from [`::ctsimu::part`](part.md), they cannot be removed.
* `set_frame_for_recon { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set all properties of the detector to match the given `frame` number, given a total of `nFrames`. Only those drifts which are known to the reconstruction software are applied. The `stageCS` and `w_rotation_in_rad` are not relevant for the detector and should be set to `0`. Because this function is inherited from [`::ctsimu::part`](part.md), they cannot be removed.
* `set_from_json { jobj stage }` — Import the detector definition and geometry from the given JSON object (`jobj`). The JSON object should contain the complete content from the scenario definition file (at least the geometry and detector sections). `stage` is the [`::ctsimu::coordinate_system`](coordinate_system.md) that represents the stage in the world coordinate system.

## Properties

The class keeps a `_properties` dictionary (inherited from [`::ctsimu::part`](part.md)) to store the detector settings. The methods `get` and `set` are used to retrieve and manipulate those properties.

Each property is a [`::ctsimu::parameter`](parameter.md) object that can also handle drifts. They come with standard values and [native units](native_units.md).

The following table gives an overview of the currently used keys, their standard values, native units, and valid options. For their meanings, please refer to the documentation of [CTSimU Scenario Descriptions](https://bamresearch.github.io/ctsimu-scenarios/).

| Property Key                      | Standard Value | Native Unit | Valid Options                                                     |
| :-------------------------------- | :------------- | :---------- | :---------------------------------------------------------------- |
| `model`                           | `""`           | `"string"`  |                                                                   |
| `manufacturer`                    | `""`           | `"string"`  |                                                                   |
| `type`                            | `"ideal"`      | `"string"`  |                                                                   |
| `columns`                         | `1000`         | `""`        |                                                                   |
| `rows`                            | `1000`         | `""`        |                                                                   |
| `pitch_u`                         | `0.1`          | `"mm"`      |                                                                   |
| `pitch_v`                         | `0.1`          | `"mm"`      |                                                                   |
| `bit_depth`                       | `16`           | `""`        |                                                                   |
| `integration_time`                | `1.0`          | `"s"`       |                                                                   |
| `dead_time`                       | `0.0`          | `"s"`       |                                                                   |
| `image_lag`                       | `0.0`          | `""`        |                                                                   |
| `frame_average`                   | `1`            | `""`        |                                                                   |
| `multisampling`                   | `"3x3"`        | `"string"`  |                                                                   |
| `primary_energy_mode`             | `0`            | `"bool"`    | `0`, `1`                                                          |
| `primary_intensity_mode`          | `0`            | `"bool"`    | `0`, `1`                                                          |
| `gray_value_mode`                 | `"imin_imax"`  | `"string"`  | `"imin_imax"`, `"linear"`, `"file"`                               |
| `imin`                            | `0`            | `""`        |                                                                   |
| `imax`                            | `60000`        | `""`        |                                                                   |
| `factor`                          | `1.0`          | `""`        |                                                                   |
| `offset`                          | `0.0`          | `""`        |                                                                   |
| `gv_characteristics_file`         | `""`           | `"string"`  |                                                                   |
| `efficiency_characteristics_file` | `""`           | `"string"`  |                                                                   |
| `noise_mode`                      | `"off"`        | `"string"`  | `"off"`, `"snr_at_imax"`, `"file"`                                |
| `snr_at_imax`                     | `100`          | `""`        |                                                                   |
| `noise_characteristics_file`      | `""`           | `"string"`  |                                                                   |
| `unsharpness_mode`                | `"off"`        | `"string"`  | `"off"`, `"basic_spatial_resolution"`, `"mtf10freq"`, `"mtffile"` |
| `basic_spatial_resolution`        | `0.1`          | `"mm"`      |                                                                   |
| `mtf_file`                        | `""`           | `"string"`  |                                                                   |
| `long_range_unsharpness`          | `0`            | `"mm"`      |                                                                   |
| `long_range_ratio`                | `0`            | `""`        |                                                                   |
| `bad_pixel_map`                   | `""`           | `"string"`  |                                                                   |
| `bad_pixel_map_type`              | `""`           | `"string"`  |                                                                   |
| `scintillator_material_id`        | `""`           | `"string"`  |                                                                   |
| `scintillator_thickness`          | `0`            | `"mm"`      |                                                                   |