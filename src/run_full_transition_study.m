%% Development and held-out transition study
clear; close all; clc;
rng(530519058);

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
dataRoot = fullfile(repoRoot, 'data', 'raw');
resultsRoot = fullfile(repoRoot, 'results');
if ~exist(resultsRoot, 'dir'), mkdir(resultsRoot); end

fs = 16000;
duration = 6.0;
transitionTime = 3.0;
n = round(duration * fs);
nReplicates = 3;
cues = ["log_spectrum", "spectral_flux", "modulation", "combined"];
modes = ["noisy", "fixed", "snr", "change", "oracle"];

cleanDir = fullfile(dataRoot, 'clean_testset_wav');
officePath = fullfile(dataRoot, 'OOFFICE', 'ch01.wav');
trafficPath = fullfile(dataRoot, 'STRAFFIC', 'ch01.wav');
assert(isfolder(cleanDir) && isfile(officePath) && isfile(trafficPath), ...
    'VoiceBank and DEMAND data are required. See data/README.md.');
[office, officeFs] = audioread(officePath);
[traffic, trafficFs] = audioread(trafficPath);
office = resample(mean(office, 2), fs, officeFs);
traffic = resample(mean(traffic, 2), fs, trafficFs);

splitDefinitions = struct( ...
    'name', {"development", "held_out"}, ...
    'speaker', {"p232", "p257"}, ...
    'noiseStartSeconds', {7, 127});
caseList = struct([]);
caseIndex = 0;
for s = 1:numel(splitDefinitions)
    split = splitDefinitions(s);
    for r = 1:nReplicates
        speech = load_speech_sequence(cleanDir, split.speaker, r, fs);
        cleanActive = active_six_second_excerpt(speech, n, fs);
        cleanPause = insert_transition_pause(cleanActive, fs, transitionTime, 0.50);
        startSample = round((split.noiseStartSeconds + (r - 1) * 20) * fs) + 1;
        officeExcerpt = select_excerpt(office, n, startSample);
        trafficExcerpt = select_excerpt(traffic, n, startSample);

        definitions = struct( ...
            'name', {"level_active", "type_active", "onset_active", ...
            "offset_active", "type_pause"}, ...
            'clean', {cleanActive, cleanActive, cleanActive, cleanActive, cleanPause}, ...
            'noiseA', {officeExcerpt, officeExcerpt, zeros(n, 1), ...
            trafficExcerpt, officeExcerpt}, ...
            'noiseB', {officeExcerpt, trafficExcerpt, trafficExcerpt, ...
            zeros(n, 1), trafficExcerpt}, ...
            'snrA', {10, 0, 0, 0, 0}, ...
            'snrB', {0, 0, 0, 0, 0});

        for d = 1:numel(definitions)
            definition = definitions(d);
            [noisy, addedNoise] = generate_dynamic_scene( ...
                definition.clean, definition.noiseA, definition.noiseB, ...
                fs, transitionTime, definition.snrA, definition.snrB);
            caseIndex = caseIndex + 1;
            caseList(caseIndex).split = split.name;
            caseList(caseIndex).speaker = split.speaker;
            caseList(caseIndex).replicate = r;
            caseList(caseIndex).condition = definition.name;
            caseList(caseIndex).clean = definition.clean;
            caseList(caseIndex).noise = addedNoise;
            caseList(caseIndex).noisy = noisy;
        end
    end
end

