# Noise-Aware Adaptive Speech Enhancement

ELEC5305 project proposal and reproducible MATLAB baseline by **Liya Xu**.

## Research question

Can real-time estimates of noise type and signal-to-noise ratio (SNR) be used to switch or interpolate between Wiener filtering and spectral subtraction so that speech quality and intelligibility improve over fixed-parameter enhancement under non-stationary noise?

## Why this project

Fixed enhancement settings rarely work equally well in a quiet office, a cafe, and a street. This project builds a transparent signal-processing pipeline that estimates changing noise conditions and adjusts its enhancement strength frame by frame. It stays within ELEC5305 topics such as STFT analysis, windowing, filtering, spectral estimation, Wiener masks, and objective evaluation.

## Planned experiment

- **Data:** VoiceBank-DEMAND clean and noisy speech, with additional controlled mixtures at -5, 0, 5, and 10 dB SNR.
- **Baselines:** unprocessed noisy speech, fixed spectral subtraction, and fixed Wiener filtering.
- **Proposed method:** a noise-aware controller that selects or blends enhancement parameters from estimated frame SNR and spectral characteristics.
- **Evaluation:** segmental/input-output SNR, STOI, optional PESQ, processing time, and spectrogram inspection.
- **Generalisation test:** tune parameters on selected speakers/noises and evaluate on held-out speakers and unseen noise recordings.

## Repository structure

```text
src/                 MATLAB implementation
tests/               Lightweight MATLAB tests
data/README.md       Dataset and licensing instructions
docs/index.md        GitHub Pages project page
proposal.md          Source proposal
proposal.pdf         Submission-ready proposal (generated after SID confirmation)
references.bib       Academic references
results/             Generated figures and metrics
```

## Quick start

In MATLAB, open this repository and run:

```matlab
addpath('src');
run_demo;
```

The demo synthesises a speech-like signal, adds time-varying noise, runs all three enhancement methods, prints SNR results, and stores a comparison figure in `results/`. It does not require a downloaded dataset.

Run the tests with:

```matlab
addpath('src');
run('tests/run_tests.m');
```

## Reproducibility and academic integrity

Dataset audio is not committed because of size and licensing. Exact download links, expected folders, split rules, random seeds, and experiment settings will be documented. External algorithms and code are cited; results generated in this project will be clearly distinguished from published results.

## Author

Liya Xu (`Liyaxuxu`)

## Licence

Code is released under the MIT License. Dataset files retain their original licences.
