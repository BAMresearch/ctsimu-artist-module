# CTSimU JSON Loader, Ver. 0.8.13

This is a module for the radiographic simulator [aRTist](http://artist.bam.de/) which reads and sets up the scenario from a [CTSimU JSON description](https://bamresearch.github.io/ctsimu-scenarios/). With the module, it is also possible to simulate the complete CT scan as described in the JSON scenario.


## Installation

Drag and drop the .artp file into your aRTist window to install the module.

The module relies on the `rl_json` extension, which comes by default since aRTist 2.10.2.

## Known Limitations

+ None of the drift definitions of the JSON scenario description are implemented yet.
+ Continuous-motion scans are not supported.
+ Drifts between frames of an averaged projection are not handled. Therefore, motion blurring within one projection cannot be simulated.
+ Parallel beam geometries are not supported.
+ External focal spot profile images are not being loaded yet.

## Deploying a new version

The `deploy.sh` script can be used to create an `.artp` file for aRTist for a certain version number. The new version number is passed as an argument:

	./deploy.sh version

For example:

	./deploy.sh 0.8.13

## Version History

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