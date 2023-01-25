# CTSimU aRTist Module 1.0

This is a module for the radiographic simulator [aRTist](http://artist.bam.de/) which reads and sets up the scenario from a [CTSimU JSON description](https://bamresearch.github.io/ctsimu-scenarios/). With the module, it is also possible to simulate the complete CT scan as described in the JSON scenario.

## Requirements

+ aRTist Version 2.12 or higher

## Installation

1. Download the aRTist package file (`CTSimU-<version>.artp`) for the latest [Release](https://github.com/BAMresearch/ctsimu-artist-module/releases).
2. Drag and drop the `.artp` file into your aRTist window to install the module.

## Known Limitations

+ Continuous-motion scans are not supported, only stop&go mode.
+ Drifts between frames of an averaged projection are not handled. Therefore, motion blurring within one projection cannot be simulated.
+ Parallel beam geometries are not supported. As a workaround, a very high source-detector distance could be set in the JSON file.

## Deploying a new version

The `deploy.sh` script can be used to create an `.artp` file for aRTist for a certain version number. The new version number is passed as an argument:

	./deploy.sh "<version>"

For example:

	./deploy.sh "0.8.14"

Note: the aRTist package file (`.artp`) should not be part of the git repository. Instead, it can be uploaded to Github as a file attachment to a new release.

## Feature Support of JSON Scenarios

The following table lists the JSON parameters defined by the [CTSimU file format](https://bamresearch.github.io/ctsimu-scenarios/) and their support by the aRTist module.

| Parameter                                             | Support     | Drift Support                                      |
| :---------------------------------------------------- | :---------- | :------------------------------------------------- |
| `environment material_id`                             | yes         | only in material definition (density, composition) |
| `environment temperature`                             | no          | no                                                 |
| `geometry detector center x/y/z`                      | yes         | yes                                                |
| `geometry detector vector_u x/y/z`                    | yes         | yes (not recommended, better to use `deviations`)  |
| `geometry detector vector_w x/y/z`                    | yes         | yes (not recommended, better to use `deviations`)  |
| `geometry detector deviations`                        | yes         | yes                                                |
| `geometry source type`                                | no          | no                                                 |
| `geometry source beam_divergence`                     | no          | no                                                 |
| `geometry source center x/y/z`                        | yes         | yes                                                |
| `geometry source vector_u x/y/z`                      | yes         | yes (not recommended, better to use `deviations`)  |
| `geometry source vector_w x/y/z`                      | yes         | yes (not recommended, better to use `deviations`)  |
| `geometry source deviations`                          | yes         | yes                                                |
| `geometry stage center x/y/z`                         | yes         | yes                                                |
| `geometry stage vector_u x/y/z`                       | yes         | yes (not recommended, better to use `deviations`)  |
| `geometry stage vector_w x/y/z`                       | yes         | yes (not recommended, better to use `deviations`)  |
| `geometry stage deviations`                           | yes         | yes                                                |
| `detector model`                                      | yes         | no                                                 |
| `detector manufacturer`                               | yes         | no                                                 |
| `detector type`                                       | yes         | no                                                 |
| `detector columns`                                    | yes         | yes                                                |
| `detector rows`                                       | yes         | yes                                                |
| `detector pixel_pitch u/v`                            | yes         | yes                                                |
| `detector bit_depth`                                  | yes         | no                                                 |
| `detector integration_time`                           | yes         | yes                                                |
| `detector dead_time`                                  | no          | no                                                 |
| `detector image_lag`                                  | no          | no                                                 |
| `detector gray_value imax`                            | yes         | yes                                                |
| `detector gray_value imin`                            | yes         | yes                                                |
| `detector gray_value factor`                          | yes         | yes                                                |
| `detector gray_value offset`                          | yes         | yes                                                |
| `detector gray_value intensity_characteristics_file`  | yes         | yes                                                |
| `detector gray_value efficiency_characteristics_file` | yes         | yes                                                |
| `detector noise snr_at_imax`                          | yes         | yes                                                |
| `detector noise noise_characteristics_file`           | yes         | yes                                                |
| `detector gain`                                       | no          | no                                                 |
| `detector unsharpness basic_spatial_resolution`       | yes         | yes                                                |
| `detector unsharpness mtf`                            | yes         | yes                                                |
| `detector bad_pixel_map`                              | no          | no                                                 |
| `detector scintillator material_id`                   | yes         | only in material definition (density, composition) |
| `detector scintillator thickness`                     | yes         | yes                                                |
| `detector filters front`                              | yes         | yes                                                |
| `detector filters rear`                               | no          | no                                                 |
| `source model`                                        | yes         | no                                                 |
| `source manufacturer`                                 | yes         | no                                                 |
| `source voltage`                                      | yes         | yes                                                |
| `source current`                                      | yes         | yes                                                |
| `source target material_id`                           | yes         | only in material definition (density, composition) |
| `source target type`                                  | yes         | no                                                 |
| `source target thickness`                             | yes         | yes                                                |
| `source target angle incidence`                       | yes         | yes                                                |
| `source target angle emission`                        | yes         | yes                                                |
| `source spot size u/v/w`                              | yes         | yes                                                |
| `source spot sigma u/v/w`                             | yes         | yes                                                |
| `source spot intensity_map file`                      | yes         | yes                                                |
| `source spot intensity_map type`                      | yes         | no                                                 |
| `source spot intensity_map dim_x/y/z`                 | yes         | no                                                 |
| `source spot intensity_map endian`                    | yes         | no                                                 |
| `source spot intensity_map headersize`                | yes         | no                                                 |
| `source spectrum monochromatic`                       | yes         | no                                                 |
| `source spectrum file`                                | yes         | yes                                                |
| `source spectrum window material_id`                  | yes         | only in material definition (density, composition) |
| `source spectrum window thickness`                    | yes         | yes                                                |
| `source spectrum filters material_id`                 | yes         | only in material definition (density, composition) |
| `source spectrum filters thickness`                   | yes         | yes                                                |
| `samples name`                                        | yes         | no                                                 |
| `samples file`                                        | yes         | yes                                                |
| `samples unit`                                        | yes         | no                                                 |
| `samples scaling_factor r/s/t`                        | yes         | yes                                                |
| `samples material_id`                                 | yes         | only in material definition (density, composition) |
| `samples position center u/v/w/x/y/z`                 | yes         | yes                                                |
| `samples position vector_r u/v/w/x/y/z`               | yes         | yes (not recommended, better to use `deviations`)  |
| `samples position vector_t u/v/w/x/y/z`               | yes         | yes (not recommended, better to use `deviations`)  |
| `samples position deviations`                         | yes         | yes                                                |
| `acquisition start_angle`                             | yes         | no                                                 |
| `acquisition stop_angle`                              | yes         | no                                                 |
| `acquisition direction`                               | yes         | no                                                 |
| `acquisition scan_mode`                               | `"stop+go"` | no                                                 |
| `acquisition scan_speed`                              | no          | no                                                 |
| `acquisition number_of_projections`                   | yes         | no                                                 |
| `acquisition include_final_angle`                     | yes         | no                                                 |
| `acquisition frame_average`                           | yes         | no                                                 |
| `acquisition dark_field`                              | only ideal  | no                                                 |
| `acquisition dark_field correction`                   | no          | no                                                 |
| `acquisition flat_field`                              | yes         | no                                                 |
| `acquisition flat_field correction`                   | yes         | no                                                 |
| `acquisition pixel_binning u/v`                       | no          | no                                                 |
| `acquisition pixel_binning u/v`                       | no          | no                                                 |
| `acquisition scattering`                              | yes (McRay) | no                                                 |
| `materials id`                                        | yes         | no                                                 |
| `materials name`                                      | yes         | no                                                 |
| `materials density`                                   | yes         | yes                                                |
| `materials composition`                               | yes         | yes                                                |
| `simulation aRTist multisampling_detector`            | yes         | yes                                                |
| `simulation aRTist multisampling_spot`                | yes         | yes                                                |
| `simulation aRTist spectral_resolution`               | yes         | no                                                 |
| `simulation aRTist scattering_mcray_photons`          | yes         | yes                                                |
| `simulation aRTist scattering_image_interval`         | yes         | yes                                                |
| `simulation aRTist long_range_unsharpness extension`  | yes         | yes                                                |
| `simulation aRTist long_range_unsharpness ratio`      | yes         | yes                                                |
| `simulation aRTist primary_energies`                  | yes         | no                                                 |
| `simulation aRTist primary_intensities`               | yes         | no                                                 |


## Version History

### 1.0.0
+ General support for file format version 1.0
+ Parameter drifts are supported
+ Scatter images can be calculated for several frames, instead of calculating a new scatter image for each frame.
+ Option to restart aRTist after each batch run. (To free memory.)
+ New supported JSON features:
	- new geometrical deviations (translations and rotations along arbitrary axes or pivot points)
	- source: spot images
	- detector: MTF
	- detector: quantum efficiency
	- detector: external noise characteristics files
	- `known_to_reconstruction` parameter for geometrical deviations and drifts is obeyed when calculating projection matrices.

### 0.8.16
+ Added aRTist-specific JSON option to create primary intensity images (as an alternative to primary energy images).

### 0.8.15
+ Minor bug fix: Parts not loaded centered at (0,0,0) since version 0.7.10 due to a spelling mistake. This bug had no impact on part placement: centering parts after loading is not necessary and has therefore been fully removed in this version.

### 0.8.14
+ Removed iSRb correction scaling factor of 0.6830822016 (for aRTist 2.12+).
+ Added aRTist-specific JSON option to create primary energy images.

### 0.8.13
+ Added options for recon volume data type (`uint16`, `float32`).
+ Cleaned up VGI output.
+ Physical pixel size is used in factor/offset detector grey value method, instead of iSRb-scaled pixel area from the DetectorCalc module.

### 0.8.12
+ Added new function: insertBatchJob, to allow better control of batch job parameters.

### 0.8.11

+ Added spectral resolution for spectrum generator as aRTist-specific parameter.

### 0.8.10

+ Finite spot size scenarios: spot sampling will be set to 20 and detector sampling to 2x2 (instead of 30 and 'source dependent' as before).

### 0.8.9

+ Bug fix: relative paths in recon configs now correct for batches with multiple runs.
+ Bug fix: CERA format specifier for float32 raw projection images.

### 0.8.8

+ Bug fix: tubes with no window no longer wrongfully show 'Al 4 mm' in their name.

### 0.8.7

+ Fixed aRTist unsharpness (moved from Gaussian sigma correction factor 1/sqrt(2) to 0.683).

### 0.8.6

+ Added support for running the flat field correction during a scan.

### 0.8.5

+ Added support for long range unsharpness.

### 0.8.4

+ Scans can start at user-defined projection numbers so simulations can be continued after crashes.
+ Index numbers in projection filenames only take 4 digits (or more, only if necessary).
+ Scattering is automatically deactivated for dark images.

### 0.8.2 - 0.8.3

+ No release; used for development tests.

### 0.8.1

+ Added `ffRescaleFactor` to generated flat field correction scripts.

### 0.8.0

+ Bug fix: memory leak when running a simulation
+ Batch Manager: 'StartRun' specifies the run id where the batch should start. Enables picking up simulations after a crash.
+ Support for simulation software-specific parameters: 'multisampling_detector', 'multisampling_spot', 'scattering_mcray_photons'

### 0.7.15

+ Bug fix: division by zero when SOD is 0.

### 0.7.14

+ Multiple JSON scenarios can be added at once to the batch queue.

### 0.7.13

+ Added fileutil as a package requirement. Some systems showed problems without it.

### 0.7.12

+ Added the object bounding box to clFDK/VG reconstruction configuration files.

### 0.7.11

+ Added support for CERA's RDabcu0v0 coordinate system to provide a reconstruction configuration alternative to the projection matrix approach. 

### 0.7.10

+ For CT scans, reconstruction configurations for SIEMENS CERA, BAM clFDK, and also VG Studio (untested) are created using projection matrices.
+ Bug fixes concerning unusual geometries.
+ Last used settings for output file types and reconstruction configurations are saved when aRTist closes.

### 0.7.9

+ Removed option to (not) import all samples from JSON, to avoid confusion. Loading a scenario will now always load _complete_ scenario.

### 0.7.8

+ 'rl_json' is now used for JSON handling, instead of tcllib's json module.

### 0.7.7

+ Added a batch manager to handle job queues.
+ Environment material is considered as an additional spectrum filter when calculating the detector characteristics. Therefore, the specified grey values at maximum intensity are reached for any environment material, not only in vacuum.

### 0.7.6

+ Fixed memory leak when running a CT scan.
+ JSON files are now closed after being read, and no longer blocked from deletion/renaming.
+ Applied Florian Wohlgemuth's fix of CanClose() for using the module in batch simulations.

### 0.7.5

+ Fixed detector saturation when using a filter in front of an ideal detector.

### 0.7.4

+ CTSimU metadata files are created along CT scan projection image stacks.
+ Fixed a bug concerning orientation vectors pointing in opposite directions (e.g. sample flipped in stage coordinate system).

### 0.7.2

+ Bug fixes concerning coordinate system positioning.

### 0.7.1

+ Implemented sample scaling (according to definition in JSON's sample section).

### 0.7.0

+ Support for CTSimU JSON scenario definition version 0.7

### 0.6.0

+ Support for CTSimU JSON scenario definition version 0.6

### 0.5.0

+ Support for CTSimU JSON scenario definition version 0.5

### 0.4.0

+ Support for CTSimU JSON scenario definition version 0.4