# ::ctsimu::material

Materials come with an `id` that is referenced at other places in the JSON scenario file, a `name`, a `density` (which may drift) and can define multiple components in a `composition` array, each with their own chemical `formula` and `mass_fraction`:

    {
      "id":   "Air",
      "name": "Air",
      "density": {"value": 1.293, "unit": "kg/m^3"},
      "composition": [
        {
          "formula": {"value": "N2"},
          "mass_fraction": {"value": 0.7552}
        },
        {
          "formula": {"value": "O2"},
          "mass_fraction": {"value": 0.2314}
        },
        {
          "formula": {"value": "Ar"},
          "mass_fraction": {"value": 0.0128}
        },
        {
          "formula": {"value": "CO2"},
          "mass_fraction": {"value": 0.0006}
        }
      ]
    }

## Methods of the `::ctsimu::material` class

### Constructor

* `constructor { { id 0 } { name "New_Material" } { density 0 } }`

  The constructor accepts the following parameters:

  - `id`: material ID, as defined in the JSON scenario description.
  - `name`: trivial name of the material.
  - `density`: mass density in g/cm³.

### General

* `reset` — Reset density to `0` (with no drifts), clear all material composition entries.
* `add_to_aRTist` — Add material to aRTist's materials list.
* `set_frame { frame nFrames { forced 0 } }` — Set the `frame` number, given a total of `nFrames`. This will obey any possibly defined drifts for density and material composition. If `forced` is set to `1`, the material will be updated in aRTist, no matter if it has changed or not.
* `generate_aRTist_composition_string` — Generate the material composition string for aRTist, which contains the chemical formulas and mass fractions.

### Getters

* `id`
* `aRTist_id` — The material id for the aRTist material manager. The prefix `CTSimU_` is added to all material IDs to avoid overwriting existing materials.
* `name`
* `density`
* `aRTist_composition_string` — Material composition string for aRTist's materials list.

### Setters

* `set_id { id }`
* `set_name { name }`
* `set_density { density }` — Set a simple numerical value for the mass density. (No full parameter object can be passed here, only a simple number. Therefore no drifts.)
* `add_component { component }` — Add a `::ctsimu::material_component` object to the list of material components. See below for the `::ctsimu::material_component` class.
* `set_from_json { jsonobj }` — Set up the material from a JSON material definition object.


## Methods of the `::ctsimu::material_component` class

### Constructor

* `constructor { parent_material_id parent_material_name { formula "Fe" } { mass_fraction 1 } }`

  The constructor accepts the following parameters:

  - `parent_material_id`: ID of the material to which this material component belongs.
  - `parent_material_name`: name of the material to which this material component belongs (for nicer error messages).
  - `formula`: empirical chemical formula that describes the composition of the component.
  - `mass_fraction`: mass fraction of the component. All mass fractions of a material should add up to one.

### General

* `set_frame { frame nFrames }` — Set the `frame` number, given a total of `nFrames`. This will obey any possibly defined drifts for the chemical formula or mass fraction.

### Getters

* `formula`
* `mass_fraction`

### Setters

* `set_from_json { jsonobj }` — Set up the material component from a JSON material component definition object.
* `set_from_json_legacy { jsonobj }` — Legacy composition definition for file format version <=1.0. The composition was simply a string value, no mass fraction was defined.