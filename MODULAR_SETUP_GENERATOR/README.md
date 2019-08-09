# create_setup.pl

A Perl script which takes the following input:
* a JSON file with the old 3-layer J-PET setup description (in the new format after refactoring done by @kkacprzak)
* an OpenDocument Spreadsheet (ODS) file with description of channel routing inside a single Digital-J-PET module
and produces a new JSON file with setup description for a combined 4-layer setup were the 4th later is of digital FTAB modules.

## Requirements

The script works with Perl 5. The following Perl modules are required to run this script:

* JSON
* Spreadsheet::Read
* Spreadsheet::ReadSXC
* File::Basename
* File::Map

The required dependencies can be installed using CPAN:

```sh
cpan install JSON Spreadsheet::Read Spreadsheet::ReadSXC File::Basename File::Map
```
## Usage

```sh
perl create_setup.pl -l old_setup.json -m digital_module_routing.ods [-i run_number]
```