%% Evaluate scene-change cues independently
detectionRows = table;
for c = 1:numel(caseList)
    current = caseList(c);
    window = hamming(512, 'periodic');
    [S, ~, frameTimes] = stft(current.noisy, fs, Window=window, ...
        OverlapLength=384, FFTLength=512);
    for cue = cues
        detector = scene_change_detector(S, frameTimes, cue);
        triggerTimes = detector.frameTimes(detector.triggers);
        postTrigger = triggerTimes(triggerTimes >= transitionTime);
        if isempty(postTrigger)
            detected = false;
            latency = NaN;
        else
            detected = postTrigger(1) <= transitionTime + 1.5;
            latency = postTrigger(1) - transitionTime;
        end
        falseAlarms = sum(triggerTimes < transitionTime);
        detectionRows = [detectionRows; table(current.split, current.speaker, ...
            current.replicate, current.condition, cue, detected, latency, ...
            falseAlarms, numel(triggerTimes), 'VariableNames', ...
            {'split', 'speaker', 'replicate', 'condition', 'cue', ...
            'detected_within_1_5_s', 'detection_latency_s', ...
            'false_alarms_before_change', 'total_triggers'})]; %#ok<AGROW>
    end
end
writetable(detectionRows, fullfile(resultsRoot, 'detector_ablation.csv'));
detectionSummary = groupsummary(detectionRows, {'split', 'cue'}, ...
    {'mean', 'std'}, {'detected_within_1_5_s', 'detection_latency_s', ...
    'false_alarms_before_change'});
writetable(detectionSummary, fullfile(resultsRoot, 'detector_ablation_summary.csv'));

developmentSummary = detectionSummary(detectionSummary.split == "development", :);
selectionCost = 10 * (1 - developmentSummary.mean_detected_within_1_5_s) + ...
    developmentSummary.mean_false_alarms_before_change + ...
    max(developmentSummary.mean_detection_latency_s, 0);
[~, bestIndex] = min(selectionCost);
selectedCue = string(developmentSummary.cue(bestIndex));
fprintf('Selected development cue: %s\n', selectedCue);

%% Compare enhancement controllers with the frozen selected cue
metricRows = table;
recoveryRows = table;
representative = struct;
for c = 1:numel(caseList)
    current = caseList(c);
    outputs = cell(size(modes));
    outputs{1} = current.noisy;
    diagnostics = cell(size(modes));
    runtimes = zeros(size(modes));
    for m = 2:numel(modes)
        started = tic;
        [outputs{m}, diagnostics{m}] = transition_wiener(current.noisy, ...
            fs, modes(m), transitionTime, selectedCue);
        runtimes(m) = toc(started);
    end

    transitionRegion = time_region(transitionTime, transitionTime + 0.75, fs, n);
    steadyRegion = time_region(transitionTime + 1.5, transitionTime + 2.5, fs, n);
    for m = 1:numel(modes)
        output = outputs{m}(1:n);
        if modes(m) == "noisy"
            processedSpeech = current.clean;
            processedNoise = current.noise;
            speechDistortion = NaN;
            residualSuppression = 0;
        else
            processedSpeech = apply_stft_gain(current.clean, fs, ...
                diagnostics{m}.gainMatrix);
            processedNoise = apply_stft_gain(current.noise, fs, ...
                diagnostics{m}.gainMatrix);
            processedSpeech = fit_audio(processedSpeech, n);
            processedNoise = fit_audio(processedNoise, n);
            speechDistortion = relative_error_db( ...
                current.clean(transitionRegion), processedSpeech(transitionRegion));
            residualSuppression = suppression_db( ...
                current.noise(transitionRegion), processedNoise(transitionRegion));
        end

        row = table(current.split, current.speaker, current.replicate, ...
            current.condition, modes(m), selectedCue, ...
            si_sdr(current.clean, output), ...
            si_sdr(current.clean(transitionRegion), output(transitionRegion)), ...
            si_sdr(current.clean(steadyRegion), output(steadyRegion)), ...
            stoi(output, current.clean, fs), ...
            10 * log10(sum(current.clean.^2) / ...
            (sum((output - current.clean).^2) + eps)), ...
            settling_time(current.clean, output, fs, transitionTime), ...
            speechDistortion, residualSuppression, runtimes(m), ...
            'VariableNames', {'split', 'speaker', 'replicate', 'condition', ...
            'system', 'selected_cue', 'whole_si_sdr_db', ...
            'transition_si_sdr_db', 'steady_si_sdr_db', 'stoi', ...
            'output_snr_db', 'settling_time_s', ...
            'transition_speech_error_db', ...
            'transition_noise_suppression_db', 'runtime_s'});
        metricRows = [metricRows; row]; %#ok<AGROW>

        if current.condition == "type_active"
            recoveryRows = [recoveryRows; local_recovery_rows( ...
                current.split, current.replicate, modes(m), current.clean, ...
                output, fs, transitionTime)]; %#ok<AGROW>
        end
    end

    if current.split == "held_out" && current.replicate == 1 && ...
            current.condition == "type_active"
        representative = current;
        representative.outputs = outputs;
        representative.diagnostics = diagnostics;
    end
