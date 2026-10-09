function summarise_detector_revision
%SUMMARISE_DETECTOR_REVISION Paired, sequence-clustered uncertainty estimates.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root,'results','detector_revision');
results = table;
for split = ["development","validation"]
    detections = readtable(fullfile(out,split+"_detection.csv"),TextType='string');
    detections.is_change = logical(detections.is_change);
    detections.hit = logical(detections.hit);
    metrics = readtable(fullfile(out,split+"_enhancement.csv"),TextType='string');
    events = readtable(fullfile(out,split+"_events.csv"),TextType='string');
    byCondition = table;
    for method = ["legacy_combined","revised"]
        for condition = unique(detections.condition)'
            r = detections(detections.method==method & detections.condition==condition,:);
            byCondition = [byCondition;table(method,condition, ...
                mean(r.hit),mean(r.latency_s,'omitnan'), ...
                60*sum(r.false_count)/sum(r.monitored_seconds), ...
                'VariableNames',{'method','condition','hit_rate','latency_s', ...
                'false_alarms_per_minute'})]; %#ok<AGROW>
        end
    end
    writetable(byCondition,fullfile(out,split+"_by_condition.csv"));
    writetable(groupsummary(events,'method','mean', ...
        {'reference_speech_active','within_100ms_of_reference_onset'}), ...
        fullfile(out,split+"_false_alarm_context.csv"));
    % All eight variants reuse a sequence: resample six sequences, not 48 rows.
    deltas = zeros(6,5);
    for replicate = 1:6
        old = detections(detections.replicate==replicate & ...
            detections.method=="legacy_combined",:);
        new = detections(detections.replicate==replicate & ...
            detections.method=="revised",:);
        oldControls = old(~old.is_change,:); newControls = new(~new.is_change,:);
        deltas(replicate,1) = mean(new.hit(new.is_change))-mean(old.hit(old.is_change));
        deltas(replicate,2) = 60*(sum(newControls.false_count)-sum(oldControls.false_count))/ ...
            sum(oldControls.monitored_seconds);
        oldMetrics = metrics(metrics.replicate==replicate & metrics.system=="legacy_combined",:);
        newMetrics = metrics(metrics.replicate==replicate & metrics.system=="revised",:);
        deltas(replicate,3) = mean(newMetrics.stoi-oldMetrics.stoi);
        deltas(replicate,4) = mean(newMetrics.whole_si_sdr_db-oldMetrics.whole_si_sdr_db,'omitnan');
        deltas(replicate,5) = mean(new.penalised_latency_s(new.is_change))- ...
            mean(old.penalised_latency_s(old.is_change));
    end
    rng(19058); draws = randi(6,6,5000);
    names = ["hit_rate","no_change_false_alarms_per_minute","stoi", ...
        "whole_si_sdr_db","penalised_latency_s"];
    for j = 1:5
        values = deltas(:,j); boot = mean(values(draws),1);
        limits = prctile(boot,[2.5,97.5]);
        results = [results;table(split,names(j),mean(values),limits(1),limits(2), ...
            'VariableNames',{'split','metric','revised_minus_original', ...
            'cluster_bootstrap_95_low','cluster_bootstrap_95_high'})]; %#ok<AGROW>
    end
end
writetable(results,fullfile(out,'paired_uncertainty.csv')); disp(results);
dev = readtable(fullfile(out,'development_manifest.csv'),TextType='string');
val = readtable(fullfile(out,'validation_manifest.csv'),TextType='string');
devNames = unique(splitNames(dev.speech_files));
valNames = unique(splitNames(val.speech_files));
assert(isempty(intersect(devNames,valNames)), 'Speech files overlap splits.');
assert(max(dev.noise_start_s+dev.duration_s) <= min(val.noise_start_s));
disp('Manifest checks passed: speech files and noise intervals are disjoint.');
end

function names = splitNames(values)
names = strings(0,1);
for k = 1:numel(values), names = [names;split(values(k),';')]; end %#ok<AGROW>
end
