# Native Units

Native units are the internal foundation units that the CTSimU module uses to operate. They need to be specified when instantiating objects of type `::ctsimu::parameter`, `::ctsimu::drift` and `::ctsimu::scenevector`.

The following list specifies all currently used native units:

| native unit | description                                                             |
|:------------|:------------------------------------------------------------------------|
| `""`        | No unit, or unit given in JSON file is ignored.                         |
| `"mm"`      | Unit of length.                                                         |
| `"rad"`     | Angular unit (radians).                                                 |
| `"deg"`     | Angular unit (degrees).                                                 |
| `"s"`       | Unit of time.                                                           |
| `"mA"`      | Unit of current.                                                        |
| `"kV"`      | Unit of voltage.                                                        |
| `"g/cm^3"`  | Unit of mass density.                                                   |
| `"lp/mm"`   | Unit of resolution (e.g., MTF frequency).                               |
| `"bool"`    | For boolean JSON values (true, false translated to 0 and 1 in Tcl).     |
| `"string"`  | Special type for string parameters such as spectrum file names.         |