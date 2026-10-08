%% Preliminary VoiceBank + DEMAND dynamic-scene experiment
% Runs three controlled transition types through the same Wiener pipeline.
clear; close all; clc;
rng(530519058);

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
dataRoot = fullfile(repoRoot, 'data', 'raw');
resultsRoot = fullfile(repoRoot, 'results');
audioRoot = fullfile(resultsRoot, 'audio', 'real_data');
if ~exist(audioRoot, 'dir'), mkdir(audioRoot); end

cleanPath = fullfile(dataRoot, 'clean_testset_wav', 'p232_003.wav');
officePath = fullfile(dataRoot, 'OOFFICE', 'ch01.wav');
trafficPath = fullfile(dataRoot, 'STRAFFIC', 'ch01.wav');
required = {cleanPath, officePath, trafficPath};
for k = 1:numel(required)
    assert(isfile(required{k}), 'Missing required dataset file: %s', required{k});
end

fs = 16000;
duration = 6.0;
transitionTime = 3.0;
n = round(duration * fs);
[cleanRaw, cleanFs] = audioread(cleanPath);
cleanRaw = mean(cleanRaw, 2);
cleanRaw = resample(cleanRaw, fs, cleanFs);
clean = fit_audio(cleanRaw, n);
clean = clean / (max(abs(clean)) + eps) * 0.75;

[office, officeFs] = audioread(officePath);
[traffic, trafficFs] = audioread(trafficPath);
office = resample(mean(office, 2), fs, officeFs);
traffic = resample(mean(traffic, 2), fs, trafficFs);
office = select_excerpt(office, n, 7 * fs);
traffic = select_excerpt(traffic, n, 11 * fs);

conditions = struct( ...
    'name', {"level_change", "noise_type_change", "noise_onset"}, ...
    'noiseA', {office, office, zeros(n, 1)}, ...
    'noiseB', {office, traffic, traffic}, ...
    'snrA', {10, 0, 0}, ...
    'snrB', {0, 0, 0});
modes = ["noisy", "fixed", "snr", "change", "oracle"];

metricRows = table;
detectionRows = table;
figureData = struct;
for c = 1:numel(conditions)
    condition = conditions(c);
    [noisy, addedNoise] = generate_dynamic_scene(clean, condition.noiseA, ...
        condition.noiseB, fs, transitionTime, condition.snrA, condition.snrB);

    outputs = cell(size(modes));
    diagnostics = cell(size(modes));
    outputs{1} = noisy;
    runtimes = zeros(size(modes));
    for m = 2:numel(modes)
        started = tic;
        [outputs{m}, diagnostics{m}] = transition_wiener( ...
            noisy, fs, modes(m), transitionTime);
        runtimes(m) = toc(started);
    end

    transitionRegion = max(1, round(transitionTime * fs) + 1): ...
        min(n, round((transitionTime + 0.75) * fs));
    for m = 1:numel(modes)
        output = outputs{m}(1:n);
        wholeSiSdr = si_sdr(clean, output);
        transitionSiSdr = si_sdr(clean(transitionRegion), output(transitionRegion));
        outputSnr = 10 * log10(sum(clean.^2) / (sum((output - clean).^2) + eps));
        settle = settling_time(clean, output, fs, transitionTime);
        row = table(string(condition.name), modes(m), wholeSiSdr, ...
            transitionSiSdr, outputSnr, settle, runtimes(m), ...
            'VariableNames', {'condition', 'system', 'whole_si_sdr_db', ...
            'transition_si_sdr_db', 'output_snr_db', 'settling_time_s', ...
            'runtime_s'});
        metricRows = [metricRows; row]; %#ok<AGROW>
    end

    changeDiag = diagnostics{modes == "change"};
    triggerTimes = changeDiag.frameTimes(changeDiag.triggers);
    validTrigger = triggerTimes(triggerTimes >= transitionTime);
    if isempty(validTrigger)
        latency = NaN;
    else
        latency = validTrigger(1) - transitionTime;
    end
    falseAlarms = sum(triggerTimes < transitionTime);
    detectionRows = [detectionRows; table(string(condition.name), ...
        latency, falseAlarms, numel(triggerTimes), ...
        'VariableNames', {'condition', 'detection_latency_s', ...
        'false_alarms_before_change', 'total_triggers'})]; %#ok<AGROW>

    if condition.name == "noise_type_change"
        figureData.clean = clean;
        figureData.noisy = noisy;
        figureData.addedNoise = addedNoise;
        figureData.outputs = outputs;
        figureData.diagnostics = changeDiag;
        figureData.modes = modes;
        for m = 1:numel(modes)
            audiowrite(fullfile(audioRoot, modes(m) + ".wav"), ...
                outputs{m}(1:n), fs);
        end
        audiowrite(fullfile(audioRoot, 'clean.wav'), clean, fs);
    end
