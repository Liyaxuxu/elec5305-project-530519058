function [enhanced, diagnostics] = transition_wiener( ...
    noisy, fs, mode, knownTransitionTime, changeCue, options)
%TRANSITION_WIENER Wiener filter where a controller sets how fast it adapts.
% mode:
%   "fixed"        always slow
%   "snr"          faster when the frame SNR is low
%   "change"       fast for a short time after a detector trigger
%   "oracle"       fast for a short time from the true change time
%   "always_fast"  always fast
%   "snr_change"   SNR rule + change trigger, whichever is faster
% options (defaults = original controller):
%   causalStartup   only use past frames in the 0.5 s noise-only start [false]
%   detector        precomputed detector output (.triggers)
%   fastNoiseAlpha  noise smoothing in the fast state [0.90]
%   fastGainAlpha   gain smoothing in the fast state [0.55]
%   holdSeconds     how long the fast state lasts [0.35]
%   releaseSeconds  ramp back to slow after the hold [0]
%   noiseFloorGuard raise the noise estimate to a running minimum [false]
%   guardWindowSeconds, guardBias  guard settings [1.0, 1.5]
%   gainFloor       minimum gain [0.05]
if nargin < 3, mode = "fixed"; end
if nargin < 4, knownTransitionTime = NaN; end
if nargin < 5, changeCue = "combined"; end
if nargin < 6, options = struct; end
options = fill_defaults(options);
mode = string(mode);
validModes = ["fixed", "snr", "change", "oracle", "always_fast", "snr_change"];
assert(any(mode == validModes), 'Unknown controller mode.');

windowLength = 512;
overlapLength = 384;
hopSeconds = (windowLength - overlapLength) / fs;
% periodic Hamming (Hann caused problems at the edges after istft)
window = hamming(windowLength, 'periodic');
[S, ~, frameTimes] = stft(noisy, fs, Window=window, ...
    OverlapLength=overlapLength, FFTLength=windowLength);

initialFrames = max(1, min(size(S, 2), round(0.25 / hopSeconds)));
noisePsd = median(abs(S(:, 1:initialFrames)).^2, 2) + eps;
if options.causalStartup
    noisePsd = abs(S(:, 1)).^2 + eps;
end
previousGain = ones(size(noisePsd));
if isfield(options, 'detector')
    detector = options.detector;
    assert(numel(detector.triggers) == size(S, 2));
else
    detector = scene_change_detector(S, frameTimes, changeCue);
end
decisionTimes = frameTimes + windowLength/(2*fs);
oracleFrame = find(decisionTimes >= knownTransitionTime, 1);

slowNoiseAlpha = 0.995;
slowGainAlpha = 0.90;
nFrames = size(S, 2);
Y = zeros(size(S));
triggers = false(1, nFrames);
noiseAlphaTrace = zeros(1, nFrames);
gainAlphaTrace = zeros(1, nFrames);
fastWeightTrace = zeros(1, nFrames);
guardTrace = false(1, nFrames);
meanGainTrace = zeros(1, nFrames);
meanNoisePsdTrace = zeros(1, nFrames);
gainMatrix = zeros(size(S));
if options.saveNoisePsd
    noisePsdMatrix = zeros(size(S));
end
holdFrames = max(1, round(options.holdSeconds / hopSeconds));
releaseFrames = max(0, round(options.releaseSeconds / hopSeconds));
holdRemaining = 0;
releaseRemaining = 0;

% running minimum for the optional guard (similar idea to minimum statistics)
guardFrames = max(2, round(options.guardWindowSeconds / hopSeconds));
guardBuffer = inf(size(S, 1), guardFrames);
smoothedPower = abs(S(:, 1)).^2 + eps;

