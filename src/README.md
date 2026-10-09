# Source Code Guide

## Main entry points

| File | Purpose |
|---|---|
| `run_transition_demo.m` | Dataset-independent smoke experiment; writes temporary output to `tmp/transition_demo/`. |
| `run_full_transition_study.m` | Earlier controlled VoiceBank/DEMAND transition study. |
| `run_detector_revision.m` | Latest development and frozen-validation detector audit. |
| `summarise_detector_revision.m` | Rebuilds the compact detector-audit summaries and figures. |

## Core implementation

| File | Purpose |
|---|---|
| `transition_wiener.m` | Common causal STFT/Wiener enhancer with fixed, SNR, change-aware, and oracle controller modes. |
| `scene_change_detector.m` | Original log-spectrum, spectral-flux, modulation, and combined detector cues. |
| `robust_change_features.m` | Persistent noise-floor and speech-related features used by the revised audit. |
| `trigger_change_features.m` | Converts revised features into causal detector events. |
| `generate_dynamic_scene.m` | Builds controlled noise transitions with known timing and SNR. |
| `build_detector_cases.m` | Defines development and validation cases without excerpt overlap. |
| `score_change_events.m` | Performs one-to-one event matching and false-alarm scoring. |
| `apply_stft_gain.m` | Applies saved gains separately for speech/noise trade-off analysis. |
| `add_noise_at_snr.m` | Produces mixtures at a requested SNR. |
| `spectral_subtraction.m` | Basic fixed baseline retained for ELEC5305 context. |

Automated checks are in `tests/`. Superseded compatibility wrappers and the first real-data prototype are preserved on the repository's `bench` branch rather than in `main`.
