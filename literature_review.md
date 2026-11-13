# Literature Review

## 1. Scope

This project asks how quickly a causal speech enhancer should adapt after an abrupt acoustic change. The focus is not a new enhancement network. Instead, it is the interaction between three observable parts of a streaming system: scene-change detection, noise-estimate adaptation, and gain smoothing. This narrower scope makes it possible to explain both improvements and failures around a known transition time.

## 2. Classical enhancement baselines

Boll's spectral-subtraction method estimates a noise spectrum and subtracts it from the noisy speech spectrum [1]. It remains a useful reference because its assumptions and artefacts are easy to inspect. Scalart and Filho's decision-directed a priori SNR estimator [2] provides the basis for a smoother Wiener-style gain and motivates the fixed enhancement pipeline used in this project.

These classical methods are normally evaluated using averages over an utterance. Loizou and Kim [3] showed that improving conventional quality measures does not necessarily improve intelligibility. This is important here: a system may have a reasonable whole-utterance score while briefly distorting speech after the environment changes. The project therefore reports both global and transition-local metrics.

## 2a. Adaptive noise tracking

The fixed baselines above need a noise estimate, and how fast that estimate follows a change is exactly what this project is about. Martin's minimum-statistics method [12] tracks the noise floor as the minimum of a smoothed power spectrum over about 1.5 s, so it works during speech but needs roughly that long to follow a rising noise level. Gerkmann and Hendriks [13] replaced this with an MMSE estimator based on speech presence probability, which has a much shorter tracking delay. Both are implemented in the VOICEBOX toolbox [14], which I used as an independent reference for my own Wiener filter. Berouti et al. [15] introduced the over-subtraction and spectral floor used in VOICEBOX's `specsub`, and segmental SNR follows the definition in Loizou's textbook [16].

These methods adapt the noise estimate continuously. My controller is different: it keeps one simple recursive estimate and only changes how fast it updates. The VOICEBOX systems provide a reference for the performance available from established continuous noise trackers. I did not combine those trackers with my change trigger, so that comparison is left for future work.

## 3. Modulation and temporal change

Speech and environmental noise have different temporal patterns. Paliwal, Schwerin, and Wojcicki [4] applied spectral subtraction in the modulation domain, showing that information across time can be used rather than treating every short-time frame independently. The present project does not reproduce that algorithm. It uses the paper to motivate a lightweight temporal change cue and asks whether that cue should temporarily alter the adaptation rate of an otherwise unchanged Wiener enhancer.

The implementation begins with log-spectral change because it is simple and interpretable. Short-time modulation energy and spectral flux are evaluated against this baseline rather than assumed to be better. Detector latency and false alarms are measured separately from enhancement quality, since a correctly detected event can still lead to harmful controller behaviour.

## 4. Real-time and latency constraints

DeepFilterNet demonstrates that modern neural enhancement can operate in real time and provides an open pretrained reference system [5]. It is optional in this project because the main experiment concerns adaptation behaviour, not neural-network training. Wu and Braun's study of ultra-low-latency enhancement [6] also shows that algorithmic latency, frame design, and quality must be considered together. Recent latency-configurable streaming work further treats latency as an explicit operating point rather than a fixed implementation detail [7].

These findings support a causal STFT implementation and the reporting of processing time. They also motivate keeping the detector and controller lightweight enough to inspect frame by frame.

## 5. Dynamic acoustic scenes

Recent work on lightweight adaptation studies enhancement systems that must respond to previously unseen and changing environments [8]. That work uses model adaptation, whereas this project uses an interpretable DSP controller. The common problem is that aggressive adaptation can learn a new environment quickly but may also alter speech or become unstable.

The gap addressed by this course project is therefore practical and focused: controlled noise-level, noise-type, onset, and offset transitions are created at known times; fixed, SNR-adaptive, change-aware, and oracle-triggered controllers are then compared using the same enhancement equation. The oracle condition separates a detector failure from a controller failure.

## 6. Datasets and evaluation

Clean utterances come from the VoiceBank corpus distributed with the University of Edinburgh noisy-speech database [9]. Environmental recordings come from DEMAND [10]. These sources allow reproducible mixtures with known transition time, noise identity, and SNR. The evaluation uses STOI [11], SI-SDR, residual-noise suppression, speech distortion, detector latency, false alarms, settling time, and runtime.