for k = 1:nFrames
    power = abs(S(:, k)).^2 + eps;
    if options.noiseFloorGuard
        smoothedPower = 0.7 * smoothedPower + 0.3 * power;
        guardBuffer(:, mod(k - 1, guardFrames) + 1) = smoothedPower;
    end
    if options.causalStartup && decisionTimes(k) <= 0.5
        % noise-only start: just average the frames so far
        noisePsd = ((k-1)*noisePsd + power)/k;
        Y(:, k) = S(:, k);
        gainMatrix(:, k) = 1;
        meanGainTrace(k) = 1;
        meanNoisePsdTrace(k) = mean(noisePsd);
        if options.saveNoisePsd, noisePsdMatrix(:, k) = noisePsd; end
        continue;
    end

    canTrigger = any(mode == ["change", "snr_change"]);
    if canTrigger && detector.triggers(k) && holdRemaining == 0
        triggers(k) = true;
        holdRemaining = holdFrames;
    elseif mode == "oracle" && isfinite(knownTransitionTime) && ...
            ((options.causalStartup && isequal(k, oracleFrame)) || ...
            (~options.causalStartup && ...
            abs(frameTimes(k) - knownTransitionTime) <= hopSeconds / 2))
        triggers(k) = true;
        holdRemaining = holdFrames;
    end

    % 1 during the hold, then an optional ramp down to 0
    if holdRemaining > 0
        fastWeight = 1;
        holdRemaining = holdRemaining - 1;
        releaseRemaining = releaseFrames;
    elseif releaseRemaining > 0
        fastWeight = releaseRemaining / (releaseFrames + 1);
        releaseRemaining = releaseRemaining - 1;
    else
        fastWeight = 0;
    end

    posteriorSnr = power ./ noisePsd;
    instantaneousPrior = max(posteriorSnr - 1, 0);
    frameSnrDb = 10 * log10(max(mean(instantaneousPrior), eps));
    lowSnrWeight = min(max((5 - frameSnrDb) / 15, 0), 1);
    snrNoiseAlpha = slowNoiseAlpha - 0.055 * lowSnrWeight;
    snrGainAlpha = slowGainAlpha - 0.20 * lowSnrWeight;
    triggeredNoiseAlpha = blend(slowNoiseAlpha, options.fastNoiseAlpha, fastWeight);
    triggeredGainAlpha = blend(slowGainAlpha, options.fastGainAlpha, fastWeight);

    switch mode
        case "fixed"
            noiseAlpha = slowNoiseAlpha;
            gainAlpha = slowGainAlpha;
        case "snr"
            noiseAlpha = snrNoiseAlpha;
            gainAlpha = snrGainAlpha;
        case "always_fast"
            fastWeight = 1;
            noiseAlpha = options.fastNoiseAlpha;
            gainAlpha = options.fastGainAlpha;
        case "snr_change"
            noiseAlpha = min(snrNoiseAlpha, triggeredNoiseAlpha);
            gainAlpha = min(snrGainAlpha, triggeredGainAlpha);
        otherwise % "change" and "oracle"
            noiseAlpha = triggeredNoiseAlpha;
            gainAlpha = triggeredGainAlpha;
    end

    % bins that look like speech update less; the 6x cap stops big jumps
    noiseObservation = min(power, 6 * noisePsd);
    noiseWeight = 1 ./ (1 + instantaneousPrior);
    updateStep = (1 - noiseAlpha) .* noiseWeight;
    noisePsd = (1 - updateStep) .* noisePsd + updateStep .* noiseObservation;
    if options.noiseFloorGuard
        % without the guard the estimate can't grow if it starts near zero
        floorEstimate = options.guardBias * min(guardBuffer, [], 2);
        raise = floorEstimate > noisePsd;
        noisePsd(raise) = floorEstimate(raise);
        guardTrace(k) = any(raise);
    end
    targetGain = max(instantaneousPrior ./ (1 + instantaneousPrior), ...
        options.gainFloor);
    gain = gainAlpha * previousGain + (1 - gainAlpha) * targetGain;
    Y(:, k) = gain .* S(:, k);
    gainMatrix(:, k) = gain;
    previousGain = gain;

    noiseAlphaTrace(k) = noiseAlpha;
    gainAlphaTrace(k) = gainAlpha;
    fastWeightTrace(k) = fastWeight;
    meanGainTrace(k) = mean(gain);
    meanNoisePsdTrace(k) = mean(noisePsd);
    if options.saveNoisePsd, noisePsdMatrix(:, k) = noisePsd; end
end

enhanced = istft(Y, fs, Window=window, OverlapLength=overlapLength, ...
    FFTLength=windowLength);
enhanced = enhanced(1:min(numel(enhanced), numel(noisy)));
diagnostics = struct( ...
    'frameTimes', frameTimes(:), ...
    'decisionTimes', decisionTimes(:), ...
    'changeCue', string(changeCue), ...
    'changeScore', detector.score, ...
    'changeThreshold', detector.threshold, ...
    'triggers', triggers(:), ...
    'noiseAlpha', noiseAlphaTrace(:), ...
    'gainAlpha', gainAlphaTrace(:), ...
    'fastWeight', fastWeightTrace(:), ...
    'guardActive', guardTrace(:), ...
    'meanGain', meanGainTrace(:), ...
    'meanNoisePsd', meanNoisePsdTrace(:), ...
    'gainMatrix', gainMatrix, ...
    'detector', detector);
if options.saveNoisePsd
    diagnostics.noisePsdMatrix = noisePsdMatrix;
end
end

function value = blend(slow, fast, weight)
% return the exact end values so the default controller doesn't change
if weight >= 1
    value = fast;
elseif weight <= 0
    value = slow;
else
    value = slow + weight * (fast - slow);
end
end

function options = fill_defaults(options)
defaults = struct('causalStartup', false, 'fastNoiseAlpha', 0.90, ...
    'fastGainAlpha', 0.55, 'holdSeconds', 0.35, 'releaseSeconds', 0, ...
    'noiseFloorGuard', false, 'guardWindowSeconds', 1.0, ...
    'guardBias', 1.5, 'gainFloor', 0.05, 'saveNoisePsd', false);
names = fieldnames(defaults);
for j = 1:numel(names)
    if ~isfield(options, names{j})
        options.(names{j}) = defaults.(names{j});
    end
end
end