end

writetable(metricRows, fullfile(resultsRoot, 'real_data_metrics.csv'));
writetable(detectionRows, fullfile(resultsRoot, 'real_data_detection_summary.csv'));

time = (0:n-1)' / fs;
fig = figure('Color', 'w', 'Position', [100 100 1050 760]);
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(time, figureData.noisy, 'Color', [0.55 0.55 0.55]); hold on;
plot(time, figureData.clean, 'Color', [0.05 0.35 0.65]);
xline(transitionTime, '--r', 'Office to traffic');
xlabel('Time (s)'); ylabel('Amplitude');
title('Real VoiceBank speech with a controlled DEMAND noise transition');
legend('Noisy', 'Clean', 'Location', 'southoutside', 'Orientation', 'horizontal');

nexttile;
diag = figureData.diagnostics;
plot(diag.frameTimes, diag.changeScore, 'LineWidth', 1.2); hold on;
plot(diag.frameTimes, diag.changeThreshold, '--', 'LineWidth', 1.0);
triggerTimes = diag.frameTimes(diag.triggers);
if ~isempty(triggerTimes)
    scatter(triggerTimes, diag.changeScore(diag.triggers), 28, 'filled');
end
xline(transitionTime, '--r');
xlabel('Time (s)'); ylabel('Change score');
title('Detector output (reported separately from enhancement quality)');
legend('Score', 'Adaptive threshold', 'Triggers', 'True change', ...
    'Location', 'southoutside', 'Orientation', 'horizontal');

nexttile;
typeRows = metricRows(metricRows.condition == "noise_type_change", :);
bar(categorical(typeRows.system, figureData.modes), typeRows.transition_si_sdr_db);
ylabel('SI-SDR (dB)');
title('First 0.75 s after the transition');
grid on;
exportgraphics(fig, fullfile(resultsRoot, 'real_data_transition_results.png'), ...
    'Resolution', 180);
close(fig);

disp(metricRows);
disp(detectionRows);

function output = fit_audio(input, n)
input = input(:);
if numel(input) < n
    input = repmat(input, ceil(n / numel(input)), 1);
end
output = input(1:n);
end

function output = select_excerpt(input, n, startSample)
input = input(:);
startSample = min(max(startSample, 1), max(1, numel(input) - n + 1));
output = fit_audio(input(startSample:end), n);
output = output - mean(output);
end

function value = si_sdr(reference, estimate)
reference = reference(:) - mean(reference);
estimate = estimate(:) - mean(estimate);
scale = (reference' * estimate) / (reference' * reference + eps);
target = scale * reference;
value = 10 * log10(sum(target.^2) / (sum((estimate - target).^2) + eps));
end

function seconds = settling_time(reference, estimate, fs, transitionTime)
% First three 100 ms blocks whose local SI-SDR stays near the final second.
block = round(0.10 * fs);
startSample = round(transitionTime * fs) + 1;
starts = startSample:block:(numel(reference) - block + 1);
values = arrayfun(@(s) si_sdr(reference(s:s+block-1), ...
    estimate(s:s+block-1)), starts);
tailCount = min(10, numel(values));
target = median(values(end-tailCount+1:end));
stable = abs(values - target) <= 1.5;
first = find(conv(double(stable), ones(1, 3), 'valid') >= 3, 1);
if isempty(first)
    seconds = NaN;
else
    seconds = (starts(first) - startSample) / fs;
end
end
