# Modulation-Aware Adaptive Speech Enhancement under Non-Stationary Noise

## Student Information

- Full Name: Liya Xu
- Student ID: 530519058
- GitHub Username: Liyaxuxu
- GitHub Project: https://github.com/Liyaxuxu/elec5305-project-530519058
- GitHub Pages: https://liyaxuxu.github.io/elec5305-project-530519058/

## Project Overview

Speech recorded in real environments often contains background noise. More importantly, that noise does not always stay the same. For example, an office recording may contain steady air-conditioning noise, while a street recording may include cars that appear suddenly and then disappear. A speech-enhancement method with one fixed setting can struggle with these changes. Strong suppression may remove more noise but damage the speech, while weak suppression may leave too much noise behind.

This project asks: **Can short-term modulation cues and frame-level SNR estimates be used to adapt noise tracking and time-frequency suppression so that speech quality and intelligibility improve over fixed-parameter spectral subtraction and Wiener filtering under non-stationary noise?**

A MATLAB system based on the short-time Fourier transform (STFT) will be developed. The system will estimate the current signal-to-noise ratio (SNR), measure how quickly the noise spectrum is changing, and adjust the noise-estimation speed and suppression strength frame by frame. Its performance will be compared with fixed spectral subtraction and fixed Wiener filtering under several noise types and SNR levels.

## Background and Motivation

Spectral subtraction estimates the noise spectrum and subtracts it from the magnitude spectrum of the noisy signal [1]. Wiener filtering takes a different approach: it estimates a gain for each time-frequency bin from speech and noise statistics. Decision-directed a priori SNR estimation can make this gain more stable between frames [2]. Both methods are computationally light and are closely related to ELEC5305 topics such as windowing, STFT analysis, spectral estimation, filtering, and Wiener masks.

However, noise reduction does not automatically mean that speech becomes easier to understand. If the noise estimate is wrong, aggressive processing can create musical noise or remove useful speech components [3]. The update rate of the noise estimator is therefore important. A slow estimator cannot follow a sudden change, but an estimator that always updates quickly may mistake speech for noise.

The proposed approach uses short-term modulation information as a simple indicator of change. If the spectral energy begins to vary rapidly, the system can react faster. When the noise is stable, it can use slower and smoother updates. Modulation-domain processing has previously been applied to speech enhancement and provides a useful basis for this design [4]. The proposed controller remains easy to interpret and does not require training a large neural network. VoiceBank-DEMAND provides paired clean and noisy recordings, making it possible to compare enhanced speech against a clean reference [5,6].

## Proposed Methodology

MATLAB will be the main platform. The implementation and experiment will be organised into five stages.

1. **Pre-processing:** Resample and normalise each recording, divide it into 32-ms Hann-windowed frames with an 8-ms hop, and calculate the STFT.
2. **Fixed baselines:** Implement spectral subtraction with a spectral floor and Wiener filtering with decision-directed SNR estimation. Their parameters will remain fixed for each recording.
3. **Noise and change estimation:** Estimate the noise power spectrum and frame SNR. The change score will combine the mean absolute difference between consecutive log-power spectra with modulation energy calculated from a 64-frame temporal DFT of subband-energy trajectories. Energy between 2 and 16 Hz will represent the short-term modulation component. Feature weights and the decision threshold will be selected using development data only.
4. **Adaptive control:** When the change score is high, update the noise estimate faster and allow the gain to react more quickly. During stable periods, use slower updates and stronger temporal smoothing. The final gain will blend the spectral-subtraction and Wiener gains.
5. **Reconstruction:** Apply the gain to the noisy STFT and use the inverse STFT to produce the enhanced waveform.

Experiments will use VoiceBank-DEMAND and selected DEMAND environmental noises. Controlled mixtures will be generated at -5, 0, 5, and 10 dB SNR. A development set of 200 utterances will be used to select thresholds and controller parameters. Final evaluation will use 400 disjoint mixtures, balanced across the four SNR levels and four noise categories. Speakers and noise recordings reserved for final testing will not be used during parameter selection.

The comparison will include unprocessed noisy speech, fixed spectral subtraction, fixed Wiener filtering, SNR-only adaptation, and the complete modulation-aware method. Evaluation will report output SNR improvement, segmental SNR, short-time objective intelligibility (STOI) [7], optional PESQ where an authorised implementation is available, and processing time. Spectrograms and short listening examples will help explain artefacts that are not obvious from a single score. Modulation detection, SNR adaptation, and smoothing will also be removed one at a time to show which parts of the system are useful.

## Expected Outcomes

The main outcome will be a working MATLAB program that can process a noisy speech file using either a baseline method or the proposed adaptive method. The adaptive method is expected to be most useful when the background noise changes suddenly, although it may not perform best in every condition. A successful result will show a repeatable improvement over at least one fixed baseline without causing a large drop in STOI or excessive processing time.

The GitHub repository will include the complete code, data preparation instructions, experiment settings, tests, result tables, spectrograms, and selected audio examples. The report will also discuss cases where the method fails or introduces audible artefacts.

## Timeline

- Weeks 1-2: refine the research question, confirm the scope, and establish fixed baselines.
- Weeks 3-5: review literature, obtain data, define leakage-free splits, and implement metrics.
- Weeks 6-9: implement noise tracking, modulation analysis, adaptive control, and MATLAB tests.
- Weeks 10-11: run ablations, tune parameters on development data, and evaluate held-out conditions.
- Weeks 12-13: interpret results, complete the report and video, and publish reproducible materials.

## References

[1] S. F. Boll, "Suppression of acoustic noise in speech using spectral subtraction," *IEEE Transactions on Acoustics, Speech, and Signal Processing*, 27(2), 113-120, 1979. doi:10.1109/TASSP.1979.1163209.

[2] P. Scalart and J. V. Filho, "Speech enhancement based on a priori signal to noise estimation," *Proceedings of ICASSP*, 2, 629-632, 1996. doi:10.1109/ICASSP.1996.543199.

[3] P. C. Loizou and G. Kim, "Reasons why current speech-enhancement algorithms do not improve speech intelligibility and suggested solutions," *IEEE Transactions on Audio, Speech, and Language Processing*, 19(1), 47-56, 2011. doi:10.1109/TASL.2010.2045180.

[4] K. K. Paliwal, B. Schwerin, and K. Wojcicki, "Modulation domain spectral subtraction for speech enhancement," *Proceedings of Interspeech*, 1353-1356, 2009. doi:10.21437/Interspeech.2009-413.

[5] C. Valentini-Botinhao, "Noisy speech database for training speech enhancement algorithms and TTS models," University of Edinburgh DataShare, 2017. doi:10.7488/ds/2117.

[6] C. Valentini-Botinhao and J. Yamagishi, "Speech enhancement of noisy and reverberant speech for text-to-speech," *IEEE/ACM Transactions on Audio, Speech, and Language Processing*, 26(8), 1420-1433, 2018. doi:10.1109/TASLP.2018.2828980.

[7] C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, "An algorithm for intelligibility prediction of time-frequency weighted noisy speech," *IEEE Transactions on Audio, Speech, and Language Processing*, 19(7), 2125-2136, 2011. doi:10.1109/TASL.2011.2114881.
