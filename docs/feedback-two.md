# Project Feedback Two - Week 10 Checkpoint

**Liya Xu | SID 530519058 | ELEC5305**

[Project site](https://liyaxuxu.github.io/elec5305-project-530519058/) | [GitHub repository](https://github.com/Liyaxuxu/elec5305-project-530519058) | [Executed MATLAB summary](https://github.com/Liyaxuxu/elec5305-project-530519058/blob/main/ELEC5305_Project_Summary.mlx)

## Brief submission description

This project investigates how quickly a causal STFT/Wiener speech enhancer should adapt when the acoustic environment changes. In response to the first project feedback, the work now uses one common Wiener pipeline and compares fixed, SNR-adaptive, change-aware, and oracle controllers on controlled VoiceBank/DEMAND mixtures. Level changes, noise-type changes, onset, offset, and active-speech versus pause transitions are included. Change detection is evaluated separately from enhancement using hit rate, false alarms, and latency, while enhancement is evaluated using STOI, SI-SDR, settling time, speech distortion, residual-noise suppression, and runtime. The latest frozen audit includes 48 development and 48 validation cases, including no-change controls. It improves detector-level false alarms and latency, but does not improve the complete enhancer, which identifies controller coupling and speech-driven false alarms as the next problems.

## Response to the first feedback

| Feedback direction | Change made | Evidence |
|---|---|---|
| Sharpen the research question | The project now focuses on adaptation delay and transition-region speech distortion rather than general denoising. | Main README and updated proposal |
| Use one interpretable pipeline | Fixed, SNR, change-aware, and oracle methods share the same STFT/Wiener equation; only the controller changes. | `src/transition_wiener.m` |
| Keep spectral subtraction separate | Spectral subtraction is retained only as a basic ELEC5305 baseline. | `src/spectral_subtraction.m` |
| Construct controlled dynamic scenes | Known-time level, type, onset, offset, and pause transitions are generated from VoiceBank speech and DEMAND noise. | `src/generate_dynamic_scene.m` and saved manifests |
| Separate detection from enhancement | Detection hit rate, latency, and false alarms are reported separately from STOI and SI-SDR. | `results/detector_revision/` |
| Analyse speech interference | Active-speech and pause transitions are compared; clean, office, and traffic no-change controls were added. | `validation_by_condition.csv` |
| Add transition-centred diagnostics | Settling time, transition SI-SDR, recovery curves, speech error, and residual-noise suppression are implemented. | `results/full_transition_summary.csv` and figures |
| Tune only on development data | A 48-setting development search was frozen before the validation run; exact files, excerpts, seeds, and hashes are retained. | `development_search.csv`, `frozen_config.json`, and manifests |
| Check causal behaviour | Future-perturbation tests confirm that future samples do not change past detector decisions or gains in the revised protocol. | `tests/test_detector_revision.m` |
| Analyse false alarms | Every false trigger is saved with timing and reference speech-activity context; uncertainty is resampled by sequence. | False-alarm audit and `paired_uncertainty.csv` |

## Work completed by the end of Week 9

| Course period | Required work | Status at this checkpoint |
|---|---|---|
| Weeks 1-2 | Consider project topic | Complete: focused question, feasible scope, four-controller comparison, and oracle diagnostic. |
| Weeks 3-5 | Literature review and dataset collection | Complete for this checkpoint: classical and recent streaming/adaptation literature, VoiceBank/DEMAND provenance, checksums, and reproducible manifests. |
| Weeks 6-9 | Initial implementation and testing | Complete: dynamic-scene generator, common Wiener pipeline, detector cues, controller comparisons, automated tests, real-data preliminary evaluation, figures, and audio examples. |

Week 10-11 optimisation has also started through the frozen false-alarm audit and detector ablations. This does not mean that the final system has been optimised or that the project is complete.

## Preliminary result

On the frozen validation set, the revised detector matched 23 of 30 scheduled changes, compared with 20 of 30 for the original combined cue. No-change false alarms fell from 62.38 to 41.90 per minute, and matched latency fell from 0.617 to 0.175 seconds. However, whole-signal SI-SDR fell from 4.507 to 3.612 dB and STOI fell from 0.83446 to 0.83108. The revised detector also produced more false alarms on clean speech alone.

The current conclusion is therefore narrow: the revised cue improves some detector measurements on this sample, but it does not improve the complete enhancer. This negative result is retained because it separates detector quality from controller behaviour.

## Current limitations and requested feedback

1. The validation evidence uses six sequences from one validation speaker and two environmental recordings. It does not establish broad speaker or noise generalisation.
2. The clean-speech false-alarm rate remains high, suggesting that speech modulation is still confused with environmental change.
3. The same fast-update controller was used with both detector trigger patterns. A compact controller ablation is needed before deciding whether the revised detector should replace the original.
4. The fixed Wiener baseline now has fixed-parameter, gain-range, causality, reconstruction, and stationary-scene checks, but comparison with an independent reference implementation remains a useful final sanity check.
5. A pretrained neural reference is intentionally deferred. Advice is requested on whether broader data or the controller ablation should take priority before an optional DeepFilterNet comparison.

## Immediate Week 10-11 priorities

1. Run a compact controller-response ablation using development data only.
2. Freeze one final detector-controller configuration before any additional validation.
3. Add a third noise environment or transition pair if time and data scope permit.
4. Retain DeepFilterNet only as an optional contextual reference after the DSP analysis is stable.

The full detector protocol, unsuccessful cases, uncertainty estimates, and reproduction commands are available in the [detector revision audit](https://github.com/Liyaxuxu/elec5305-project-530519058/blob/main/results/detector_revision/README.md).
