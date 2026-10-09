function result = score_change_events(triggerTimes, changeTime, endTime, startTime)
%SCORE_CHANGE_EVENTS Match at most one alarm to a known change in [0,1.5] s.
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
% This rate includes extra alarms inside the matching window as false alarms.
result = struct('isChange', isChange, 'hit', ~isempty(matched), ...
    'latency', latency, 'falseCount', numel(falseTimes), ...
    'exposureSeconds', exposure, 'falseTimes', falseTimes);
end