end
writetable(metricRows, fullfile(resultsRoot, 'full_transition_metrics.csv'));
writetable(recoveryRows, fullfile(resultsRoot, 'transition_recovery.csv'));
metricNames = {'whole_si_sdr_db', 'transition_si_sdr_db', ...
    'steady_si_sdr_db', 'stoi', 'output_snr_db', 'settling_time_s', ...
    'transition_speech_error_db', 'transition_noise_suppression_db', ...
    'runtime_s'};
metricSummary = groupsummary(metricRows, {'split', 'condition', 'system'}, ...
    {'mean', 'std'}, metricNames);
writetable(metricSummary, fullfile(resultsRoot, 'full_transition_summary.csv'));

%% Figures
create_detector_figure(detectionSummary, cues, resultsRoot);
create_metric_figure(metricSummary, modes, resultsRoot);
create_tradeoff_figure(metricRows, modes, resultsRoot);
create_recovery_figure(recoveryRows, modes, resultsRoot);
create_representative_figure(representative, modes, transitionTime, ...
    selectedCue, fs, resultsRoot);

fid = fopen(fullfile(resultsRoot, 'selected_change_cue.txt'), 'w');
fprintf(fid, '%s\n', selectedCue);
fclose(fid);
disp(detectionSummary);
disp(metricSummary(metricSummary.split == "held_out", :));

function speech = load_speech_sequence(folder, speaker, replicate, fs)
files = dir(fullfile(folder, speaker + "_*.wav"));
assert(~isempty(files), 'No speech files found for %s.', speaker);
startIndex = 1 + (replicate - 1) * 4;
indices = mod((startIndex:startIndex + 5) - 1, numel(files)) + 1;
speech = [];
for index = indices
    [utterance, inputFs] = audioread(fullfile(files(index).folder, files(index).name));
    utterance = resample(mean(utterance, 2), fs, inputFs);
    speech = [speech; utterance; zeros(round(0.08 * fs), 1)]; %#ok<AGROW>
end
speech = speech / (max(abs(speech)) + eps) * 0.75;
end

function clean = active_six_second_excerpt(speech, n, fs)
half = round(0.10 * fs);
energy = movmean(speech.^2, 2 * half + 1);
valid = (round(3 * fs) + 1):(numel(speech) - round(3 * fs));
[~, localIndex] = max(energy(valid));
centre = valid(localIndex);
first = centre - round(3 * fs);
clean = fit_audio(speech(first:end), n);
end

function output = insert_transition_pause(input, fs, transitionTime, pauseDuration)
output = input;
centre = round(transitionTime * fs) + 1;
half = round(pauseDuration * fs / 2);
region = max(1, centre - half):min(numel(input), centre + half);
output(region) = 0;
end

function output = select_excerpt(input, n, startSample)
input = input(:);
startSample = min(max(startSample, 1), max(1, numel(input) - n + 1));
output = fit_audio(input(startSample:end), n);
output = output - mean(output);
end

function output = fit_audio(input, n)
input = input(:);
if numel(input) < n
    input = [input; zeros(n - numel(input), 1)];
end
output = input(1:n);
end

function region = time_region(startTime, endTime, fs, n)
region = max(1, round(startTime * fs) + 1):min(n, round(endTime * fs));
end

