# Modulation-Aware Adaptive Speech Enhancement under Non-Stationary Noise

**ELEC5305 Audio and Acoustic Signal Processing Project**

**Student:** Liya Xu | **SID:** 530519058 | **GitHub:** [Liyaxuxu](https://github.com/Liyaxuxu)

This project investigates a lightweight and interpretable speech-enhancement method for environments in which the background noise changes over time. Instead of applying one fixed suppression setting to an entire recording, the proposed system estimates the current signal-to-noise ratio (SNR) and temporal spectral change, then adapts its noise tracking and time-frequency gain frame by frame.

## Research question

> Can short-term modulation cues and frame-level SNR estimates be used to adapt noise tracking and time-frequency suppression so that speech quality and intelligibility improve over fixed-parameter spectral subtraction and Wiener filtering under non-stationary noise?

## Motivation

A fixed enhancement setting rarely works equally well for stationary office noise, competing cafe speech, and rapidly changing street noise. Strong suppression may remove more noise but distort speech, while weak suppression preserves speech but leaves substantial interference. The project therefore studies how an adaptive controller can manage this trade-off without relying on a large neural network.

The work directly applies ELEC5305 concepts including windowing, STFT analysis, spectral estimation, modulation analysis, filtering, Wiener masks, and objective audio evaluation.

## System overview

```text
Noisy speech
    |
    v
Hann-windowed STFT
    |
    +--> Noise PSD and frame-SNR estimation
    |
    +--> Temporal spectral/modulation change detection
    |
    v
Adaptive gain controller
    |
    +--> Spectral-subtraction gain
    +--> Wiener gain
    +--> Gain interpolation and temporal smoothing
    |
    v
Inverse STFT
    |
    v
Enhanced speech
```

The fixed spectral-subtraction and Wiener implementations act as reproducible baselines. The proposed method uses SNR and modulation-related change information to control how quickly the noise estimate updates and how strongly the signal is suppressed.

## Current implementation

| Component | Status | Description |
|---|---|---|
| Controlled noise mixing | Implemented | Adds noise to clean audio at a requested global SNR. |
| Fixed spectral subtraction | Implemented | Uses oversubtraction and a spectral floor. |
| Fixed Wiener filtering | Implemented | Uses decision-directed SNR estimation and noise tracking. |
| SNR-adaptive enhancement prototype | Implemented | Blends suppression behaviour according to estimated frame SNR. |
| Synthetic demonstration | Implemented | Runs all methods without requiring a downloaded dataset. |
| MATLAB smoke tests | Implemented | Checks SNR mixing and finite enhancement outputs. |
| Modulation-aware change controller | In progress | Will adapt estimator speed and gain smoothing after noise transitions. |
| VoiceBank-DEMAND batch evaluation | Planned | Will evaluate held-out speakers and unseen noise recordings. |
| STOI, PESQ and confidence intervals | Planned | Will provide the final objective comparison. |

No final performance claim is made from the synthetic demo. Final conclusions will be based on the documented real-data experiment.

## Experimental design

### Data

The main dataset is [VoiceBank-DEMAND](https://doi.org/10.7488/ds/2117), which provides paired clean and noisy speech. Additional controlled mixtures will be generated from clean speech and selected DEMAND environmental noises.

Audio data is not committed to this repository because of its size and original licensing conditions. See [`data/README.md`](data/README.md) for the expected directory layout.

### Conditions

- Input SNRs: `-5`, `0`, `5`, and `10 dB`
- Noise categories: stationary, broadband, competing speech, and rapidly changing environmental noise
- Generalisation: held-out speakers and noise recordings not used for parameter selection
- Reproducibility: fixed random seeds, documented splits, and development-only parameter tuning

### Compared methods

1. Unprocessed noisy speech
2. Fixed-parameter spectral subtraction
3. Fixed-parameter Wiener filtering
4. SNR-only adaptive enhancement
5. Proposed SNR and modulation-aware adaptive enhancement

### Evaluation

| Measure | Purpose |
|---|---|
| Input/output and segmental SNR | Measure noise reduction relative to clean speech. |
| STOI | Estimate speech intelligibility. |
| PESQ, where available | Estimate perceptual speech quality. |
| Real-time factor | Measure computational cost. |
| Spectrograms and listening examples | Examine residual noise and speech artefacts. |
| Bootstrap confidence intervals | Quantify uncertainty across utterances. |

Ablation experiments will remove modulation detection, SNR adaptation, and temporal smoothing individually to determine which components contribute to the result.

## Quick start

### Requirements

- MATLAB with `stft`, `istft`, and Signal Processing Toolbox functions
- No dataset is required for the synthetic demo

### Run the demo

Open MATLAB in the repository root and run:

```matlab
addpath('src');
run_demo;
```

The script generates a reproducible speech-like signal, adds time-varying noise, runs the fixed and adaptive methods, prints SNR measurements, and saves a waveform comparison under `results/`.

### Run the tests

```matlab
addpath('src');
run('tests/run_tests.m');
```

## Repository structure

```text
.
|-- ELEC5305_Project_Proposal.tex   Current self-contained LaTeX proposal
|-- proposal.md                     Proposal source in Markdown
|-- proposal.pdf                    Rendered proposal
|-- references.bib                  Complete academic bibliography
|-- src/
|   |-- add_noise_at_snr.m          Controlled noisy-mixture generation
|   |-- spectral_subtraction.m      Fixed spectral-subtraction baseline
|   |-- wiener_filter.m             Fixed Wiener-filter baseline
|   |-- adaptive_enhance.m          Current adaptive prototype
|   `-- run_demo.m                  Reproducible synthetic demonstration
|-- tests/run_tests.m               MATLAB smoke tests
|-- data/README.md                  Dataset and folder instructions
|-- docs/index.md                   GitHub Pages source
`-- results/                        Generated figures, audio and metrics
```

## Project materials

- [Current LaTeX proposal](ELEC5305_Project_Proposal.tex)
- [Rendered proposal](proposal.pdf)
- [GitHub Pages project summary](https://liyaxuxu.github.io/elec5305-project-530519058/)
- [Complete BibTeX bibliography](references.bib)

## Selected references

1. S. F. Boll, "Suppression of Acoustic Noise in Speech Using Spectral Subtraction," *IEEE Transactions on Acoustics, Speech, and Signal Processing*, 1979. [doi:10.1109/TASSP.1979.1163209](https://doi.org/10.1109/TASSP.1979.1163209)
2. P. Scalart and J. V. Filho, "Speech Enhancement Based on a Priori Signal to Noise Estimation," *ICASSP*, 1996. [doi:10.1109/ICASSP.1996.543199](https://doi.org/10.1109/ICASSP.1996.543199)
3. P. C. Loizou and G. Kim, "Reasons Why Current Speech-Enhancement Algorithms Do Not Improve Speech Intelligibility and Suggested Solutions," *IEEE Transactions on Audio, Speech, and Language Processing*, 2011. [doi:10.1109/TASL.2010.2045180](https://doi.org/10.1109/TASL.2010.2045180)
4. K. K. Paliwal, B. Schwerin, and K. Wojcicki, "Modulation Domain Spectral Subtraction for Speech Enhancement," *Interspeech*, 2009. [doi:10.21437/Interspeech.2009-413](https://doi.org/10.21437/Interspeech.2009-413)
5. C. Valentini-Botinhao, "Noisy Speech Database for Training Speech Enhancement Algorithms and TTS Models," University of Edinburgh DataShare, 2017. [Dataset and documentation](https://doi.org/10.7488/ds/2117)
6. C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, "An Algorithm for Intelligibility Prediction of Time-Frequency Weighted Noisy Speech," *IEEE Transactions on Audio, Speech, and Language Processing*, 2011. [doi:10.1109/TASL.2011.2114881](https://doi.org/10.1109/TASL.2011.2114881)

## Reproducibility and academic integrity

Published methods and datasets are cited in the proposal and [`references.bib`](references.bib). Dataset files retain their original licences. Final experiment configurations, random seeds, data splits, and generated results will be documented so that the reported findings can be reproduced and distinguished from published results.

## Author and licence

Copyright (c) 2026 **Liya Xu**. Code is released under the [MIT License](LICENSE). Dataset files retain their original licences.
