function diagnostics = scene_change_detector(S, frameTimes, cue)
%SCENE_CHANGE_DETECTOR Causal change cues and robust trigger decisions.
% S is a frequency-by-time STFT matrix. Supported cues are
% "log_spectrum", "spectral_flux", "modulation", and "combined".
if nargin < 3, cue = "combined"; end
cue = string(cue);
validCues = ["log_spectrum", "spectral_flux", "modulation", "combined"];
assert(any(cue == validCues), 'Unknown scene-change cue: %s', cue);

nFrames = size(S, 2);
nBins = size(S, 1);
powerSpectrum = abs(S).^2 + eps;
logPower = log(powerSpectrum);
normalisedMagnitude = abs(S) ./ (sqrt(sum(abs(S).^2, 1)) + eps);

nBands = 8;
edges = round(linspace(1, nBins + 1, nBands + 1));
subbandLogEnergy = zeros(nBands, nFrames);
for b = 1:nBands
    bins = edges(b):edges(b + 1) - 1;
    subbandLogEnergy(b, :) = log(mean(powerSpectrum(bins, :), 1) + eps);
end

logSpectrumScore = zeros(1, nFrames);
spectralFluxScore = zeros(1, nFrames);
modulationScore = zeros(1, nFrames);
smoothedLogPower = logPower(:, 1);
smoothedModulation = 0;
for k = 2:nFrames
    logSpectrumScore(k) = mean(abs(logPower(:, k) - smoothedLogPower));
    smoothedLogPower = 0.85 * smoothedLogPower + 0.15 * logPower(:, k);

    positiveDifference = max(normalisedMagnitude(:, k) - ...
        normalisedMagnitude(:, k - 1), 0);
    spectralFluxScore(k) = sqrt(mean(positiveDifference.^2));

    first = max(1, k - 4);
    localTrajectory = subbandLogEnergy(:, first:k);
    if size(localTrajectory, 2) > 1
        modulationEnergy = sqrt(mean(diff(localTrajectory, 1, 2).^2, 'all'));
        modulationScore(k) = abs(modulationEnergy - smoothedModulation);
        smoothedModulation = 0.9 * smoothedModulation + 0.1 * modulationEnergy;
    end
end

rawScores = [logSpectrumScore; spectralFluxScore; modulationScore];
selectedScore = zeros(1, nFrames);
threshold = inf(1, nFrames);
historyFrames = max(12, round(1.0 / median(diff(frameTimes))));
warmupFrames = min(nFrames, 12);
thresholdScale = 6;

for k = warmupFrames + 1:nFrames
    first = max(1, k - historyFrames);
    history = rawScores(:, first:k - 1);
    centres = median(history, 2);
    spreads = median(abs(history - centres), 2) + eps;
    robustScores = (rawScores(:, k) - centres) ./ spreads;
    switch cue
        case "log_spectrum"
            selectedScore(k) = rawScores(1, k);
            threshold(k) = centres(1) + thresholdScale * spreads(1);
        case "spectral_flux"
            selectedScore(k) = rawScores(2, k);
            threshold(k) = centres(2) + thresholdScale * spreads(2);
        case "modulation"
            selectedScore(k) = rawScores(3, k);
            threshold(k) = centres(3) + thresholdScale * spreads(3);
        case "combined"
            selectedScore(k) = max(robustScores);
            threshold(k) = thresholdScale;
    end
end

candidate = selectedScore > threshold;
% Two adjacent exceedances reject isolated speech-induced spikes.
persistentCandidate = candidate & [false candidate(1:end - 1)];
holdFrames = max(1, round(0.35 / median(diff(frameTimes))));
triggers = false(1, nFrames);
holdRemaining = 0;
for k = 1:nFrames
    if holdRemaining > 0
        holdRemaining = holdRemaining - 1;
    elseif persistentCandidate(k)
        triggers(k) = true;
        holdRemaining = holdFrames;
    end
end

diagnostics = struct( ...
    'frameTimes', frameTimes(:), ...
    'cue', cue, ...
    'score', selectedScore(:), ...
    'threshold', threshold(:), ...
    'triggers', triggers(:), ...
    'logSpectrumScore', logSpectrumScore(:), ...
    'spectralFluxScore', spectralFluxScore(:), ...
    'modulationScore', modulationScore(:));
end
