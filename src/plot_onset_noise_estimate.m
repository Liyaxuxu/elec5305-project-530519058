function plot_onset_noise_estimate(split)
%PLOT_ONSET_NOISE_ESTIMATE Plot the noise estimate around a noise onset.
%   plot_onset_noise_estimate("unseen_test")
% Takes the first onset case and the frozen settings, and compares the true
% noise power with the fixed, always-fast and noise-floor guard estimates.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'results', 'controller_ablation');
selected = jsondecode(fileread(fullfile(out, 'frozen_controller.json')));
cases = build_detector_cases(root, split, -30);
current = cases(find(string({cases.condition}) == "onset", 1));
window = hamming(512, 'periodic');
[N, ~, t] = stft(current.noise, current.fs, Window=window, ...
    OverlapLength=384, FFTLength=512);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 420]);
plot(t, 10*log10(mean(abs(N).^2, 1) + eps), 'k', 'LineWidth', 1.0, ...
    'DisplayName', 'True added-noise power'); hold on;
runs = {"fixed", false, 'Fixed Wiener'; "always_fast", false, 'Always fast'; ...
    "fixed", true, 'Fixed + noise-floor guard (not used)'};
for k = 1:size(runs, 1)
    options = selected;
    options.noiseFloorGuard = runs{k, 2};
    options.causalStartup = true;
    [~, d] = transition_wiener(current.noisy, current.fs, runs{k, 1}, ...
        current.changeTime, "combined", options);
    plot(d.frameTimes, 10*log10(d.meanNoisePsd + eps), 'LineWidth', 1.4, ...
        'DisplayName', runs{k, 3});
end
xline(current.changeTime, '--r', 'Noise onset', 'HandleVisibility', 'off');
xlabel('Time (s)'); ylabel('Mean power (dB)'); grid on;
title("Noise onset from a -30 dB floor (" + current.id + ")", ...
    'Interpreter', 'none');
legend('Location', 'southoutside', 'Orientation', 'horizontal', ...
    'Interpreter', 'none');
exportgraphics(fig, fullfile(out, split + "_onset_noise_estimate.png"), ...
    Resolution=150);
close(fig);
end
