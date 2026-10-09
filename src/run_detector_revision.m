function run_detector_revision(phase)
%RUN_DETECTOR_REVISION Development selection, then a frozen validation pass.
% run_detector_revision("develop"); run_detector_revision("validate");
arguments
    phase (1,1) string {mustBeMember(phase,["develop","audit_development","validate"])}
end
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'results', 'detector_revision');
if ~isfolder(out), mkdir(out); end
if phase ~= "validate", split = "development"; else, split = "validation"; end
[cases, manifest] = build_detector_cases(root, split);
writetable(manifest, fullfile(out, split+"_manifest.csv"));
featureCache = cell(size(cases)); baseline = cell(size(cases));
for c = 1:numel(cases)
    [S, ~, t] = stft(cases(c).noisy, cases(c).fs, ...
        Window=hamming(512,'periodic'), OverlapLength=384, FFTLength=512);
    featureCache{c} = robust_change_features(S, t);
    baseline{c} = scene_change_detector(S, t, "combined");
end
[baseRows, baseEvents] = evaluate(cases, baseline, "legacy_combined");
baseSummary = summarise(baseRows, "legacy_combined");
if phase == "develop"
    candidates = struct([]); searchRows = table; index = 0;
    for family = ["legacy", "floor"]
        for threshold = [4,6,8,10]
            for persistence = [2,4,8]
                for weight = [0,0.75]
                    index = index+1;
                    config = struct('family',family,'threshold',threshold, ...
                        'persistenceFrames',persistence,'speechWeight',weight);
                    if index == 1, candidates = config;
                    else, candidates(index) = config; end
                    detectors = cellfun(@(f) trigger_change_features(f,config), ...
                        featureCache, 'UniformOutput',false);
                    rows = evaluate(cases, detectors, "candidate");
                    summary = summarise(rows, "candidate");
                    summary.candidate_id = index;
                    summary.family = family; summary.threshold = threshold;
                    summary.persistence_frames = persistence;
                    summary.speech_weight = weight;
                    searchRows = [searchRows; summary]; %#ok<AGROW>
                end
            end
        end
    end
    % A detector cannot win simply by never firing. Misses carry full latency.
    eligible = searchRows.hit_rate >= baseSummary.hit_rate-0.05;
    cost = searchRows.false_alarms_per_minute + ...
        3*searchRows.penalised_latency_s + 20*(1-searchRows.hit_rate);
    cost(~eligible) = Inf;
    [~, best] = min(cost);
    assert(any(eligible), 'No candidate preserves the development hit rate.');
    config = candidates(best);
    searchRows.selection_cost = cost;
    writetable(searchRows, fullfile(out,'development_search.csv'));
    save(fullfile(out,'frozen_config.mat'),'config');
    fid = fopen(fullfile(out,'frozen_config.json'),'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(config,PrettyPrint=true));
    clear cleanup;
else
    assert(isfile(fullfile(out,'frozen_config.json')), 'Run develop first.');
    config = jsondecode(fileread(fullfile(out,'frozen_config.json')));
    config.family = string(config.family);
end
revised = cellfun(@(f) trigger_change_features(f,config), featureCache, ...
    'UniformOutput',false);
[newRows, newEvents] = evaluate(cases, revised, "revised");
ungatedConfig = config; ungatedConfig.speechWeight = 0;
ungated = cellfun(@(f) trigger_change_features(f,ungatedConfig), featureCache, ...
    'UniformOutput',false);
[ungatedRows,ungatedEvents] = evaluate(cases,ungated,"floor_without_speech_gate");
rows = [baseRows;newRows]; events = [baseEvents;newEvents];
summary = [baseSummary;summarise(newRows,"revised")];
writetable([rows;ungatedRows],fullfile(out,split+"_ablation.csv"));
writetable([summary;summarise(ungatedRows,"floor_without_speech_gate")], ...
    fullfile(out,split+"_ablation_summary.csv"));
writetable(ungatedEvents,fullfile(out,split+"_ungated_events.csv"));
writetable(rows,fullfile(out,split+"_detection.csv"));
writetable(events,fullfile(out,split+"_events.csv"));
writetable(summary,fullfile(out,split+"_summary.csv"));
disp(config); disp(summary);

% Audit fixed vs both detectors using identical causal-startup Wiener code.
metrics = table;
for c = 1:numel(cases)
    current = cases(c); n = numel(current.clean);
    for system = ["noisy","fixed","snr","legacy_combined","revised","oracle"]
        options = struct('causalStartup',true);
        mode = system;
        if system == "legacy_combined"
            mode = "change"; options.detector = baseline{c};
        elseif system == "revised"
            mode = "change"; options.detector = revised{c};
        end
        started = tic;
        if system == "noisy"
            output = current.noisy;
        else
            [output, diag] = transition_wiener(current.noisy,current.fs, ...
                mode,current.changeTime,"combined",options);
            % Reapplying the saved gain must reconstruct the actual output.
            reconstruction = apply_stft_gain(current.clean,current.fs,diag.gainMatrix)+ ...
                apply_stft_gain(current.noise,current.fs,diag.gainMatrix);
            assert(norm(reconstruction-output)/max(norm(output),eps)<1e-9);
        end
        seconds = toc(started);
        output = real(output(1:n));
        whole = sisdr(current.clean,output);
        intelligence = stoi(output,current.clean,current.fs);
        local = NaN;
        if isfinite(current.changeTime)
            region = round(current.changeTime*current.fs)+1: ...
                round((current.changeTime+0.75)*current.fs);
            local = sisdr(current.clean(region),output(region));
        end
        metrics = [metrics; table(current.id,current.replicate,current.condition, ...
            system,whole,intelligence,local,seconds,'VariableNames', ...
            {'case_id','replicate','condition','system','whole_si_sdr_db', ...
            'stoi','transition_si_sdr_db','evaluation_runtime_s'})]; %#ok<AGROW>
    end
end
writetable(metrics,fullfile(out,split+"_enhancement.csv"));
metricSummary = groupsummary(metrics,'system',{'mean','std'}, ...
    {'whole_si_sdr_db','stoi','transition_si_sdr_db'});
writetable(metricSummary,fullfile(out,split+"_enhancement_summary.csv"));
disp(metricSummary);
make_plots(cases,baseline,revised,summary,out,split);
end

function [rows,events] = evaluate(cases,detectors,method)
rows = table; events = table;
for c = 1:numel(cases)
    current = cases(c); detector = detectors{c};
    % The centered 32 ms analysis frame is available 16 ms after its centre.
    alarmTimes = detector.frameTimes(detector.triggers)+0.016;
    result = score_change_events(alarmTimes,current.changeTime,8,1);
    penalisedLatency = 1.5;
    if result.hit, penalisedLatency = result.latency; end
    rows = [rows; table(current.id,current.replicate,current.condition,method, ...
        result.isChange,result.hit,result.latency,penalisedLatency, ...
        result.falseCount,7,result.exposureSeconds,'VariableNames', ...
        {'case_id','replicate','condition','method','is_change','hit', ...
        'latency_s','penalised_latency_s','false_count','monitored_seconds', ...
        'non_event_seconds'})]; %#ok<AGROW>
    if nargout < 2, continue; end
    energy = movmean(current.clean.^2,round(0.02*current.fs));
    speech = energy > max(1e-10,0.02*max(energy));
    onsets = find(diff([false;speech])==1)/current.fs;
    for eventTime = result.falseTimes(:)'
        sample = min(numel(speech),max(1,round(eventTime*current.fs)));
        nearOnset = any(abs(onsets-eventTime)<=0.10);
        events = [events; table(current.id,current.condition,method,eventTime, ...
            speech(sample),nearOnset,'VariableNames',{'case_id','condition', ...
            'method','false_alarm_time_s','reference_speech_active', ...
            'within_100ms_of_reference_onset'})]; %#ok<AGROW>
    end
end
end

function summary = summarise(rows,method)
change = rows.is_change;
hitRate = mean(rows.hit(change));
latency = mean(rows.latency_s(change & rows.hit),'omitnan');
penalty = mean(rows.penalised_latency_s(change));
falseRate = 60*sum(rows.false_count)/sum(rows.monitored_seconds);
controls = ~change;
controlRate = 60*sum(rows.false_count(controls))/sum(rows.monitored_seconds(controls));
summary = table(method,hitRate,latency,penalty,falseRate,controlRate, ...
    sum(change),sum(controls),'VariableNames',{'method','hit_rate', ...
    'matched_latency_s','penalised_latency_s','false_alarms_per_minute', ...
    'no_change_false_alarms_per_minute','change_cases','no_change_cases'});
end

function value = sisdr(reference,estimate)
reference = reference-mean(reference); estimate = estimate-mean(estimate);
target = reference*(reference'*estimate)/(reference'*reference+eps);
residual = sum((estimate-target).^2);
if residual < 1e-12*sum(target.^2), value = NaN; return; end
value = 10*log10((sum(target.^2)+eps)/(residual+eps));
end

function make_plots(cases,old,new,summary,out,split)
fig = figure('Visible','off','Color','w','Position',[100 100 1000 420]);
tiledlayout(1,3);
columns = {'hit_rate','no_change_false_alarms_per_minute','matched_latency_s'};
labels = {'Change detection rate','False alarms/min (no change)','Matched latency (s)'};
for j = 1:3
    nexttile; bar(summary.(columns{j})); xticks(1:2);
    xticklabels({'Original','Revised'}); title(labels{j}); grid on;
end
exportgraphics(fig,fullfile(out,split+"_detectors.png"),Resolution=150); close(fig);
% Fixed diagnostic example: first stationary office case, no cherry-picking.
c = find(string({cases.condition})=="stationary_office",1);
fig = figure('Visible','off','Color','w','Position',[100 100 1000 620]);
tiledlayout(3,1);
nexttile; plot((0:numel(cases(c).clean)-1)/cases(c).fs,cases(c).clean);
title('Clean speech reference: no scheduled environmental change');
for j = 1:2
    if j==1, d=old{c}; name="Original combined cue";
    else, d=new{c}; name="Revised cue"; end
    nexttile; plot(d.frameTimes,d.score); hold on;
    plot(d.frameTimes,d.threshold,'--');
    scatter(d.frameTimes(d.triggers),d.score(d.triggers),24,'filled');
    xlim([1 8]); title(name); ylabel('Score'); grid on;
end
xlabel('Frame centre time (s)');
exportgraphics(fig,fullfile(out,split+"_false_alarm_audit.png"),Resolution=150);
close(fig);
end
