# Requirements
* Python 3.6+
* the `conf_djpet.xml` file must be present in the working directory 

# create_modular_setup.py

The scripts takes no arguments and produces a JSON file with the Modular J-PET setup description compatible with J-PET Analysis Framework v10.

# add_datasources.py

The JSON file produced by `create_modular_setup.py` does not contain the `data_source` and `data_module` entries required by the new HLD unpacker. IF needed, they can be added to the setup by using:
```
    python3 add_datasources.py file_produced_by_create_modular_setup.json new_file.json
```
As a result, `new_file.json` will be produced containing all contents of the previous JSON + the `data_source` and `data_module` entries.
