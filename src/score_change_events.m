function result = score_change_events(triggerTimes, changeTime, endTime, startTime)
%SCORE_CHANGE_EVENTS Count the hit and false alarms for one case (1.5 s window).
if nargin < 4, startTime = 1; end
triggerTimes = triggerTimes(triggerTimes >= startTime & triggerTimes <= endTime);
isChange = isfinite(changeTime);
matched = [];
latency = NaN;
if isChange
    matched = find(triggerTimes >= changeTime & triggerTimes <= changeTime+1.5, 1);
    if ~isempty(matched), latency = triggerTimes(matched)-changeTime; end
end
falseTimes = triggerTimes;
falseTimes(matched) = [];
exposure = max(endTime-startTime, eps);
if isChange
    exposure = max(exposure - max(0, min(endTime, changeTime+1.5) - ...
        max(startTime, changeTime)), eps);
end
% extra alarms inside the 1.5 s window also count as false alarms
result = struct('isChange', isChange, 'hit', ~isempty(matched), ...
    'latency', latency, 'falseCount', numel(falseTimes), ...
    'exposureSeconds', exposure, 'falseTimes', falseTimes);
end