Development mixtures use p232 speech with office and traffic noise. The controller is frozen before evaluation on unused p257 utterances and non-overlapping noise excerpts. A final office-to-cafeteria split adds a noise environment and transition pair not used during development. This tests excerpt and transition-pair generalisation, but not unseen-speaker generalisation because p257 also appears in validation.

## 7. Project implication

The contribution of this project is the transition-centred experiment rather than a new enhancement algorithm. It measures when fast adaptation helps, when it harms speech, and whether a temporal change cue adds information beyond an SNR-only controller. The negative results are also useful because they expose false alarms, speech leakage into the noise estimate and overly aggressive adaptation.

## References

1. S. F. Boll, "Suppression of Acoustic Noise in Speech Using Spectral Subtraction," *IEEE TASSP*, 1979. https://doi.org/10.1109/TASSP.1979.1163209
2. P. Scalart and J. V. Filho, "Speech Enhancement Based on a Priori Signal to Noise Estimation," *ICASSP*, 1996. https://doi.org/10.1109/ICASSP.1996.543199
3. P. C. Loizou and G. Kim, "Reasons Why Current Speech-Enhancement Algorithms Do Not Improve Speech Intelligibility and Suggested Solutions," *IEEE TASLP*, 2011. https://doi.org/10.1109/TASL.2010.2045180
4. K. K. Paliwal, B. Schwerin, and K. Wojcicki, "Modulation Domain Spectral Subtraction for Speech Enhancement," *Interspeech*, 2009. https://doi.org/10.21437/Interspeech.2009-413
5. H. Schroter et al., "DeepFilterNet: Perceptually Motivated Real-Time Speech Enhancement," *Interspeech*, pp. 2008-2009, 2023. https://www.isca-archive.org/interspeech_2023/schroter23b_interspeech.html
6. H. Wu and S. Braun, "Ultra-Low Latency Speech Enhancement: A Comprehensive Study," *ICASSP*, 2025. https://doi.org/10.1109/ICASSP49660.2025.10889823
7. Y. Kim and Y. Chung, "Latency-Configurable Streaming Speech Enhancement via Asymmetric Temporal Padding," arXiv:2606.19688, 2026. https://arxiv.org/abs/2606.19688
8. L. Cheng and S.-C. Liu, "Towards Lightweight Adaptation of Speech Enhancement Models in Real-World Environments," arXiv:2603.07471, 2026. https://arxiv.org/abs/2603.07471
9. C. Valentini-Botinhao, "Noisy Speech Database for Training Speech Enhancement Algorithms and TTS Models," University of Edinburgh DataShare, 2017. https://doi.org/10.7488/ds/2117
10. J. Thiemann, N. Ito, and E. Vincent, "The Diverse Environments Multi-channel Acoustic Noise Database (DEMAND)," *Proceedings of Meetings on Acoustics*, 2013. https://doi.org/10.1121/1.4799597
11. C. H. Taal et al., "An Algorithm for Intelligibility Prediction of Time-Frequency Weighted Noisy Speech," *IEEE TASLP*, 2011. https://doi.org/10.1109/TASL.2011.2114881
12. R. Martin, "Noise Power Spectral Density Estimation Based on Optimal Smoothing and Minimum Statistics," *IEEE Transactions on Speech and Audio Processing*, vol. 9, no. 5, pp. 504-512, 2001. https://doi.org/10.1109/89.928915
13. T. Gerkmann and R. C. Hendriks, "Unbiased MMSE-Based Noise Power Estimation With Low Complexity and Low Tracking Delay," *IEEE TASLP*, vol. 20, no. 4, pp. 1383-1393, 2012. https://doi.org/10.1109/TASL.2011.2180896
14. M. Brookes, "VOICEBOX: Speech Processing Toolbox for MATLAB," Imperial College London. http://www.ee.ic.ac.uk/hp/staff/dmb/voicebox/voicebox.html
15. M. Berouti, R. Schwartz, and J. Makhoul, "Enhancement of Speech Corrupted by Acoustic Noise," *ICASSP*, pp. 208-211, 1979. https://doi.org/10.1109/ICASSP.1979.1170788
16. P. C. Loizou, *Speech Enhancement: Theory and Practice*, 2nd ed. CRC Press, 2013.
