# How Quickly Should a Speech Enhancer Adapt?

## Modulation-Aware Speech Enhancement in Dynamic Acoustic Scenes

**ELEC5305 Audio and Acoustic Signal Processing Project**

**Student:** Liya Xu | **SID:** 530519058 | **GitHub:** [Liyaxuxu](https://github.com/Liyaxuxu)

**Start here:** Open the executed MATLAB Live Script [`ELEC5305_Project_Summary.mlx`](ELEC5305_Project_Summary.mlx) for a single guided view of the research question, implementation, experiments, figures, results, limitations, and next steps. Its build source is [`tools/build_project_summary.m`](tools/build_project_summary.m).

**Week 10 submission:** The [Project Feedback Two checkpoint](docs/feedback-two.md) gives a brief submission description, maps the first feedback to repository evidence, and identifies the specific questions that remain.

**Proposals:** The original version is available as [PDF](Proposal/Proposal.pdf) and [LaTeX source](Proposal/Proposal.tex). The feedback-aligned version is available as [proposal_2 PDF](Proposal/proposal_2.pdf) and [LaTeX source](Proposal/proposal_2.tex).

## Review this project in three steps

1. Open [`ELEC5305_Project_Summary.mlx`](ELEC5305_Project_Summary.mlx) for the complete executed walkthrough.
2. Read [`src/transition_wiener.m`](src/transition_wiener.m) and [`src/scene_change_detector.m`](src/scene_change_detector.m) for the main enhancer and detector.
3. Inspect [`results/detector_revision/`](results/detector_revision/) for the latest frozen audit and [`results/`](results/) for the earlier transition study.

Earlier superseded scripts, results, and duplicated website assets are preserved on the [`bench` branch](https://github.com/Liyaxuxu/elec5305-project-530519058/tree/bench). They are intentionally excluded from `main` so that the assessed project has one clear path through the current work.

## Latest: false-alarm audit

The latest experiment adds no-change controls, a persistent noise-floor cue, a speech-related threshold, causal startup checks, and frozen validation on unused speech/noise excerpts. It contains 48 development and 48 validation cases. The revised detector is an experimental option; the default controller is preserved.

| Validation result | Original combined | Revised |
|---|---:|---:|
| Detected scheduled changes | 20/30 | 23/30 |
| No-change false alarms/min | 62.38 | 41.90 |
| Matched latency (s) | 0.617 | 0.175 |
| STOI | 0.83446 | 0.83108 |

**The complete enhancer has not improved.** Detection false alarms fell by 32.8% overall, but STOI and whole-signal SI-SDR declined. Clean-speech-only false alarms increased from 65.71 to 98.57/min despite improvements in the office and traffic controls. These failures are retained and discussed in the [full audit, protocol, ablations, uncertainty estimates and reproduction instructions](results/detector_revision/README.md).

The results below are the earlier pilot, retained for provenance. They use different excerpts, initialization and scoring; do not compare their 60% detection rate or false-alarm counts directly with this revision. The old batch initialization was not fully causal at startup. The revision verifies past-only decisions with future-perturbation tests and adds frame-availability time to detection latency.

## Project focus

This project studies the transient behaviour of a causal STFT speech enhancer when the acoustic environment changes abruptly. The main question is:

> Can a lightweight modulation/change-aware controller reduce adaptation delay and speech distortion compared with fixed and SNR-only Wiener baselines?

A second question is whether whole-utterance metrics hide short but important failures immediately after a scene change. The system is deliberately based on interpretable DSP so that its noise estimate, change score, Wiener gain, smoothing state, and adaptation rate can be inspected directly.

## Current progress

| Component | Status | Current evidence |
|---|---|---|
| Topic and research question | Complete | Scope revised around adaptation speed in controlled dynamic scenes. |
| Literature review | Complete for Feedback Two | Classical enhancement, modulation processing, streaming latency, neural reference, and recent adaptation work are synthesised in [`literature_review.md`](literature_review.md). |
| Dataset collection | Complete for preliminary testing | Official VoiceBank clean test speech and DEMAND OOFFICE/STRAFFIC recordings; provenance and split are documented in [`data/`](data/). |
| Controlled SNR mixer | Complete | Unit test verifies requested global SNR. |
| Dynamic scene generator | Complete | Creates a known noise A to noise B transition with pre/post SNR metadata. |
| Fixed spectral subtraction | Complete | Retained as a basic ELEC5305 baseline. |
| Fixed Wiener enhancer | Complete | Uses one common STFT/Wiener pipeline. |
| SNR-adaptive Wiener controller | Preliminary | Changes PSD-update and gain-smoothing rates using estimated frame SNR. |
| Change-aware Wiener controller | Preliminary | Uses a log-spectral change score, adaptive threshold, and hold time. |
| Oracle change-triggered Wiener | Complete | Uses the known simulated transition time as a diagnostic reference, not a guaranteed quality upper bound. |
| Automated tests | Complete | Mixing, output validity, scene metadata, and all controller modes pass. |
| Real VoiceBank/DEMAND evaluation | Expanded preliminary | Five conditions, three repetitions, separate development/held-out speakers, and non-overlapping noise excerpts. |
| Change-cue ablation | Complete for current data | Log-spectrum, spectral flux, short-time modulation, and combined cues evaluated independently. |
| Transition diagnostics | Complete for current data | STOI, SI-SDR, settling time, steady-state score, speech error, residual-noise suppression, and runtime. |

## Weeks 1--9 checkpoint

| Weeks | Required activity | Evidence in this repository |
|---|---|---|
| 1--2 | Consider project topic | Revised title, focused research question, four-system comparison, and oracle diagnostic. |
| 3--5 | Literature review and dataset collection | [`literature_review.md`](literature_review.md), [`references.bib`](references.bib), dataset provenance, checksums, and [`data/experiment_manifest.csv`](data/experiment_manifest.csv). |
| 6--9 | Initial implementation and testing | Causal STFT/Wiener implementation, controlled transition generator, three real-data conditions, automated tests, CSV results, plots, and listening examples. |

This checkpoint means the scheduled work has been attempted and documented. It does not mean that the final held-out experiment or controller tuning is complete.

## Feedback-driven updates and code map

The table below shows what changed after the first project feedback and where each part can be checked. A fuller response, including preliminary results and current limitations, is available in the [Project Feedback Two checkpoint](docs/feedback-two.md).

| Update completed | Main code and evidence |
|---|---|
| Built one common Wiener pipeline with fixed, SNR-adaptive, change-aware, and oracle controller modes; kept spectral subtraction as a separate baseline. | [`src/transition_wiener.m`](src/transition_wiener.m), [`src/spectral_subtraction.m`](src/spectral_subtraction.m) |
| Added controlled SNR mixing, dynamic noise scenes, reproducible cases, and exact transition metadata. | [`src/add_noise_at_snr.m`](src/add_noise_at_snr.m), [`src/generate_dynamic_scene.m`](src/generate_dynamic_scene.m), [`src/build_detector_cases.m`](src/build_detector_cases.m) |
| Evaluated the original change cues and implemented the revised causal detector and event scoring. | [`src/scene_change_detector.m`](src/scene_change_detector.m), [`src/robust_change_features.m`](src/robust_change_features.m), [`src/trigger_change_features.m`](src/trigger_change_features.m), [`src/score_change_events.m`](src/score_change_events.m) |
| Added development and frozen-validation studies, summary tables, and separate speech/noise decomposition. | [`src/run_full_transition_study.m`](src/run_full_transition_study.m), [`src/run_detector_revision.m`](src/run_detector_revision.m), [`src/summarise_detector_revision.m`](src/summarise_detector_revision.m), [`src/apply_stft_gain.m`](src/apply_stft_gain.m) |
| Added automated checks, a documented detector audit, and one executed MATLAB walkthrough of the complete project. | [`tests/run_tests.m`](tests/run_tests.m), [`tests/test_detector_revision.m`](tests/test_detector_revision.m), [`results/detector_revision/README.md`](results/detector_revision/README.md), [`ELEC5305_Project_Summary.mlx`](ELEC5305_Project_Summary.mlx) |

## Experimental structure

```text
Clean speech + noise A + noise B + known transition time
                         |
                         v
               Controlled dynamic mixture
                         |
                         v
                   Causal STFT
                         |
            +------------+-------------+
            |            |             |
         Fixed       SNR-only      Change/oracle
       controller    controller      controller
            |            |             |
            +------------+-------------+
                         |
                   Wiener gain
                         |
                         v
                      ISTFT
                         |
                         v
     Global metrics + transition-region diagnostics
```

All four main systems use the same Wiener enhancement equation. Only the controller changes. This makes it possible to separate the effect of change detection from the effect of faster noise tracking and weaker gain smoothing.

## Historical Pilot Results

The expanded study uses VoiceBank speaker `p232` for development and held-out speaker `p257` for testing. Each split contains three speech sequences and non-overlapping DEMAND excerpts. Five conditions are tested: level change, noise-type change, onset, offset, and the same noise-type change during a controlled speech pause. Every change occurs at 3.0 seconds.

![Held-out transition metrics](results/held_out_transition_metrics.png)

| Held-out condition | Fixed | SNR-adaptive | Change-aware | Oracle |
|---|---:|---:|---:|---:|
| Level change | 1.76 | 2.98 | **3.95** | 3.40 |
| Noise offset | 13.95 | 14.58 | **20.61** | 15.68 |
| Noise onset | 3.08 | 4.07 | **4.21** | 3.73 |
| Noise-type change during speech | 5.93 | 6.75 | 7.20 | **7.36** |
| Noise-type change during pause | 2.52 | 4.34 | **4.82** | 4.16 |

Values are mean SI-SDR in the first 0.75 seconds after the change, in dB. Across all held-out conditions, change-aware processing achieved 4.22 dB whole-signal SI-SDR compared with 2.49 dB for fixed Wiener. However, mean STOI was approximately 0.93 for change-aware and 0.92 for fixed, while the unprocessed mixtures were approximately 0.94. The current controller therefore improves distortion-based measures but does not yet demonstrate an intelligibility improvement.

### Detector ablation

![Detector ablation](results/detector_ablation.png)

The combined cue was selected using development data and then frozen. On the held-out cases it detected 60% of changes within 1.5 seconds, with 0.79 seconds mean latency among detected cases and 3.27 false alarms before each change. The detector is therefore still the main weakness. Spectral flux produced few false alarms but missed all transitions at the current threshold; modulation reduced false alarms relative to the combined cue but was not selected by the predefined development cost.

### Transition diagnostics

![Held-out controller trace](results/held_out_controller_trace.png)

The study now saves the Wiener gain and applies it separately to clean speech and added noise. This allows transition speech error and residual-noise suppression to be measured independently. The recovery curve, speech/noise trade-off, complete per-case metrics, and summaries are available in [`results/`](results/). These are still preliminary results: only two speakers and two noise environments are included.

## Compared systems

1. **Fixed Wiener:** fixed noise-tracking and gain-smoothing parameters.
2. **SNR-adaptive Wiener:** adaptation controlled only by estimated frame SNR.
3. **Change-aware Wiener:** adaptation triggered by a spectral/modulation change score.
4. **Oracle Wiener:** adaptation triggered by the known simulated change time.
5. **Fixed spectral subtraction:** retained as a basic baseline, not the main research system.

## Real-data protocol

Clean VoiceBank speech is mixed with selected DEMAND noises to create controlled scene changes. The current checkpoint implements:

- a noise-level change;
- a noise-type change at the same nominal SNR;
- noise onset and noise disappearance;
- the same noise-type transition during active speech and a controlled pause.

Development uses speaker `p232`; held-out evaluation uses speaker `p257` and non-overlapping noise excerpts. Detector selection is performed only on development cases. The exact inputs are listed in [`data/experiment_manifest.csv`](data/experiment_manifest.csv).

Implemented metrics include detection latency, false-alarm rate, transition settling time, transition-region SI-SDR, STOI, residual-noise suppression, speech distortion, and processing time.

## Reproduce the experiments

### Requirements

- MATLAB R2026a or a compatible release
- Signal Processing Toolbox

After downloading the official data described in [`data/README.md`](data/README.md), run the real-data experiment from the repository root:

```matlab
addpath('src');
run('src/run_full_transition_study.m');
```

The dataset-independent smoke test is:

```matlab
addpath('src');
run('src/run_transition_demo.m');
```

Run the automated checks with:

```matlab
addpath('src');
run('tests/run_tests.m');
```

## Repository structure

```text
.
|-- src/
|   |-- README.md                  Guide to entry points and core functions
|   |-- generate_dynamic_scene.m   Known-time noise transition generator
|   |-- transition_wiener.m        Four Wiener controller modes
|   |-- scene_change_detector.m    Four independently evaluated change cues
|   |-- apply_stft_gain.m          Speech/noise decomposition analysis
|   |-- run_full_transition_study.m Development and held-out study
|   |-- run_transition_demo.m      Dataset-independent smoke experiment
|   |-- run_detector_revision.m    Frozen false-alarm and detector audit
|   |-- spectral_subtraction.m     Basic fixed baseline
|   `-- add_noise_at_snr.m         Controlled stationary mixture helper
|-- tests/run_tests.m              Automated MATLAB checks
|-- ELEC5305_Project_Summary.mlx   Executed, self-contained project walkthrough
|-- tools/build_project_summary.m  Build source for the Live Script
|-- results/                        Figures, metrics, and audio examples
|-- docs/
|   |-- index.md                    GitHub Pages progress report
|   `-- feedback-two.md             Week 10 checkpoint and feedback response
|-- data/                           Dataset provenance and experiment manifest
|-- literature_review.md            Focused literature review
|-- Proposal/
|   |-- Proposal.pdf                Originally submitted proposal
|   |-- Proposal.tex                Original LaTeX source
|   |-- proposal_2.pdf              Feedback-aligned proposal
|   `-- proposal_2.tex              Updated LaTeX source
`-- references.bib                  Project bibliography
```

The `bench` branch preserves superseded early experiments and duplicated outputs; it is not part of the recommended review path.

## Next milestones

1. Improve change detection without increasing false alarms, using development data only.
2. Add more speakers, noise environments, transition pairs, and random seeds.
3. Validate the fixed Wiener implementation against an independent reference.
4. Repeat final frozen testing with more independent sequence clusters and paired uncertainty intervals.
5. Add pretrained DeepFilterNet3 only as an optional modern reference.

## Selected references

1. S. F. Boll, "Suppression of Acoustic Noise in Speech Using Spectral Subtraction," *IEEE Transactions on Acoustics, Speech, and Signal Processing*, 1979. [doi:10.1109/TASSP.1979.1163209](https://doi.org/10.1109/TASSP.1979.1163209)
2. P. Scalart and J. V. Filho, "Speech Enhancement Based on a Priori Signal to Noise Estimation," *ICASSP*, 1996. [doi:10.1109/ICASSP.1996.543199](https://doi.org/10.1109/ICASSP.1996.543199)
3. P. C. Loizou and G. Kim, "Reasons Why Current Speech-Enhancement Algorithms Do Not Improve Speech Intelligibility and Suggested Solutions," *IEEE Transactions on Audio, Speech, and Language Processing*, 2011. [doi:10.1109/TASL.2010.2045180](https://doi.org/10.1109/TASL.2010.2045180)
4. K. K. Paliwal, B. Schwerin, and K. Wojcicki, "Modulation Domain Spectral Subtraction for Speech Enhancement," *Interspeech*, 2009. [doi:10.21437/Interspeech.2009-413](https://doi.org/10.21437/Interspeech.2009-413)
5. C. Valentini-Botinhao, "Noisy Speech Database for Training Speech Enhancement Algorithms and TTS Models," University of Edinburgh DataShare, 2017. [Dataset](https://doi.org/10.7488/ds/2117)
6. C. H. Taal et al., "An Algorithm for Intelligibility Prediction of Time-Frequency Weighted Noisy Speech," *IEEE Transactions on Audio, Speech, and Language Processing*, 2011. [doi:10.1109/TASL.2011.2114881](https://doi.org/10.1109/TASL.2011.2114881)

## Academic integrity and licence

Published methods and datasets are cited in the proposal and bibliography. Third-party dataset files are not committed. The implementation in this repository is distinguished from external reference implementations.

Copyright (c) 2026 **Liya Xu**. Repository code is released under the [MIT License](LICENSE).
