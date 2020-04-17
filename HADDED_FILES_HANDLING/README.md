# Scripts for handling of ROOT files resulting from hadd-ing large batches

## purge.C

ROOT script to remove all ROOT file contents except for TDirectory-based objects.

In practice, when applied to a file produced by hadd-ing multiple output files from the J-PET Analysis Framework, it will remove anything besides directories with histograms (especially multiple instances of ParamBank which are a common nuisance with hadd-ed files will be deleted) allowing for faster opening of files and inspection of histograms.  

### Usage:

```sh
root "purge.C(\"path_to_hadded_root_file.root\")"
```

The script modifies the indicated file in-place.
