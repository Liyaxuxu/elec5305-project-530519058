# Result Definitions

## Evaluation regions

- **Whole signal:** complete six-second mixture.
- **Transition region:** 0 to 0.75 seconds after the known scene change.
- **Steady-state region:** 1.5 to 2.5 seconds after the change.
- **Recovery curve:** 100 ms blocks from 0.5 seconds before to 2.5 seconds after the change.

## Enhancement metrics

- **SI-SDR:** scale-invariant signal-to-distortion ratio against clean speech; higher is better.
- **STOI:** short-time objective intelligibility score; higher is better.
- **Output SNR:** clean-reference signal-to-error ratio over the whole mixture; higher is better.
- **Settling time:** first post-change 100 ms block in a run of three blocks whose error energy remains within 1.5 dB of the median error measured 1.5 seconds or more after the transition. `NaN` means the condition was not met within the recording.
- **Transition speech error:** saved Wiener gain applied to the clean-speech STFT, followed by relative reconstruction-error energy; lower is better.
- **Transition noise suppression:** saved Wiener gain applied to the known added-noise STFT; positive values indicate noise reduction. It is undefined after noise offset because the target interval contains no added noise.
- **Runtime:** MATLAB wall-clock processing time for one six-second signal. It is not a hardware-independent real-time factor.

## Detector metrics

Each cue uses a causal one-second history. Its adaptive threshold is the historical median plus six median absolute deviations. A trigger requires two adjacent frames above threshold and is followed by a 350 ms hold period.

- **Detection rate:** fraction of cases with a trigger from 0 to 1.5 seconds after the true change.
- **Detection latency:** first post-change trigger time minus the true transition time.
- **False alarms:** triggers before the known transition.

The selected cue is chosen only from development cases using:

```text
cost = 10 * missed-detection rate + mean false alarms + mean non-negative latency
```

The selected cue is then frozen for held-out controller evaluation.

## Files

- `detector_ablation.csv`: one detector result per case and cue.
- `detector_ablation_summary.csv`: development and held-out detector summaries.
- `full_transition_metrics.csv`: one enhancement result per case and system.
- `full_transition_summary.csv`: grouped means and standard deviations.
- `transition_recovery.csv`: time-aligned local SI-SDR values.
- `selected_change_cue.txt`: cue selected from development data.
