# ctsimu_source
A class to set up and generate an X-ray source. Inherits from [`::ctsimu::part`](part.md).

## Methods of the `::ctsimu::source` class

### Constructor

* `constructor { { name "Source" } }`

	A name for the source can be passed as an argument to the constructor. Useful for debugging, because it appears in error messages as well. Usually, `"Source"` is fine.

### General

* `reset` — Reset source to standard settings. Deletes all previously defined drifts, etc. Called internally before a new source definition is loaded from a JSON file.
* `set_from_json { jobj stage }` — Import the source definition and geometry from the given JSON object (`jobj`). The JSON object should contain the complete content from the scenario definition file (at least the geometry and source sections). `stage` is the `::ctsimu::coordinate_system` that represents the stage in the world coordinate system. Necessary because the source could be attached to the stage coordinate system.

## Properties

The class keeps a `_properties` dictionary (inherited from [`::ctsimu::part`](part.md)) to store the source settings. The methods `get` and `set` are used to retrieve and manipulate those properties.

Each property is a [`::ctsimu::parameter`](parameter.md) object that can also handle drifts. They come with standard values and [native units](native_units.md).

The following table gives an overview of the currently used keys, their standard values, native units, and valid options. For their meanings, please refer to the documentation of [CTSimU Scenario Descriptions](https://bamresearch.github.io/ctsimu-scenarios/).

| Property Key                    | Standard Value | Native Unit | Valid Options                                                     |
| :------------------------------ | :------------- | :---------- | :---------------------------------------------------------------- |
| `model`                         | `""`           | `"string"`  |                                                                   |
| manufacturer                    | `""`           | `"string"`  |                                                                   |