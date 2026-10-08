%RUN_TRANSITION_DEMO Preliminary dynamic-scene Wiener comparison.
rng(5305);
fs = 16000;
duration = 6;
t = (0:1/fs:duration-1/fs)';
transitionTime = 3.0;

% A deterministic speech-like source keeps this demo dataset-independent.
f0 = 125 + 18 * sin(2*pi*0.55*t);
phase = 2*pi*cumsum(f0) / fs;
envelope = 0.25 + 0.75 * abs(sin(2*pi*2.2*t));
clean = envelope .* (sin(phase) + 0.45*sin(2*phase) + 0.20*sin(3*phase));
clean = 0.35 * clean / max(abs(clean));
clean(t < 0.30) = 0;
clean(t > 4.45 & t < 4.75) = 0;

fanNoise = filter(1, [1 -0.97], randn(size(t)));
trafficNoise = filter([1 -0.8], [1 -0.25], randn(size(t)));
trafficNoise = trafficNoise .* (0.65 + 0.35*sin(2*pi*1.4*t).^2);
[noisy, addedNoise, scene] = generate_dynamic_scene( ...
    clean, fanNoise, trafficNoise, fs, transitionTime, 0, 0);

[fixed, fixedDiag] = transition_wiener(noisy, fs, "fixed", transitionTime);
[snrAdaptive, snrDiag] = transition_wiener(noisy, fs, "snr", transitionTime);
[changeAware, changeDiag] = transition_wiener(noisy, fs, "change", transitionTime);
[oracle, oracleDiag] = transition_wiener(noisy, fs, "oracle", transitionTime);

names = ["Noisy"; "Fixed Wiener"; "SNR-adaptive"; "Change-aware"; "Oracle"];
signals = {noisy, fixed, snrAdaptive, changeAware, oracle};
wholeSnr = zeros(numel(signals), 1);
transitionSnr = zeros(numel(signals), 1);
wholeSiSdr = zeros(numel(signals), 1);
transitionSiSdr = zeros(numel(signals), 1);
transitionWindow = t >= transitionTime & t < transitionTime + 0.75;
for k = 1:numel(signals)
    estimate = signals{k}(1:numel(clean));
    wholeSnr(k) = signal_snr(clean, estimate);
    transitionSnr(k) = signal_snr(clean(transitionWindow), estimate(transitionWindow));
    wholeSiSdr(k) = si_sdr(clean, estimate);
    transitionSiSdr(k) = si_sdr(clean(transitionWindow), estimate(transitionWindow));
end

frameTolerance = median(diff(changeDiag.frameTimes));
detectedFrames = find(changeDiag.triggers & ...
    changeDiag.frameTimes >= transitionTime - frameTolerance, 1);
if isempty(detectedFrames)
    detectionLatencyMs = NaN;
else
    detectionLatencyMs = max(0, 1000 * ...
        (changeDiag.frameTimes(detectedFrames) - transitionTime));
end
falseAlarms = sum(changeDiag.triggers & ...
    changeDiag.frameTimes < transitionTime - frameTolerance);

repoRoot = fileparts(fileparts(mfilename('fullpath')));
resultDir = fullfile(repoRoot, 'results');
if ~isfolder(resultDir), mkdir(resultDir); end
metrics = table(names, wholeSnr, transitionSnr, wholeSiSdr, transitionSiSdr, ...
    'VariableNames', {'System', 'WholeSignalSnrDb', 'TransitionSnrDb', ...
    'WholeSignalSiSdrDb', 'TransitionSiSdrDb'});
writetable(metrics, fullfile(resultDir, 'preliminary_metrics.csv'));

summary = table(scene.transitionTime, scene.snrBefore, scene.snrAfter, ...
    detectionLatencyMs, falseAlarms, ...
    'VariableNames', {'TransitionTimeSeconds', 'SnrBeforeDb', 'SnrAfterDb', ...
    'DetectionLatencyMs', 'FalseAlarmsBeforeTransition'});
writetable(summary, fullfile(resultDir, 'change_detection_summary.csv'));

figure('Visible', 'off', 'Position', [100 100 1050 850]);
tiledlayout(3, 1, 'TileSpacing', 'compact');
nexttile;
plot(t, noisy, Color=[0.25 0.25 0.25]); hold on;
xline(transitionTime, '--r', 'True transition', LineWidth=1.2);
title('Synthetic dynamic scene: fan-like noise to traffic-like noise');
xlabel('Time (s)'); ylabel('Amplitude'); axis tight;

nexttile;
plot(changeDiag.frameTimes, changeDiag.changeScore, Color=[0.05 0.45 0.38]); hold on;
plot(changeDiag.frameTimes, changeDiag.changeThreshold, '--', Color=[0.2 0.2 0.2]);
xline(transitionTime, '--r', 'True transition', LineWidth=1.2);
triggerTimes = changeDiag.frameTimes(changeDiag.triggers);
scatter(triggerTimes, changeDiag.changeScore(changeDiag.triggers), 28, 'filled');
title(sprintf('Change score (latency %.1f ms, %d pre-transition false alarms)', ...
    detectionLatencyMs, falseAlarms));
xlabel('Time (s)'); ylabel('Score'); axis tight;
legend('Change score', 'Adaptive threshold', Location='best');

nexttile;
systems = categorical(names, names, 'Ordinal', true);
bar(systems, transitionSiSdr, FaceColor=[0.08 0.50 0.40]);
yline(0, ':');
title('Preliminary SI-SDR in the first 0.75 s after the transition');
ylabel('SI-SDR (dB)'); grid on;
exportgraphics(gcf, fullfile(resultDir, 'preliminary_transition_results.png'), Resolution=180);
close(gcf);

audioDir = fullfile(resultDir, 'audio');
if ~isfolder(audioDir), mkdir(audioDir); end
audiowrite(fullfile(audioDir, 'clean.wav'), clean, fs);
audiowrite(fullfile(audioDir, 'dynamic_noisy.wav'), normalise_audio(noisy), fs);
audiowrite(fullfile(audioDir, 'fixed_wiener.wav'), normalise_audio(fixed), fs);
audiowrite(fullfile(audioDir, 'change_aware_wiener.wav'), normalise_audio(changeAware), fs);
audiowrite(fullfile(audioDir, 'oracle_wiener.wav'), normalise_audio(oracle), fs);

disp(metrics);
disp(summary);

function value = signal_snr(reference, estimate)
reference = reference(:);
estimate = estimate(:);
n = min(numel(reference), numel(estimate));
value = 10 * log10(sum(reference(1:n).^2) / ...
    (sum((reference(1:n) - estimate(1:n)).^2) + eps));
end

function value = si_sdr(reference, estimate)
reference = reference(:);
estimate = estimate(:);
n = min(numel(reference), numel(estimate));
reference = reference(1:n);
estimate = estimate(1:n);
projection = (reference' * estimate) / (reference' * reference + eps) * reference;
residual = estimate - projection;
value = 10 * log10(sum(projection.^2) / (sum(residual.^2) + eps));
end

function output = normalise_audio(input)
output = input / max(1, 1.01 * max(abs(input)));
end
