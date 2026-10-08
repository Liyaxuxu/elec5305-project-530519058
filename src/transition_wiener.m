function [enhanced, diagnostics] = transition_wiener( ...
    noisy, fs, mode, knownTransitionTime, changeCue)
%TRANSITION_WIENER Wiener enhancement with selectable adaptation control.
% Modes: "fixed", "snr", "change", and "oracle".
if nargin < 3, mode = "fixed"; end
if nargin < 4, knownTransitionTime = NaN; end
if nargin < 5, changeCue = "combined"; end

windowLength = 512;
overlapLength = 384;
hopSeconds = (windowLength - overlapLength) / fs;
% A periodic Hamming window avoids unstable endpoint normalisation after
% modifying the first and last STFT frames.
window = hamming(windowLength, 'periodic');
[S, ~, frameTimes] = stft(noisy, fs, Window=window, ...
    OverlapLength=overlapLength, FFTLength=windowLength);

initialFrames = max(1, min(size(S, 2), round(0.25 / hopSeconds)));
noisePsd = median(abs(S(:, 1:initialFrames)).^2, 2) + eps;
previousGain = ones(size(noisePsd));
detector = scene_change_detector(S, frameTimes, changeCue);

nFrames = size(S, 2);
Y = zeros(size(S));
triggers = false(1, nFrames);
noiseAlphaTrace = zeros(1, nFrames);
gainAlphaTrace = zeros(1, nFrames);
meanGainTrace = zeros(1, nFrames);
meanNoisePsdTrace = zeros(1, nFrames);
gainMatrix = zeros(size(S));
holdFrames = max(1, round(0.35 / hopSeconds));
holdRemaining = 0;

for k = 1:nFrames
    power = abs(S(:, k)).^2 + eps;

    if mode == "change" && detector.triggers(k) && holdRemaining == 0
        triggers(k) = true;
        holdRemaining = holdFrames;
    elseif mode == "oracle" && isfinite(knownTransitionTime) && ...
            abs(frameTimes(k) - knownTransitionTime) <= hopSeconds / 2
        triggers(k) = true;
        holdRemaining = holdFrames;
    end

    posteriorSnr = power ./ noisePsd;
    instantaneousPrior = max(posteriorSnr - 1, 0);
    frameSnrDb = 10 * log10(max(mean(instantaneousPrior), eps));

    switch mode
        case "fixed"
            noiseAlpha = 0.995;
            gainAlpha = 0.90;
        case "snr"
            lowSnrWeight = min(max((5 - frameSnrDb) / 15, 0), 1);
            noiseAlpha = 0.995 - 0.055 * lowSnrWeight;
            gainAlpha = 0.90 - 0.20 * lowSnrWeight;
        otherwise
            if holdRemaining > 0
                noiseAlpha = 0.90;
                gainAlpha = 0.55;
                holdRemaining = holdRemaining - 1;
            else
                noiseAlpha = 0.995;
                gainAlpha = 0.90;
            end
    end

    % Bins with a high estimated speech SNR update less strongly. The cap
    % still permits a changed noise floor to be acquired in fast mode.
    noiseObservation = min(power, 6 * noisePsd);
    noiseWeight = 1 ./ (1 + instantaneousPrior);
    updateStep = (1 - noiseAlpha) .* noiseWeight;
    noisePsd = (1 - updateStep) .* noisePsd + updateStep .* noiseObservation;
    targetGain = max(instantaneousPrior ./ (1 + instantaneousPrior), 0.05);
    gain = gainAlpha * previousGain + (1 - gainAlpha) * targetGain;
    Y(:, k) = gain .* S(:, k);
    gainMatrix(:, k) = gain;
    previousGain = gain;

    noiseAlphaTrace(k) = noiseAlpha;
    gainAlphaTrace(k) = gainAlpha;
    meanGainTrace(k) = mean(gain);
    meanNoisePsdTrace(k) = mean(noisePsd);
end

enhanced = istft(Y, fs, Window=window, OverlapLength=overlapLength, ...
    FFTLength=windowLength);
enhanced = enhanced(1:min(numel(enhanced), numel(noisy)));
diagnostics = struct( ...
    'frameTimes', frameTimes(:), ...
    'changeCue', string(changeCue), ...
    'changeScore', detector.score, ...
    'changeThreshold', detector.threshold, ...
    'triggers', triggers(:), ...
    'noiseAlpha', noiseAlphaTrace(:), ...
    'gainAlpha', gainAlphaTrace(:), ...
    'meanGain', meanGainTrace(:), ...
    'meanNoisePsd', meanNoisePsdTrace(:), ...
    'gainMatrix', gainMatrix, ...
    'detector', detector);
end
