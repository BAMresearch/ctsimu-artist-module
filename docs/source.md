# ::ctsimu::source
A class to set up and generate an X-ray source. Inherits from [`::ctsimu::part`](part.md).

## Methods of the `::ctsimu::source` class

### Constructor

* `constructor { { name "CTSimU_Source" } { id "S" } }`

	A name for the source can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well. The `id` designates aRTist's identifier for the object (to find it in the part list).

### General

* `initialize { material_manager }` — Necessary initialization after constructing. If the source object shall be used fully (not just as a geometrical object), it needs to have access to the scenario's material manager.
* `reset` — Reset source to standard settings. Deletes all previously defined drifts, etc. Called internally before a new source definition is loaded from a JSON file.
* `hash` — Returns a hash of all properties that are relevant for the generation of the spectrum. If one of the X-ray source parameters changes, the hash changes as well and the source is re-generated for the new frame.
* `hash_spot` — Returns a hash of the spot profile properties. They are independent of the spectrum and therefore require a separate hash.
* `current_temp_file` — Returns the name of the current temporary spectrum file. Temporary files are used to avoid re-generation of a previously known spectrum for a given scenario.
* `set_in_aRTist` — Sets up the X-ray source in aRTist: if necessary, generates the X-ray spectrum and spot image.
* `compute_spectrum` — Generate the X-ray spectrum. Adaption of `proc ComputeSpectrum` from aRTist's `stuff/xsource.tcl`. Assumes that the `::XSource` properties are already set.
* `load_spectrum { file }` — Load spectrum from CSV or TSV and filter it by external filters, but not by windows.
* `make_gaussian_spot_profile { sigmaX sigmaY }` — Generate a spot profile image in aRTist from the given standard deviations `sigmaX` and `sigmaY` (in mm).
* `load_spot_image { }` — Load the external intensity map file into aRTist.

### Setters

* `set_frame { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set all properties of the X-ray source to match the given `frame` number, given a total of `nFrames`. All drifts are applied, no matter if they are known to the reconstruction software. The `stageCS` and `w_rotation_in_rad` are not relevant for the X-ray source and should be set to `0`. Because this function is inherited from [`::ctsimu::part`](part.md), they cannot be removed.
* `set_frame_for_recon { stageCS frame nFrames { w_rotation_in_rad 0 } }` — Set all properties of the X-ray source to match the given `frame` number, given a total of `nFrames`. Only those drifts which are known to the reconstruction software are applied. The `stageCS` and `w_rotation_in_rad` are not relevant for the X-ray source and should be set to `0`. Because this function is inherited from [`::ctsimu::part`](part.md), they cannot be removed.
* `set_from_json { jobj stage }` — Import the source definition and geometry from the given JSON object (`jobj`). The JSON object should contain the complete content from the scenario definition file (at least the geometry and source sections). `stage` is the [`::ctsimu::coordinate_system`](coordinate_system.md) that represents the stage in the world coordinate system.

## Properties

The class keeps a `_properties` dictionary (inherited from [`::ctsimu::part`](part.md)) to store the source settings. The methods `get` and `set` are used to retrieve and manipulate those properties.

Each property is a [`::ctsimu::parameter`](parameter.md) object that can also handle drifts. They come with standard values and [native units](native_units.md).

The following table gives an overview of the currently used keys, their standard values, native units, and valid options. For their meanings, please refer to the documentation of [CTSimU Scenario Descriptions](https://bamresearch.github.io/ctsimu-scenarios/).

| Property Key                    | Standard Value | Native Unit | Valid Options                                                     |
| :------------------------------ | :------------- | :---------- | :---------------------------------------------------------------- |
| `model`                         | `""`           | `"string"`  |                                                                   |
| `manufacturer`                  | `""`           | `"string"`  |                                                                   |
| `voltage`                       | `130`          | `"kV"`      |                                                                   |
| `voltage_max`                   | `200`          | `"kV"`      |                                                                   |
| `current`                       | `0.1`          | `"mA"`      |                                                                   |
| `target_material_id`            | `"W"`          | `"string"`  |                                                                   |
| `target_type`                   | `"reflection"` | `"string"`  | `"reflection"`, `"transmission"`                                  |
| `target_thickness`              | `10`           | `"mm"`      |                                                                   |
| `target_angle_incidence`        | `45`           | `"deg"`     |                                                                   |
| `target_angle_emission`         | `45`           | `"deg"`     |                                                                   |
| `spot_size_u`                   | `0`            | `"mm"`      |                                                                   |
| `spot_size_v`                   | `0`            | `"mm"`      |                                                                   |
| `spot_size_w`                   | `0`            | `"mm"`      |                                                                   |
| `spot_sigma_u`                  | `0`            | `"mm"`      |                                                                   |
| `spot_sigma_v`                  | `0`            | `"mm"`      |                                                                   |
| `spot_sigma_w`                  | `0`            | `"mm"`      |                                                                   |
| `multisampling`                 | `"20"`         | `"string"`  |                                                                   |
| `intensity_map_file`            | `""`           | `"string"`  |                                                                   |
| `intensity_map_datatype`        | `"float32"`    | `"string"`  | `"float32"`, `"float64"`, `"uint8"`, `"int8"`, `"uint16"`, `"int16"`, `"uint32"`, `"int32"` |
| `intensity_map_dim_x`           | `0`            | `""`        |                                                                   |
| `intensity_map_dim_y`           | `0`            | `""`        |                                                                   |
| `intensity_map_dim_z`           | `0`            | `""`        |                                                                   |
| `intensity_map_headersize`      | `0`            | `""`        |                                                                   |
| `intensity_map_endian`          | `"little"`     | `"string"`  | `"little"`, `"big"`                                               |
| `spectrum_monochromatic`        | `0`            | `"bool"`    |                                                                   |
| `spectrum_file`                 | `""`           | `"string"`  |                                                                   |
| `spectrum_resolution`           | `1.0`          | `""`        |                                                                   |