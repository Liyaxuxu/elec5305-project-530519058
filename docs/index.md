# How Quickly Should a Speech Enhancer Adapt?

## Modulation-Aware Speech Enhancement in Dynamic Acoustic Scenes

**Liya Xu | SID 530519058 | ELEC5305 Project Feedback Two**

[Source code and full documentation](https://github.com/Liyaxuxu/elec5305-project-530519058)

## Research question

Can a lightweight modulation/change-aware controller reduce adaptation delay and speech distortion after an abrupt acoustic change, compared with fixed and SNR-only Wiener baselines?

The experiment keeps the causal STFT/Wiener enhancement equation fixed and changes only its controller. A known-time oracle trigger is included to separate two questions: was the scene change detected, and did faster adaptation actually help?

## Work completed for Weeks 1--9

| Weeks | Activity | Completed evidence |
|---|---|---|
| 1--2 | Topic selection | Focused research question, project scope, and four-system comparison. |
| 3--5 | Literature and data | Focused literature review; official VoiceBank and DEMAND data; checksums and development/held-out split. |
| 6--9 | Implementation and testing | Three real transition types, four controllers, automated tests, metrics, diagnostic plot, and audio. |

The current implementation includes fixed, SNR-adaptive, change-aware, and oracle-triggered Wiener controllers. Spectral subtraction is retained as a basic reference but is not mixed into the controller comparison.

## Preliminary real-data experiment

Clean VoiceBank speech (`p232_003.wav`) is mixed with DEMAND OOFFICE and STRAFFIC recordings. A known change occurs at 3.0 seconds in each six-second mixture.

1. **Level change:** office noise changes from 10 dB to 0 dB SNR.
2. **Noise-type change:** office noise changes to traffic noise at 0 dB SNR.
3. **Noise onset:** traffic noise begins at 0 dB SNR.

![Real VoiceBank and DEMAND transition results](assets/real_data_transition_results.png)

| Condition | System | Whole SI-SDR (dB) | Transition SI-SDR (dB) |
|---|---|---:|---:|
| Level change | Fixed | 3.10 | 0.59 |
| Level change | Change-aware | **5.50** | **1.40** |
| Level change | Oracle | 4.93 | 2.19 |
| Noise-type change | Fixed | **4.26** | **3.45** |
| Noise-type change | Change-aware | 4.21 | 3.39 |
| Noise-type change | Oracle | 4.94 | 3.82 |
| Noise onset | Fixed | 1.89 | **0.56** |
| Noise onset | Change-aware | **2.67** | 0.50 |
| Noise onset | Oracle | 1.81 | 0.44 |

The change-aware controller helped clearly for the level change, was approximately equal to fixed adaptation for the noise-type change, and did not improve the first 0.75 seconds after noise onset. Detector latency was 0.288 s, 0.440 s, and 1.352 s, respectively. Six false alarms occurred before the true change in every condition.

This is a useful preliminary result rather than a final performance claim. It shows that the current detector is too sensitive and that the controller effect depends on the type of scene change. It also confirms the value of the oracle comparison: even a correct trigger can be followed by an adaptation rule that damages speech.

## Listening example: office to traffic

- [Noisy mixture](assets/audio/real_data/noisy.wav)
- [Fixed Wiener](assets/audio/real_data/fixed.wav)
- [SNR-adaptive Wiener](assets/audio/real_data/snr.wav)
- [Change-aware Wiener](assets/audio/real_data/change.wav)
- [Oracle-triggered Wiener](assets/audio/real_data/oracle.wav)
- [Clean reference](assets/audio/real_data/clean.wav)

## Reproducibility and next work

The repository contains the exact development manifest, dataset provenance, code, CSV metrics, and automated tests. Speaker `p232` is used for development and `p257` is held out. The final stage will reduce false alarms, add a separate modulation-energy ablation, add offset and speech-pause transitions, freeze the parameters, and evaluate non-overlapping held-out mixtures.

[Read the full README](https://github.com/Liyaxuxu/elec5305-project-530519058#readme) | [Read the literature review](https://github.com/Liyaxuxu/elec5305-project-530519058/blob/main/literature_review.md) | [View dataset provenance](https://github.com/Liyaxuxu/elec5305-project-530519058/tree/main/data)
