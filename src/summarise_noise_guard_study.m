function summarise_noise_guard_study
%SUMMARISE_NOISE_GUARD_STUDY Condition tables and cluster uncertainty.
root = fileparts(fileparts(mfilename('fullpath')));
folder = fullfile(root,'results','noise_guard_study');
assert_disjoint_manifests(folder);
for split = ["development","confirmation"]
    detection = readtable(fullfile(folder,split+"_detection.csv"), ...
        TextType="string");
    quality = readtable(fullfile(folder,split+"_quality.csv"), ...
        TextType="string");
    detectionByCondition = groupsummary(detection,{'method','condition'}, ...
        {'mean','sum'},{'hit','latency_s','false_count','exposure_seconds'});
    detectionByCondition.false_alarms_per_minute = 60 * ...
        detectionByCondition.sum_false_count ./ ...
        detectionByCondition.sum_exposure_seconds;
    writetable(detectionByCondition,fullfile(folder, ...
        split+"_detection_by_condition.csv"));
    qualityByCondition = groupsummary(quality,{'system','condition'}, ...
        {'mean','std'},{'whole_si_sdr_db','stoi','transition_si_sdr_db'});
    writetable(qualityByCondition,fullfile(folder, ...
        split+"_quality_by_condition.csv"));
end

detection = readtable(fullfile(folder,'confirmation_detection.csv'), ...
    TextType="string");
quality = readtable(fullfile(folder,'confirmation_quality.csv'), ...
    TextType="string");
replicates = extract_replicate(detection.case_id);
qualityReplicates = extract_replicate(quality.case_id);
cluster = table;
for r = 1:6
    change = detection.is_change & replicates==r;
    controls = ~detection.is_change & replicates==r;
    old = detection.method=="unguarded";
    guarded = detection.method=="noise_guarded";
    hitDelta = mean(detection.hit(change & guarded))- ...
        mean(detection.hit(change & old));
    falseDelta = 60*sum(detection.false_count(controls & guarded))/ ...
        sum(detection.exposure_seconds(controls & guarded))- ...
        60*sum(detection.false_count(controls & old))/ ...
        sum(detection.exposure_seconds(controls & old));
    fixed = quality.system=="fixed" & qualityReplicates==r;
    tuned = quality.system=="guard_and_tuned" & qualityReplicates==r;
    wholeDelta = mean(quality.whole_si_sdr_db(tuned),'omitnan')- ...
        mean(quality.whole_si_sdr_db(fixed),'omitnan');
    stoiDelta = mean(quality.stoi(tuned))-mean(quality.stoi(fixed));
    transitionDelta = mean(quality.transition_si_sdr_db(tuned),'omitnan')- ...
        mean(quality.transition_si_sdr_db(fixed),'omitnan');
    cluster = [cluster;table(r,hitDelta,falseDelta,wholeDelta,stoiDelta, ...
        transitionDelta,'VariableNames',{'replicate','hit_rate_delta', ...
        'control_false_alarms_per_minute_delta','whole_si_sdr_db_delta', ...
        'stoi_delta','transition_si_sdr_db_delta'})]; %#ok<AGROW>
end
rng(530519058); draws = 5000;
metrics = cluster.Properties.VariableNames(2:end); uncertainty = table;
for k = 1:numel(metrics)
    values = cluster.(metrics{k}); boot = zeros(draws,1);
    for b = 1:draws
        boot(b) = mean(values(randi(6,6,1)),'omitnan');
    end
    uncertainty = [uncertainty;table(string(metrics{k}),mean(values,'omitnan'), ...
        prctile(boot,2.5),prctile(boot,97.5),'VariableNames', ...
        {'metric','mean_delta','lower_95','upper_95'})]; %#ok<AGROW>
end
writetable(cluster,fullfile(folder,'confirmation_cluster_deltas.csv'));
writetable(uncertainty,fullfile(folder,'confirmation_paired_uncertainty.csv'));
disp(uncertainty);
end

function assert_disjoint_manifests(folder)
development = readtable(fullfile(folder,'development_manifest.csv'), ...
    TextType="string");
confirmation = readtable(fullfile(folder,'confirmation_manifest.csv'), ...
    TextType="string");
developmentSpeech = unique(split(join(development.speech_files,";"),";"));
confirmationSpeech = unique(split(join(confirmation.speech_files,";"),";"));
assert(isempty(intersect(developmentSpeech,confirmationSpeech)), ...
    'Development and confirmation speech files overlap.');
developmentNoise = unique([development.noise_start_s, ...
    development.noise_start_s+development.duration_s],'rows');
confirmationNoise = unique([confirmation.noise_start_s, ...
    confirmation.noise_start_s+confirmation.duration_s],'rows');
for d = 1:size(developmentNoise,1)
    for c = 1:size(confirmationNoise,1)
        assert(developmentNoise(d,2)<=confirmationNoise(c,1) || ...
            confirmationNoise(c,2)<=developmentNoise(d,1), ...
            'Development and confirmation noise intervals overlap.');
    end
end
end

function replicate = extract_replicate(ids)
replicate = zeros(size(ids));
for k = 1:numel(ids)
    token = regexp(ids(k),'_(\d+)_','tokens','once');
    replicate(k) = str2double(token{1});
end
end
