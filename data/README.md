# Data Manifest

Raw audio is kept outside Git history. The preliminary real-data experiment uses clean VoiceBank test utterances and two 16 kHz DEMAND environments. The project constructs its own controlled transitions; it does not use the pre-mixed noisy VoiceBank files.

## Sources

| Item | Source and version | Use in this project | Licence/checksum |
|---|---|---|---|
| VoiceBank clean test set | [University of Edinburgh DataShare](https://datashare.ed.ac.uk/items/6ed35425-bf14-4d2b-93a1-0a4984952757), DOI [10.7488/ds/2117](https://doi.org/10.7488/ds/2117) | Clean speech, resampled from 48 kHz to 16 kHz | Dataset terms on the official record; downloaded ZIP MD5 `34eb1c0ba7ef667e9b966866c542fc16` |
| DEMAND OOFFICE 16 kHz | [DEMAND record on Zenodo](https://zenodo.org/records/1227121), DOI [10.5281/zenodo.1227121](https://doi.org/10.5281/zenodo.1227121) | Office noise | CC BY-SA 3.0; MD5 `7b61cc2d182d5a654cb9c3101ddd4041` |
| DEMAND STRAFFIC 16 kHz | [DEMAND record on Zenodo](https://zenodo.org/records/1227121), DOI [10.5281/zenodo.1227121](https://doi.org/10.5281/zenodo.1227121) | Road-traffic noise | CC BY-SA 3.0; MD5 `2efa87262f272bbf9ba578088e81939c` |

## Local layout

```text
data/raw/clean_testset_wav/
data/raw/OOFFICE_16k/
data/raw/STRAFFIC_16k/
data/raw/downloads/
```

The current subset is sufficient for preliminary implementation and testing. The final evaluation will record the exact speaker files, noise intervals, transition conditions, random seeds, development split, and held-out split in a machine-readable manifest.

The current protocol is recorded in [`experiment_manifest.csv`](experiment_manifest.csv). Speaker `p232` is used for the preliminary development run; speaker `p257` is reserved for held-out testing. DEMAND excerpts used for final testing will not overlap the development excerpts.

## Reproducibility rule

Development mixtures may be used to choose change thresholds and controller rates. Final test mixtures must use different speakers or utterances, non-overlapping noise excerpts, and held-out transition pairs. Raw third-party audio must not be committed to this repository.
