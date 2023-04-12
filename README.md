# genproductions

This is a branch for enabling **ReadOnly NLO** gridpack production with `MadGraph5_aMC@NLO`. The official repo of `genproductions` is [here](https://github.com/cms-sw/genproductions).

The way to get a gridpack doesn't differ from the official repo, just run [`gridpack_generation.sh`](https://github.com/shimashimarin/genproductions/blob/RO_NLOgridpack/bin/MadGraph5_aMCatNLO/gridpack_generation.sh) as usual.

Please notice that, besides the `gridpack`, there will be an additional compressed file, noted as `pointer` file. E.g., if the output `gridpack` is

```
WtoLNu-2Jets_amcatnloFXFX-pythia8_slc7_amd64_gcc10_CMSSW_12_4_8_tarball.tar.xz
```
the `pointer` file is
```
WtoLNu-2Jets_amcatnloFXFX-pythia8_slc7_amd64_gcc10_CMSSW_12_4_8_pointer.gz
```

There are just two files inside the `pointer` file: [`mk_workdir.py`](https://github.com/shimashimarin/genproductions/blob/RO_NLOgridpack/bin/MadGraph5_aMCatNLO/mk_workdir.py) and `runcmsgrid.sh`. The former one is used to make soft-links to the unpacked `gridpack`. The latter one is generated from [`runcmsgrid_NLO.sh`](https://github.com/shimashimarin/genproductions/blob/RO_NLOgridpack/bin/MadGraph5_aMCatNLO/runcmsgrid_NLO.sh).

In a sample production configuration file, simply replace the `gridpack` with this `pointer` file. But before doing this, please **note:**

- unpack the `gridpack` somewhere,
- uppack the `pointer` file, update the path to the unpacked `gridpack` in the `runcmsgrid.sh`, which corresponds to [this line](https://github.com/shimashimarin/genproductions/blob/RO_NLOgridpack/bin/MadGraph5_aMCatNLO/runcmsgrid_NLO.sh#L71),
- recompress `mk_workdir.py` and `runcmsgrid.sh` to the `pointer` file.
