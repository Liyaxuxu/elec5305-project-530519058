function detector = trigger_change_features(features, config)
%TRIGGER_CHANGE_FEATURES Persistence and speech-conditioned trigger threshold.
t = features.frameTimes;
hop = median(diff(t));
if config.family == "floor"
    score = features.floorScore;
else
    score = features.legacyScore;
end
% This is a heuristic speech proxy, not a trained or reference-label VAD.
threshold = config.threshold + config.speechWeight * ...
    max(features.speechExcessDb-6, 0);
above = score > threshold & t >= features.warmupSeconds;
triggers = false(size(t));
consecutive = 0;
holdRemaining = 0;
for k = 1:numel(t)
    if holdRemaining > 0
        holdRemaining = holdRemaining-1;
        consecutive = 0;
    else
        if above(k), consecutive = consecutive+1; else, consecutive = 0; end
        if consecutive >= config.persistenceFrames
            triggers(k) = true;
            consecutive = 0;
            holdRemaining = round(0.35/hop);
        end
    end
end
detector = struct('frameTimes', t, 'score', score, 'threshold', threshold, ...
    'triggers', triggers, 'speechExcessDb', features.speechExcessDb);
end