function value = si_sdr(reference, estimate)
reference = reference(:) - mean(reference);
estimate = estimate(:) - mean(estimate);
scale = (reference' * estimate) / (reference' * reference + eps);
target = scale * reference;
value = 10 * log10(sum(target.^2) / (sum((estimate - target).^2) + eps));
end

function value = relative_error_db(reference, processed)
value = 10 * log10((sum((processed - reference).^2) + eps) / ...
    (sum(reference.^2) + eps));
end

function value = suppression_db(originalNoise, processedNoise)
if mean(originalNoise.^2) < 1e-12
    value = NaN;
else
    value = 10 * log10((sum(originalNoise.^2) + eps) / ...
        (sum(processedNoise.^2) + eps));
end
end

function seconds = settling_time(reference, estimate, fs, transitionTime)
block = round(0.10 * fs);
startSample = round(transitionTime * fs) + 1;
starts = startSample:block:(numel(reference) - block + 1);
errorDb = arrayfun(@(s) 10 * log10(mean( ...
    (estimate(s:s+block-1) - reference(s:s+block-1)).^2) + eps), starts);
late = starts >= round((transitionTime + 1.5) * fs);
target = median(errorDb(late));
stable = abs(errorDb - target) <= 1.5;
first = find(conv(double(stable), ones(1, 3), 'valid') >= 3, 1);
if isempty(first)
    seconds = NaN;
else
    seconds = (starts(first) - startSample) / fs;
end
end

function rows = local_recovery_rows(split, replicate, system, reference, ...
        estimate, fs, transitionTime)
rows = table;
blockDuration = 0.10;
relativeStarts = -0.5:blockDuration:2.4;
for relativeStart = relativeStarts
    first = round((transitionTime + relativeStart) * fs) + 1;
    last = first + round(blockDuration * fs) - 1;
    value = si_sdr(reference(first:last), estimate(first:last));
    rows = [rows; table(split, replicate, system, ...
        relativeStart + blockDuration / 2, value, 'VariableNames', ...
        {'split', 'replicate', 'system', 'relative_time_s', ...
        'local_si_sdr_db'})]; %#ok<AGROW>
end
end

function create_detector_figure(summary, cues, resultsRoot)
fig = figure('Color', 'w', 'Position', [100 100 980 520]);
tiledlayout(1, 2, 'TileSpacing', 'compact');
for s = 1:2
    nexttile;
    splitName = ["development", "held_out"];
    rows = summary(summary.split == splitName(s), :);
    yyaxis left;
    cueLabels = replace(cues, "_", " ");
    bar(categorical(rows.cue, cues, cueLabels), ...
        rows.mean_detected_within_1_5_s);
    ylim([0 1.05]); ylabel('Detection rate');
    yyaxis right;
    plot(categorical(rows.cue, cues, cueLabels), ...
        rows.mean_false_alarms_before_change, ...
        '-o', 'LineWidth', 1.5);
    ylabel('Mean false alarms');
    title(strrep(splitName(s), '_', ' ')); grid on;
end
exportgraphics(fig, fullfile(resultsRoot, 'detector_ablation.png'), ...
    'Resolution', 180);
close(fig);
end

function create_metric_figure(summary, modes, resultsRoot)
rows = summary(summary.split == "held_out", :);
conditions = unique(rows.condition, 'stable');
controllerModes = modes(2:end);
values = NaN(numel(conditions), numel(controllerModes));
for c = 1:numel(conditions)
    for m = 1:numel(controllerModes)
        match = rows.condition == conditions(c) & ...
            rows.system == controllerModes(m);
        values(c, m) = rows.mean_transition_si_sdr_db(match);
    end
end
fig = figure('Color', 'w', 'Position', [100 100 1050 560]);
conditionLabels = replace(conditions, "_", " ");
bar(categorical(conditions, conditions, conditionLabels), values);
ylabel('Mean transition SI-SDR (dB)');
title('Held-out performance in the first 0.75 s after each change');
legend(controllerModes, 'Location', 'southoutside', 'Orientation', 'horizontal');
grid on;
exportgraphics(fig, fullfile(resultsRoot, 'held_out_transition_metrics.png'), ...
    'Resolution', 180);
