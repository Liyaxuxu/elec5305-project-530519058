function run_noise_guard_study(phase)
%RUN_NOISE_GUARD_STUDY Tune on development, then run one frozen confirmation.
arguments
    phase (1,1) string {mustBeMember(phase,["develop","confirm"])}
end
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root,'results','noise_guard_study');
if ~isfolder(out), mkdir(out); end
split = "development";
if phase == "confirm", split = "confirmation"; end
[cases,manifest] = build_detector_cases(root,split);
writetable(manifest,fullfile(out,split+"_manifest.csv"));
[features,unguarded] = extract_detectors(cases,root);

if phase == "develop"
    [detectorConfig,detectorSearch] = select_guard(cases,features,unguarded);
    writetable(detectorSearch,fullfile(out,'development_detector_search.csv'));
    guarded = make_detectors(features,detectorConfig);
    [controllerConfig,controllerSearch] = select_controller(cases,guarded);
    writetable(controllerSearch,fullfile(out,'development_controller_search.csv'));
    frozen = struct('detector',detectorConfig,'controller',controllerConfig, ...
        'selectionSplit',"development",'confirmationSplit',"confirmation");
    write_json(fullfile(out,'frozen_config.json'),frozen);
else
    file = fullfile(out,'frozen_config.json');
    assert(isfile(file),'Run the development phase first.');
    frozen = jsondecode(fileread(file));
    detectorConfig = normalise_detector_config(frozen.detector);
    controllerConfig = frozen.controller;
    guarded = make_detectors(features,detectorConfig);
end

[ungRows,ungEvents] = evaluate_detector(cases,unguarded,"unguarded");
[guardRows,guardEvents] = evaluate_detector(cases,guarded,"noise_guarded");
detectionRows = [ungRows;guardRows];
detectionSummary = [summarise_detector(ungRows,"unguarded"); ...
    summarise_detector(guardRows,"noise_guarded")];
writetable(detectionRows,fullfile(out,split+"_detection.csv"));
writetable([ungEvents;guardEvents],fullfile(out,split+"_events.csv"));
writetable(detectionSummary,fullfile(out,split+"_detection_summary.csv"));

quality = evaluate_final_systems(cases,unguarded,guarded,controllerConfig);
qualitySummary = groupsummary(quality,'system',{'mean','std'}, ...
    {'whole_si_sdr_db','stoi','transition_si_sdr_db'});
writetable(quality,fullfile(out,split+"_quality.csv"));
writetable(qualitySummary,fullfile(out,split+"_quality_summary.csv"));
make_figures(cases,guarded,detectionSummary,quality,out,split);
disp(detectionSummary); disp(qualitySummary);
end

function [features,detectors] = extract_detectors(cases,root)
base = jsondecode(fileread(fullfile(root,'results','detector_revision', ...
    'frozen_config.json')));
base = normalise_detector_config(base);
base.noiseOccupancyThresholdDb = -100;
features = cell(size(cases)); detectors = cell(size(cases));
for c = 1:numel(cases)
    [S,~,t] = stft(cases(c).noisy,cases(c).fs, ...
        Window=hamming(512,'periodic'),OverlapLength=384,FFTLength=512);
    features{c} = robust_change_features(S,t);
    detectors{c} = trigger_change_features(features{c},base);
end
end

function config = normalise_detector_config(config)
config.family = string(config.family);
end

function detectors = make_detectors(features,config)
detectors = cellfun(@(f) trigger_change_features(f,config),features, ...
    'UniformOutput',false);
end

function [selected,search] = select_guard(cases,features,unguarded)
base = struct('family',"floor",'threshold',8,'persistenceFrames',4, ...
    'speechWeight',0.75,'noiseOccupancyThresholdDb',-100);
baseRows = evaluate_detector(cases,unguarded,"unguarded");
baseSummary = summarise_detector(baseRows,"unguarded");
thresholds = [-100,-18,-15,-12,-9,-6,-3];
search = table;
for threshold = thresholds
    config = base; config.noiseOccupancyThresholdDb = threshold;
    rows = evaluate_detector(cases,make_detectors(features,config),"candidate");
    summary = summarise_detector(rows,"candidate");
    summary.noise_occupancy_threshold_db = threshold;
    search = [search;summary]; %#ok<AGROW>
end
% The guard is allowed to reject false alarms, not scheduled changes.
eligible = search.hit_rate >= baseSummary.hit_rate;
cost = search.no_change_false_alarms_per_minute + ...
    5*search.penalised_latency_s + 20*(1-search.hit_rate);
