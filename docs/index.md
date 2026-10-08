# How Quickly Should a Speech Enhancer Adapt?

## Modulation-Aware Speech Enhancement in Dynamic Acoustic Scenes

**Liya Xu | SID 530519058 | ELEC5305 Project Feedback Two**

[View the source code and full documentation](https://github.com/Liyaxuxu/elec5305-project-530519058)

## Project description

This project investigates what happens immediately after a causal speech enhancer encounters an abrupt acoustic scene change. It asks whether a lightweight modulation/change-aware controller can reduce adaptation delay without creating excessive speech distortion, compared with fixed and SNR-only Wiener baselines.

The main contribution is a transition-aware experiment in which the true noise-change time is known. This allows change detection and enhancement adaptation to be evaluated separately.

## Achieved to date

- Implemented controlled SNR mixing and a dynamic noise A to noise B scene generator.
- Implemented fixed spectral subtraction and a common STFT/Wiener enhancement pipeline.
- Implemented fixed, SNR-adaptive, change-aware, and oracle-triggered Wiener controllers.
- Added automated MATLAB tests for mixture SNR, output validity, transition metadata, and every controller mode.
- Generated machine-readable metrics, a diagnostic figure, and listening examples.

## Preliminary experiment

The current dataset-independent demo uses a six-second synthetic speech-like source. At 3.0 seconds, fan-like noise changes to traffic-like noise while the source remains active. The pre- and post-transition mixtures are both approximately 0 dB SNR.

![Preliminary transition results](assets/preliminary_transition_results.png)

| System | Whole-signal SNR (dB) | Transition SI-SDR (dB) |
|---|---:|---:|
| Noisy | 0.00 | 0.61 |
| Fixed Wiener | 1.95 | -2.96 |
| SNR-adaptive Wiener | 1.08 | -6.96 |
| Change-aware Wiener | 1.82 | -7.30 |
| Oracle Wiener | 1.79 | -6.26 |

The change score located the true scene change within one STFT-frame tolerance, with one earlier false alarm. However, the current fast-adaptation settings increased transition-region speech distortion, including in the oracle case. This suggests that the controller update is currently too aggressive and that knowing the correct transition time alone is not sufficient.

This is a useful preliminary negative result rather than a final performance claim. It motivates separate evaluation of:

1. whether the environmental change was detected correctly; and
2. whether changing the Wiener parameters after detection actually helped.

## Listening examples

- [Dynamic noisy mixture](assets/audio/dynamic_noisy.wav)
- [Fixed Wiener output](assets/audio/fixed_wiener.wav)
- [Change-aware Wiener output](assets/audio/change_aware_wiener.wav)
- [Oracle-triggered Wiener output](assets/audio/oracle_wiener.wav)

The signals are synthetic and are provided only to verify the current pipeline. Final conclusions will use real clean speech and environmental noise.

## Next steps

- Validate the fixed Wiener baseline using clean VoiceBank speech and stationary DEMAND noise.
- Generate noise-level, noise-type, onset, and offset transitions at known times.
- Compare transitions during speech with the same transitions during silence.
- Add spectral-flux and short-time modulation-energy detectors.
- Measure detection latency, false alarms, settling time, transition SI-SDR/STOI, residual noise, speech distortion, and runtime.
- Freeze parameters after development and evaluate unseen speakers, noises, and transition pairs.

## Reproducibility

The preliminary experiment is generated with a fixed random seed. From the repository root in MATLAB:

```matlab
addpath('src');
run('src/run_transition_demo.m');
```

Tests can be run with:

```matlab
addpath('src');
run('tests/run_tests.m');
```

[Read the full README](https://github.com/Liyaxuxu/elec5305-project-530519058#readme)
