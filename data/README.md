# Data Manifest

Raw audio is kept outside Git history. The final experiments use clean VoiceBank test utterances and three 16 kHz DEMAND environments: office, traffic and cafeteria. The project constructs controlled transitions and does not use the pre-mixed noisy VoiceBank files.

## Sources

| Item | Source and version | Use in this project | Licence/checksum |
|---|---|---|---|
| VoiceBank clean test set | [University of Edinburgh DataShare](https://datashare.ed.ac.uk/items/6ed35425-bf14-4d2b-93a1-0a4984952757), DOI [10.7488/ds/2117](https://doi.org/10.7488/ds/2117) | Clean speech, resampled from 48 kHz to 16 kHz | Dataset terms on the official record; downloaded ZIP MD5 `34eb1c0ba7ef667e9b966866c542fc16` |
| DEMAND OOFFICE 16 kHz | [DEMAND record on Zenodo](https://zenodo.org/records/1227121), DOI [10.5281/zenodo.1227121](https://doi.org/10.5281/zenodo.1227121) | Office noise | CC BY-SA 3.0; MD5 `7b61cc2d182d5a654cb9c3101ddd4041` |
| DEMAND STRAFFIC 16 kHz | [DEMAND record on Zenodo](https://zenodo.org/records/1227121), DOI [10.5281/zenodo.1227121](https://doi.org/10.5281/zenodo.1227121) | Road-traffic noise | CC BY-SA 3.0; MD5 `2efa87262f272bbf9ba578088e81939c` |
| DEMAND PCAFETER 16 kHz | [DEMAND record on Zenodo](https://zenodo.org/records/1227121), file `PCAFETER_16k.zip` | Cafeteria noise, used **only** in the unseen office-to-cafeteria test split of the controller ablation | CC BY-SA 3.0; MD5 `99927d148128254141a9417d051510bb` |

## Local layout

```text
data/raw/clean_testset_wav/
data/raw/OOFFICE/
data/raw/STRAFFIC/
data/raw/PCAFETER/      (only needed for run_controller_ablation("test"))
data/raw/downloads/
```

Each final split records the speaker files, noise intervals, transition conditions, random seeds and measured pre/post SNR in a machine-readable manifest:

- [`development_manifest.csv`](../results/controller_ablation/development_manifest.csv)
- [`validation_manifest.csv`](../results/controller_ablation/validation_manifest.csv)
- [`unseen_test_manifest.csv`](../results/controller_ablation/unseen_test_manifest.csv)

Speaker `p232` is used for controller selection. Speaker `p257` is used for validation and the final test, with non-overlapping utterances and noise excerpts. The final test changes from office to cafeteria noise; cafeteria is not used during development. This is an unseen transition pair but not an unseen-speaker test.

## Older experiments

The October detector audit has its own manifests in [`results/detector_revision/`](../results/detector_revision/), and [`experiment_manifest.csv`](experiment_manifest.csv) in this folder describes the first pilot study.

## Rules I followed

- Settings (detector thresholds and controller rates) were only chosen on the p232 development mixtures.
- Validation and test mixtures use different utterances and noise excerpts from development, and the final test uses a noise type (cafeteria) that development never saw.
- No raw dataset audio is committed to this repository.
