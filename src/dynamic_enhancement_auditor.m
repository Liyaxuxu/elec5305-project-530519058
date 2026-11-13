function report = dynamic_enhancement_auditor(clean, noiseA, noiseB, fs, ...
    changeTime, snrBefore, snrAfter, outDir, options)
%DYNAMIC_ENHANCEMENT_AUDITOR Run all systems on one noise change and save plots.
%   report = dynamic_enhancement_auditor(clean, noiseA, noiseB, fs, ...
%       changeTime, snrBefore, snrAfter, outDir, options)
% Mixes noiseA -> noiseB at changeTime, runs the controllers and reference
% systems, and saves metrics.csv, detection.csv, three figures and the audio
% in outDir.
% options (all optional): systems, controller (settings for
% transition_wiener), detectorConfig ([] = original detector), references
% (true/false), extraOutputs (struct with name/signal, e.g. DeepFilterNet3
% output for the same mixture), name (figure title).
if nargin < 8 || isempty(outDir), outDir = fullfile(pwd, 'auditor_output'); end
if nargin < 9, options = struct; end
if ~isfield(options, 'systems')
    options.systems = ["fixed", "snr", "change", "snr_change", ...
        "always_fast", "oracle"];
end
if ~isfield(options, 'controller'), options.controller = struct; end
if ~isfield(options, 'detectorConfig'), options.detectorConfig = []; end
if ~isfield(options, 'references'), options.references = true; end
if ~isfield(options, 'extraOutputs'), options.extraOutputs = struct([]); end
if ~isfield(options, 'name'), options.name = "Dynamic scene"; end
if ~isfolder(fullfile(outDir, 'audio')), mkdir(fullfile(outDir, 'audio')); end

[noisy, addedNoise] = generate_dynamic_scene(clean, noiseA, noiseB, fs, ...
    changeTime, snrBefore, snrAfter);
clean = clean(:); n = numel(clean);
window = hamming(512, 'periodic');
[S, f, t] = stft(noisy, fs, Window=window, OverlapLength=384, FFTLength=512);
if isempty(options.detectorConfig)
    detector = scene_change_detector(S, t, "combined");
    detectorName = "original combined cue";
else
    detector = trigger_change_features(robust_change_features(S, t), ...
        options.detectorConfig);
    detectorName = "revised noise-floor cue";
end
alarmTimes = detector.frameTimes(detector.triggers) + 0.016;
detection = score_change_events(alarmTimes, changeTime, n/fs, 0.5);
detectedTime = NaN;
if detection.hit, detectedTime = changeTime + detection.latency; end
detectionTable = table(changeTime, numel(alarmTimes), detection.hit, ...
    detection.latency, detection.falseCount, detectorName, 'VariableNames', ...
    {'change_time_s', 'n_alarms', 'detected_within_1_5_s', 'latency_s', ...
    'false_alarms', 'detector'});
writetable(detectionTable, fullfile(outDir, 'detection.csv'));

% run the Wiener controllers
systems = ["noisy", string(options.systems)];
outputs = cell(size(systems)); diagnostics = cell(size(systems));
runtimes = zeros(size(systems));
for j = 1:numel(systems)
    started = tic;
    if systems(j) == "noisy"
        outputs{j} = noisy;
    else
        controller = options.controller;
        controller.detector = detector;
        controller.saveNoisePsd = true;
        [outputs{j}, diagnostics{j}] = transition_wiener(noisy, fs, ...
            systems(j), changeTime, "combined", controller);
    end
    runtimes(j) = toc(started);
end
nWiener = numel(systems);

% reference systems
if options.references
    started = tic;
    outputs{end+1} = spectral_subtraction(noisy, fs);
    runtimes(end+1) = toc(started); systems(end+1) = "spectral_subtraction";
    if exist('specsub', 'file') == 2
        started = tic;
        outputs{end+1} = specsub(noisy, fs, struct('g', 2, 'e', 2, 'am', 1, ...
            'ne', 1, 'ti', 0.008, 'of', 4, 'b', 0.05^2));
        runtimes(end+1) = toc(started); systems(end+1) = "ref_voicebox_mmse";
    end
end
for k = 1:numel(options.extraOutputs)
    outputs{end+1} = options.extraOutputs(k).signal; %#ok<AGROW>
    runtimes(end+1) = NaN; systems(end+1) = string(options.extraOutputs(k).name); %#ok<AGROW>
end
diagnostics(end+1:numel(systems)) = {[]};

rows = table;
for j = 1:numel(systems)
    y = real(outputs{j}(:)); y = [y(1:min(end, n)); zeros(max(0, n-numel(y)), 1)];
    outputs{j} = y;
    gain = [];
    if ~isempty(diagnostics{j}), gain = diagnostics{j}.gainMatrix; end
    m = transition_metrics(clean, addedNoise, y, fs, changeTime, gain);
    rows = [rows; [table(systems(j), runtimes(j), 'VariableNames', ...
        {'system', 'runtime_s'}), struct2table(m)]]; %#ok<AGROW>
    audiowrite(fullfile(outDir, 'audio', systems(j) + ".wav"), normalise(y), fs);
end
audiowrite(fullfile(outDir, 'audio', "clean.wav"), normalise(clean), fs);
writetable(rows, fullfile(outDir, 'metrics.csv'));