close(fig);
end

function create_recovery_figure(recovery, modes, resultsRoot)
rows = recovery(recovery.split == "held_out", :);
fig = figure('Color', 'w', 'Position', [100 100 840 560]); hold on;
for m = 1:numel(modes)
    systemRows = rows(rows.system == modes(m), :);
    times = unique(systemRows.relative_time_s);
    means = arrayfun(@(t) mean(systemRows.local_si_sdr_db( ...
        systemRows.relative_time_s == t), 'omitnan'), times);
    plot(times, means, 'LineWidth', 1.5, 'DisplayName', modes(m));
end
xline(0, '--k', 'True change', 'HandleVisibility', 'off');
xlabel('Time relative to transition (s)');
ylabel('Mean local SI-SDR (dB)');
title('Held-out recovery after office-to-traffic transitions');
legend('Location', 'southoutside', 'Orientation', 'horizontal'); grid on;
exportgraphics(fig, fullfile(resultsRoot, 'transition_recovery.png'), ...
    'Resolution', 180);
close(fig);
end

function create_tradeoff_figure(metrics, modes, resultsRoot)
rows = metrics(metrics.split == "held_out" & metrics.system ~= "noisy", :);
fig = figure('Color', 'w', 'Position', [100 100 760 560]); hold on;
for m = 2:numel(modes)
    match = rows.system == modes(m);
    scatter(mean(rows.transition_speech_error_db(match), 'omitnan'), ...
        mean(rows.transition_noise_suppression_db(match), 'omitnan'), ...
        90, 'filled', 'DisplayName', modes(m));
end
xlabel('Speech error (dB, lower is better)');
ylabel('Noise suppression (dB, higher is better)');
title('Held-out transition trade-off'); legend('Location', 'best'); grid on;
exportgraphics(fig, fullfile(resultsRoot, 'speech_noise_tradeoff.png'), ...
    'Resolution', 180);
close(fig);
end

function create_representative_figure(example, modes, transitionTime, cue, fs, resultsRoot)
n = numel(example.clean);
time = (0:n - 1)' / fs;
changeIndex = find(modes == "change", 1);
diag = example.diagnostics{changeIndex};
fig = figure('Color', 'w', 'Position', [100 100 1050 780]);
tiledlayout(3, 1, 'TileSpacing', 'compact');
nexttile;
plot(time, example.noisy, 'Color', [0.6 0.6 0.6]); hold on;
plot(time, example.clean, 'Color', [0.05 0.35 0.65]);
xline(transitionTime, '--r');
title('Held-out office-to-traffic transition'); ylabel('Amplitude');
legend('Noisy', 'Clean', 'Location', 'southoutside', 'Orientation', 'horizontal');
nexttile;
plot(diag.frameTimes, diag.changeScore, 'LineWidth', 1.2); hold on;
plot(diag.frameTimes, diag.changeThreshold, '--', 'LineWidth', 1.0);
scatter(diag.frameTimes(diag.triggers), diag.changeScore(diag.triggers), 24, 'filled');
xline(transitionTime, '--r');
title("Selected cue: " + cue); ylabel('Score');
legend('Score', 'Threshold', 'Triggers', 'True change', ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
nexttile;
plot(diag.frameTimes, diag.meanGain, 'LineWidth', 1.2); hold on;
plot(diag.frameTimes, diag.noiseAlpha, 'LineWidth', 1.0);
xline(transitionTime, '--r');
xlabel('Time (s)'); ylabel('Controller state');
title('Mean Wiener gain and noise-update coefficient');
legend('Mean gain', 'Noise alpha', 'True change', ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
exportgraphics(fig, fullfile(resultsRoot, 'held_out_controller_trace.png'), ...
    'Resolution', 180);
close(fig);
end