cost(~eligible) = Inf;
assert(any(eligible),'No guard preserves the development hit rate.');
[~,index] = min(cost);
search.selection_cost = cost;
search.selected = false(height(search),1); search.selected(index) = true;
selected = base;
selected.noiseOccupancyThresholdDb = ...
    search.noise_occupancy_threshold_db(index);
end

function [selected,search] = select_controller(cases,detectors)
fixedRows = evaluate_quality(cases,detectors,struct,"fixed","fixed");
fixedWhole = mean(fixedRows.whole_si_sdr_db,'omitnan');
fixedStoi = mean(fixedRows.stoi);
search = table;
noiseAlphas = [0.90,0.94,0.97,0.985];
gainAlphas = [0.55,0.70,0.82,0.90];
holdSeconds = [0.10,0.20,0.35];
for noiseAlpha = noiseAlphas
    for gainAlpha = gainAlphas
        for hold = holdSeconds
            options = struct('fastNoiseAlpha',noiseAlpha, ...
                'fastGainAlpha',gainAlpha,'fastHoldSeconds',hold);
            rows = evaluate_quality(cases,detectors,options,"change","candidate");
            change = isfinite([cases.changeTime])';
            summary = table(noiseAlpha,gainAlpha,hold, ...
                mean(rows.whole_si_sdr_db,'omitnan'),mean(rows.stoi), ...
                mean(rows.transition_si_sdr_db(change),'omitnan'), ...
                'VariableNames',{'fast_noise_alpha','fast_gain_alpha', ...
                'hold_seconds','mean_whole_si_sdr_db','mean_stoi', ...
                'mean_transition_si_sdr_db'});
            search = [search;summary]; %#ok<AGROW>
        end
    end
end
eligible = search.mean_whole_si_sdr_db >= fixedWhole & ...
    search.mean_stoi >= fixedStoi-0.001;
if ~any(eligible)
    eligible = search.mean_whole_si_sdr_db >= fixedWhole-0.25 & ...
        search.mean_stoi >= fixedStoi-0.001;
end
score = search.mean_transition_si_sdr_db + ...
    0.25*(search.mean_whole_si_sdr_db-fixedWhole);
score(~eligible) = -Inf;
assert(any(eligible),'No controller satisfies the development quality guardrails.');
[~,index] = max(score);
search.selection_score = score;
search.selected = false(height(search),1); search.selected(index) = true;
selected = struct('fastNoiseAlpha',search.fast_noise_alpha(index), ...
    'fastGainAlpha',search.fast_gain_alpha(index), ...
    'fastHoldSeconds',search.hold_seconds(index));
end

function [rows,events] = evaluate_detector(cases,detectors,method)
rows = table; events = table;
for c = 1:numel(cases)
    alarms = detectors{c}.frameTimes(detectors{c}.triggers)+0.016;
    result = score_change_events(alarms,cases(c).changeTime,8,1);
    penalty = 1.5; if result.hit, penalty = result.latency; end
    rows = [rows;table(cases(c).id,cases(c).condition,method, ...
        result.isChange,result.hit,result.latency,penalty,result.falseCount, ...
        result.exposureSeconds,'VariableNames',{'case_id','condition','method', ...
        'is_change','hit','latency_s','penalised_latency_s','false_count', ...
        'exposure_seconds'})]; %#ok<AGROW>
    for eventTime = result.falseTimes(:)'
        sample = min(numel(cases(c).clean),max(1,round(eventTime*cases(c).fs)));
        energy = movmean(cases(c).clean.^2,round(0.02*cases(c).fs));
        active = energy > max(1e-10,0.02*max(energy));
        occupancy = interp1(detectors{c}.frameTimes, ...
            detectors{c}.noiseOccupancyDb,eventTime,'nearest','extrap');
        events = [events;table(cases(c).id,cases(c).condition,method, ...
            eventTime,active(sample),occupancy,'VariableNames',{'case_id', ...
            'condition','method','false_alarm_time_s','reference_speech_active', ...
            'noise_occupancy_db'})]; %#ok<AGROW>
    end
end
end

function summary = summarise_detector(rows,method)
change = rows.is_change; controls = ~change;
summary = table(method,mean(rows.hit(change)), ...
    mean(rows.latency_s(change & rows.hit),'omitnan'), ...
    mean(rows.penalised_latency_s(change)), ...
    60*sum(rows.false_count)/sum(rows.exposure_seconds), ...
    60*sum(rows.false_count(controls))/sum(rows.exposure_seconds(controls)), ...
    'VariableNames',{'method','hit_rate','matched_latency_s', ...
    'penalised_latency_s','false_alarms_per_minute', ...
    'no_change_false_alarms_per_minute'});
