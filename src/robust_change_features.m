function features = robust_change_features(S, frameTimes)
%ROBUST_CHANGE_FEATURES Past-only noise-floor and speech-proxy descriptors.
hop = median(diff(frameTimes));
% MATLAB's default centered STFT: use positive frequencies once, not twice.
P = abs(S(floor(size(S, 1)/2)+2:end, :)).^2 + 1e-12;
nFrames = size(P, 2);
edges = round(linspace(1, size(P, 1)+1, 9));
bands = zeros(8, nFrames);
for b = 1:8
    bands(b, :) = mean(P(edges(b):edges(b+1)-1, :), 1);
end
recentCount = max(2, round(0.20/hop));
referenceCount = max(2, round(0.65/hop));
delta = zeros(8, nFrames);
speechExcess = zeros(1, nFrames);
noiseOccupancy = -Inf(1, nFrames);
for k = recentCount+referenceCount:nFrames
    recent = bands(:, k-recentCount+1:k);
    previous = bands(:, k-recentCount-referenceCount+1:k-recentCount);
    % Lower temporal quantiles limit the influence of short voiced peaks.
    recentFloor = prctile(recent, 20, 2);
    previousFloor = prctile(previous, 20, 2);
    delta(:, k) = 10*log10((recentFloor+1e-12)./(previousFloor+1e-12));
    speechExcess(k) = max(0, 10*log10( ...
        (sum(bands(:, k))+1e-12)/(sum(recentFloor)+1e-12)));
    combined = [previous recent];
    referenceLevel = prctile(sum(combined, 1), 80);
    persistentFloor = max(sum(recentFloor), sum(previousFloor));
    % Continuous noise occupies the lower temporal envelope. Speech-only
    % windows usually have a much lower floor because of pauses and gaps.
    noiseOccupancy(k) = 10*log10((persistentFloor+1e-12) / ...
        (referenceLevel+1e-12));
end
legacy = scene_change_detector(S, frameTimes, "combined");
features = struct('frameTimes', frameTimes(:), ...
    'floorScore', median(abs(delta), 1)', ...
    'legacyScore', legacy.score, 'speechExcessDb', speechExcess(:), ...
    'noiseOccupancyDb', noiseOccupancy(:), ...
    'bandDeltaDb', delta, 'warmupSeconds', 1.0);
end