% Figure 1: what happens inside the controller
positive = f >= 0;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 950]);
tiledlayout(4, 1, 'TileSpacing', 'compact');
nexttile;
imagesc(t, f(positive)/1000, 10*log10(abs(S(positive, :)).^2 + eps));
axis xy; ylabel('Frequency (kHz)'); colormap(gca, 'turbo');
hold on; xline(changeTime, '--w', 'True change', 'LineWidth', 1.5);
if isfinite(detectedTime)
    xline(detectedTime, '-g', 'Detected', 'LineWidth', 1.5);
end
title(options.name + ": noisy spectrogram", 'Interpreter', 'none');
nexttile;
plot(detector.frameTimes, detector.score, 'LineWidth', 1.0); hold on;
plot(detector.frameTimes, detector.threshold, '--', 'LineWidth', 1.0);
scatter(detector.frameTimes(detector.triggers), ...
    detector.score(detector.triggers), 30, 'filled');
xline(changeTime, '--r', 'HandleVisibility', 'off');
if isfinite(detectedTime)
    xline(detectedTime, '-g', 'HandleVisibility', 'off', 'LineWidth', 1.5);
    detectionText = sprintf('detected after %.0f ms', 1000*detection.latency);
else
    detectionText = 'not detected within 1.5 s';
end
title(sprintf('Change score (%s): %s, %d false alarm(s)', detectorName, ...
    detectionText, detection.falseCount));
ylabel('Change score'); grid on;
legend('Score', 'Threshold', 'Triggers', 'Location', 'eastoutside');
nexttile; hold on;
[N, ~, ~] = stft(addedNoise, fs, Window=window, OverlapLength=384, FFTLength=512);
plot(t, 10*log10(mean(abs(N).^2, 1) + eps), 'k', 'DisplayName', 'True noise');
for j = 2:nWiener
    plot(diagnostics{j}.frameTimes, 10*log10(diagnostics{j}.meanNoisePsd + eps), ...
        'DisplayName', replace(systems(j), "_", " "), 'LineWidth', 1.0);
end
xline(changeTime, '--r', 'HandleVisibility', 'off');
ylabel('Noise estimate (dB)'); grid on; legend('Location', 'eastoutside');
nexttile; hold on;
for j = 2:nWiener
    plot(diagnostics{j}.frameTimes, diagnostics{j}.meanGain, ...
        'DisplayName', replace(systems(j), "_", " "), 'LineWidth', 1.0);
end
xline(changeTime, '--r', 'HandleVisibility', 'off');
xlabel('Time (s)'); ylabel('Mean Wiener gain'); grid on;
legend('Location', 'eastoutside');
exportgraphics(fig, fullfile(outDir, 'auditor_overview.png'), Resolution=150);
close(fig);

% spectrograms
show = ["noisy", "fixed", "change", "always_fast", "oracle", ...
    "spectral_subtraction", "ref_voicebox_mmse", "ref_deepfilternet3"];
show = show(ismember(show, systems));
signals = [{clean}, outputs(arrayfun(@(s) find(systems == s, 1), show))];
labels = ["clean", show];
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100 100 1100 180*ceil(numel(labels)/2) + 80]);
tiledlayout(ceil(numel(labels)/2), 2, 'TileSpacing', 'compact');
limits = [];
for j = 1:numel(labels)
    nexttile;
    [Y, ~, ty] = stft(signals{j}, fs, Window=window, OverlapLength=384, ...
        FFTLength=512);
    power = 10*log10(abs(Y(positive, :)).^2 + eps);
    if isempty(limits), limits = max(power(:)) + [-80 0]; end
    imagesc(ty, f(positive)/1000, power, limits); axis xy;
    colormap(gca, 'turbo'); hold on;
    xline(changeTime, '--w', 'LineWidth', 1.2);
    title(replace(labels(j), "_", " ")); ylabel('kHz');
end
xlabel('Time (s)');
exportgraphics(fig, fullfile(outDir, 'auditor_spectrograms.png'), Resolution=150);
close(fig);

% local SI-SDR around the change
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 450]);
hold on;
for j = 1:numel(systems)
    times = []; values = [];
    for start = -0.5:0.1:2.4
        first = round((changeTime + start)*fs) + 1;
        last = first + round(0.1*fs) - 1;
        if first < 1 || last > n, continue; end
        times(end+1) = start + 0.05; %#ok<AGROW>
        values(end+1) = local_sisdr(clean(first:last), outputs{j}(first:last)); %#ok<AGROW>
    end
    plot(times, values, 'LineWidth', 1.3, 'DisplayName', replace(systems(j), "_", " "));
end
xline(0, '--k', 'Change', 'HandleVisibility', 'off');
xlabel('Time relative to the change (s)'); ylabel('Local SI-SDR (dB)');
legend('Location', 'eastoutside'); grid on;
title(options.name + ": recovery after the change", 'Interpreter', 'none');
exportgraphics(fig, fullfile(outDir, 'auditor_recovery.png'), Resolution=150);
close(fig);

report = struct('metrics', rows, 'detection', detectionTable, ...
    'noisy', noisy, 'outputs', {outputs}, 'systems', systems, ...
    'outDir', string(outDir));
disp(detectionTable); disp(rows);
end

function y = normalise(x)
y = real(x(:)) / max(1, 1.01*max(abs(x(:))));
end

function value = local_sisdr(reference, estimate)
reference = reference - mean(reference); estimate = estimate - mean(estimate);
target = reference*(reference'*estimate)/(reference'*reference + eps);
value = 10*log10((sum(target.^2) + eps)/(sum((estimate - target).^2) + eps));
end