end

function rows = evaluate_quality(cases,detectors,options,mode,label)
rows = table;
for c = 1:numel(cases)
    current = cases(c); currentOptions = options;
    currentOptions.causalStartup = true;
    if mode == "change", currentOptions.detector = detectors{c}; end
    if mode == "fixed"
        [output,~] = transition_wiener(current.noisy,current.fs,"fixed", ...
            current.changeTime,"combined",currentOptions);
    else
        [output,~] = transition_wiener(current.noisy,current.fs,mode, ...
            current.changeTime,"combined",currentOptions);
    end
    output = real(output(1:numel(current.clean)));
    local = NaN;
    if isfinite(current.changeTime)
        region = round(current.changeTime*current.fs)+1: ...
            round((current.changeTime+0.75)*current.fs);
        local = sisdr(current.clean(region),output(region));
    end
    rows = [rows;table(current.id,current.condition,label, ...
        sisdr(current.clean,output),stoi(output,current.clean,current.fs),local, ...
        'VariableNames',{'case_id','condition','system','whole_si_sdr_db', ...
        'stoi','transition_si_sdr_db'})]; %#ok<AGROW>
end
end

function rows = evaluate_final_systems(cases,unguarded,guarded,controller)
rows = table;
definitions = {"fixed","fixed",struct,guarded; ...
    "snr","snr",struct,guarded; ...
    "old_response","change",struct,unguarded; ...
    "guard_only","change",struct,guarded; ...
    "guard_and_tuned","change",controller,guarded; ...
    "oracle_tuned","oracle",controller,guarded};
for k = 1:size(definitions,1)
    current = evaluate_quality(cases,definitions{k,4},definitions{k,3}, ...
        definitions{k,2},definitions{k,1});
    rows = [rows;current]; %#ok<AGROW>
end
end

function value = sisdr(reference,estimate)
reference = reference-mean(reference); estimate = estimate-mean(estimate);
target = reference*(reference'*estimate)/(reference'*reference+eps);
residual = sum((estimate-target).^2);
if residual < 1e-12*sum(target.^2), value = NaN; return; end
value = 10*log10((sum(target.^2)+eps)/(residual+eps));
end

function write_json(path,value)
fid = fopen(path,'w'); cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true)); clear cleanup;
end

function make_figures(cases,detectors,detection,quality,out,split)
fig = figure('Visible','off','Color','w','Position',[100 100 900 400]);
tiledlayout(1,2);
nexttile; bar(detection.hit_rate); xticks(1:2);
xticklabels({'Unguarded','Guarded'}); ylabel('Rate'); title('Change detection');
nexttile; bar(detection.no_change_false_alarms_per_minute); xticks(1:2);
xticklabels({'Unguarded','Guarded'}); ylabel('False alarms/min');
title('No-change controls'); grid on;
exportgraphics(fig,fullfile(out,split+"_detector.png"),Resolution=160); close(fig);

systems = unique(quality.system,'stable'); values = zeros(numel(systems),2);
for k = 1:numel(systems)
    match = quality.system==systems(k);
    values(k,1) = mean(quality.whole_si_sdr_db(match));
    values(k,2) = mean(quality.transition_si_sdr_db(match),'omitnan');
end
fig = figure('Visible','off','Color','w','Position',[100 100 980 430]);
bar(values); xticklabels(strrep(systems,'_',' ')); xtickangle(20);
ylabel('SI-SDR (dB)'); legend('Whole signal','Transition region', ...
    'Location','best'); title('Controller response comparison'); grid on;
exportgraphics(fig,fullfile(out,split+"_quality.png"),Resolution=160); close(fig);

% Fixed, reproducible clean-control example for interpreting the guard.
c = find(string({cases.condition})=="clean_control",1);
d = detectors{c}; fig = figure('Visible','off','Color','w', ...
    'Position',[100 100 980 590]); tiledlayout(2,1);
nexttile; plot(d.frameTimes,d.score); hold on; plot(d.frameTimes,d.threshold,'--');
scatter(d.frameTimes(d.triggers),d.score(d.triggers),20,'filled');
xlim([1 8]); title('Guarded detector on clean speech'); ylabel('Change score');
nexttile; plot(d.frameTimes,d.noiseOccupancyDb); hold on;
yline(d.noiseOccupancyThresholdDb,'--'); xlim([1 8]);
ylabel('Noise occupancy (dB)'); xlabel('Time (s)'); grid on;
exportgraphics(fig,fullfile(out,split+"_clean_control.png"),Resolution=160);
close(fig);
end
