# Source Code Guide

## Main entry points

| File | Purpose |
|---|---|
| `run_transition_demo.m` | Dataset-independent smoke experiment; writes temporary output to `tmp/transition_demo/`. |
| `run_full_transition_study.m` | Earlier controlled VoiceBank/DEMAND transition study. |
| `run_detector_revision.m` | Latest development and frozen-validation detector audit. |
| `summarise_detector_revision.m` | Rebuilds the compact detector-audit summaries and figures. |
| `run_controller_ablation.m` | Controller ablation (always-fast, SNR + change, release ramp, gain floor) with spectral-subtraction, VOICEBOX and DeepFilterNet3 references; develop / validate / unseen test. |
| `summarise_controller_ablation.m` | Aggregate tables, paired cluster-bootstrap statistics, condition-wise hypothesis tests and ranking analysis. |
| `plot_controller_ablation.m` | Recovery, settling-time, trade-off and average-vs-transition figures for the ablation. |
| `plot_onset_noise_estimate.m` | Noise estimate around a noise onset (fixed, always-fast and the unused noise-floor guard). |
| `run_auditor_example.m` | Real-data Auditor example using a detected office-to-cafeteria change, with spectral subtraction, VOICEBOX and optional DeepFilterNet3. |

## Core implementation

| File | Purpose |
|---|---|
| `transition_wiener.m` | Common STFT/Wiener enhancer with fixed, SNR, change-aware, oracle, always-fast and SNR + change controller modes. Frame decisions only use past frames. By default the noise estimate is initialised from the first 250 ms; the main experiments (`run_controller_ablation.m`, `run_detector_revision.m`) turn on `causalStartup`, which uses only past frames in the noise-only start. |
| `dynamic_enhancement_auditor.m` | One-call analysis of a known noise change: mixture, all controllers, metrics, figures and audio. |
| `transition_metrics.m` | Whole-signal and transition-centred metrics (SI-SDR, STOI, settling time, speech error, noise suppression). |
| `scene_change_detector.m` | Original log-spectrum, spectral-flux, modulation, and combined detector cues. |
| `robust_change_features.m` | Persistent noise-floor and speech-related features used by the revised audit. |
| `trigger_change_features.m` | Converts revised features into causal detector events. |
| `generate_dynamic_scene.m` | Builds controlled noise transitions with known timing and SNR. |
| `build_detector_cases.m` | Defines development, validation and unseen-test cases without excerpt overlap. |
| `validate_dfn_outputs.m` | Checks the DeepFilterNet3 WAV files before the ablation uses them: all files present, mono, right sample rate and length, finite values. It does not check which model or input produced them. |
| `score_change_events.m` | Performs one-to-one event matching and false-alarm scoring. |
| `apply_stft_gain.m` | Applies saved gains separately for speech/noise trade-off analysis. |
| `add_noise_at_snr.m` | Produces mixtures at a requested SNR. |
| `spectral_subtraction.m` | Basic fixed baseline retained for ELEC5305 context. |

Automated checks are in `tests/`. Superseded compatibility wrappers and the first real-data prototype are preserved on the repository's `bench` branch rather than in `main`.
