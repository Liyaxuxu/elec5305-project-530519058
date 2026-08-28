# Noise-Aware Adaptive Speech Enhancement under Non-Stationary Noise

## Student Information

- Full Name: Liya Xu
- Student ID: 530519058
- GitHub Username: Liyaxuxu
- GitHub Project: https://github.com/Liyaxuxu/elec5305-project-530519058-speech-enhancement
- GitHub Pages: https://liyaxuxu.github.io/elec5305-project-530519058-speech-enhancement/

## Project Overview

Speech enhancement systems aim to recover intelligible, natural speech from recordings corrupted by environmental noise. A practical difficulty is that real acoustic environments are non-stationary: a recording may move from relatively stable ventilation noise to intermittent voices, traffic, or impacts, while the signal-to-noise ratio (SNR) also changes. A spectral subtraction or Wiener filter configured with one fixed suppression strength therefore tends either to leave substantial noise or to introduce musical noise and speech distortion. This project asks: **can real-time estimates of noise type and SNR be used to adapt Wiener-filter and spectral-subtraction parameters so that speech quality and intelligibility improve over fixed-parameter methods under changing noise?**

The proposed solution is an interpretable short-time Fourier transform (STFT) pipeline. It will estimate the noise spectrum and frame SNR, derive simple spectral descriptors of the current interference, and use a rule-based controller to select or interpolate enhancement settings. This creates a complete engineering investigation rather than only an implementation: fixed and adaptive methods will be compared under controlled SNRs, multiple noise categories, held-out speakers, and unseen noise recordings.

## Background and Motivation

Spectral subtraction is a foundational enhancement technique that estimates and subtracts a noise spectrum from the noisy speech magnitude [1]. Wiener filtering instead estimates a time-frequency gain from signal and noise statistics, while decision-directed a priori SNR estimation reduces unstable gain changes [2]. These methods are computationally efficient and closely connected to the ELEC5305 material on windowing, STFT analysis, spectral estimation, filtering, and Wiener masks. However, classical enhancement can improve measured quality without reliably improving intelligibility, especially when noise estimates are inaccurate or suppression creates artefacts [3]. This motivates examining when adaptation helps and where it fails rather than claiming that one filter is universally best.

VoiceBank-DEMAND provides paired clean and noisy utterances widely used for speech-enhancement evaluation [4,5]. It enables objective comparison with clean references while remaining manageable on a normal laptop. The project is valuable because it combines established algorithms in a new, testable control strategy, provides explainable behaviour, and avoids the large compute and opaque decisions of a deep neural network.

## Proposed Methodology

MATLAB will be the primary platform. Audio will be resampled to a common rate and normalised consistently. Each waveform will be divided into overlapping Hann-windowed frames and transformed using the STFT. A minimum-statistics-style update during low-energy frames will track the noise power spectral density. Baseline one will implement fixed oversubtraction with a spectral floor. Baseline two will implement a fixed Wiener gain using decision-directed SNR estimation.

The proposed controller will compute frame SNR, spectral flatness, low-to-high-band energy ratio, and temporal spectral change. These low-cost descriptors will map each frame to a suppression regime representing approximately stationary, broadband, or rapidly changing interference. Rather than making a hard classification claim, the controller will interpolate the Wiener and subtraction gains and constrain gain changes over time. Ablation experiments will remove the noise descriptor, SNR adaptation, or temporal smoothing to identify which component contributes to performance.

Experiments will use VoiceBank-DEMAND plus selected DEMAND noises. Controlled mixtures will be generated at -5, 0, 5, and 10 dB. Development and test partitions will be separated by speaker and noise recording to prevent leakage. The methods will be evaluated using output SNR improvement, segmental SNR, short-time objective intelligibility (STOI) [6], optional PESQ where the required implementation is available, real-time factor, and waveform/spectrogram examples. Bootstrap confidence intervals across utterances will be reported so that conclusions do not depend on a few examples.

## Expected Outcomes

The main deliverable will be a working MATLAB prototype that reads noisy speech and produces enhanced audio using fixed or adaptive modes. The expected result is not that adaptation wins in every condition, but that it improves the average STOI/SNR trade-off and reduces severe failures when noise changes. A successful outcome will include reproducible scripts, documented datasets and splits, configuration values, aggregate tables, spectrograms, listening examples, ablations, and an honest analysis of artefacts and limitations. The public GitHub repository and GitHub Pages site will contain the code, proposal, final report, results, and demonstration instructions.

## Timeline

- Weeks 1-2: refine the research question, confirm scope, and establish fixed baselines.
- Weeks 3-5: review literature, download data, define leakage-free splits, and implement metrics.
- Weeks 6-9: implement noise tracking, adaptive control, batch experiments, and unit tests.
- Weeks 10-11: run ablations, optimise parameters on development data, and evaluate held-out data.
- Weeks 12-13: interpret results, finish the report and video, and publish reproducible GitHub materials.

## References

[1] S. F. Boll, “Suppression of acoustic noise in speech using spectral subtraction,” *IEEE Transactions on Acoustics, Speech, and Signal Processing*, 27(2), 113-120, 1979. doi:10.1109/TASSP.1979.1163209.

[2] P. Scalart and J. V. Filho, “Speech enhancement based on a priori signal to noise estimation,” *Proceedings of ICASSP*, 2, 629-632, 1996. doi:10.1109/ICASSP.1996.543199.

[3] P. C. Loizou and G. Kim, “Reasons why current speech-enhancement algorithms do not improve speech intelligibility and suggested solutions,” *IEEE Transactions on Audio, Speech, and Language Processing*, 19(1), 47-56, 2011. doi:10.1109/TASL.2010.2045180.

[4] C. Valentini-Botinhao, “Noisy speech database for training speech enhancement algorithms and TTS models,” University of Edinburgh DataShare, 2017. doi:10.7488/ds/2117.

[5] C. Valentini-Botinhao and J. Yamagishi, “Speech enhancement of noisy and reverberant speech for text-to-speech,” *IEEE/ACM Transactions on Audio, Speech, and Language Processing*, 26(8), 1420-1433, 2018. doi:10.1109/TASLP.2018.2828980.

[6] C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, “An algorithm for intelligibility prediction of time-frequency weighted noisy speech,” *IEEE Transactions on Audio, Speech, and Language Processing*, 19(7), 2125-2136, 2011. doi:10.1109/TASL.2011.2114881.
