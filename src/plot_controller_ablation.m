function plot_controller_ablation(split)
%PLOT_CONTROLLER_ABLATION Make the ablation figures for one split.
%   plot_controller_ablation("validation")   (or "development", "unseen_test")
% Reads results/controller_ablation/<split>_*.csv and saves the recovery,
% settling time, trade-off, average-vs-transition and original-vs-selected
% plots in the same folder.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'results', 'controller_ablation');
metrics = readtable(fullfile(out, split + "_metrics.csv"), TextType='string');
recovery = readtable(fullfile(out, split + "_recovery.csv"), TextType='string');
% same rules as the summary tables: no clean_control, and transition
% metrics only for level/type/onset/offset
transitionSet = ["level", "type", "onset", "offset"];
metrics = metrics(metrics.condition ~= "clean_control", :);
recovery = recovery(ismember(recovery.condition, transitionSet), :);
main = ["fixed", "snr", "change_legacy", "snr_change_revised", ...
    "always_fast", "oracle"];
labels = ["Fixed", "SNR-only", "Change (original cue)", ...
    "SNR + change (new cue)", "Always fast", "Oracle"];
selected = metrics(metrics.config == "selected", :);

% recovery curve
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 520]);
hold on;
rows = recovery(recovery.config == "selected", :);
for j = 1:numel(main)
    r = rows(rows.system == main(j), :);
    times = unique(r.relative_time_s);
    values = arrayfun(@(x) mean(r.local_si_sdr_db(r.relative_time_s == x), ...
        'omitnan'), times);
    plot(times, values, 'LineWidth', 1.5, 'DisplayName', labels(j));
end
xline(0, '--k', 'Change', 'HandleVisibility', 'off');
xlabel('Time relative to the change (s)');
ylabel('Mean local SI-SDR, 100 ms blocks (dB)');
title("Recovery after the change (" + split + ")", 'Interpreter', 'none');
legend('Location', 'southoutside', 'NumColumns', 3); grid on;
save_figure(fig, out, split + "_recovery.png");

% settling time per condition
conditions = ["level", "type", "onset", "offset", "type_pause"];
values = NaN(numel(conditions), numel(main));
for i = 1:numel(conditions)
    for j = 1:numel(main)
        r = selected(selected.condition == conditions(i) & ...
            selected.system == main(j), :);
        values(i, j) = mean(r.settling_time_s, 'omitnan');
    end
end
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 950 480]);
bar(categorical(conditions, conditions, replace(conditions, "_", " ")), values);
ylabel('Mean settling time (s, lower is better)');
title("Settling time by type of change (" + split + ")", 'Interpreter', 'none');
legend(labels, 'Location', 'southoutside', 'NumColumns', 3); grid on;
save_figure(fig, out, split + "_settling_by_condition.png");

% speech error vs noise suppression
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 760 560]);
hold on;
for j = 1:numel(main)
    r = selected(selected.system == main(j) & ...
        ismember(selected.condition, transitionSet), :);
    scatter(mean(r.transition_speech_error_db, 'omitnan'), ...
        mean(r.transition_noise_suppression_db, 'omitnan'), 90, 'filled', ...
        'DisplayName', labels(j));
end
xlabel('Transition speech error (dB, lower is better)');
ylabel('Transition noise suppression (dB, higher is better)');
title("Speech distortion vs noise removal after the change (" + split + ")", ...
    'Interpreter', 'none');
legend('Location', 'best'); grid on;
save_figure(fig, out, split + "_tradeoff.png");

% whole-signal vs transition metrics
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 460]);
layout = tiledlayout(1, 2, 'TileSpacing', 'compact');
for panel = 1:2
    nexttile; hold on;
    for j = 1:numel(main)
        r = selected(selected.system == main(j), :);
        if panel == 1
            x = mean(r.stoi, 'omitnan'); xName = 'Whole-signal STOI';
        else
            x = mean(r.whole_si_sdr_db, 'omitnan'); xName = 'Whole-signal SI-SDR (dB)';
        end
        y = mean(r.transition_si_sdr_db(ismember(r.condition, transitionSet)), ...
            'omitnan');
        scatter(x, y, 80, 'filled', 'DisplayName', labels(j));
    end
    xlabel(xName); ylabel('Transition SI-SDR, first 0.75 s (dB)'); grid on;
end
legend('Location', 'southoutside', 'NumColumns', 3);
title(layout, "Average metrics vs transition metrics (" + split + ")", ...
    'Interpreter', 'none');
save_figure(fig, out, split + "_average_vs_transition.png");

% original vs selected setting
systems = ["change_legacy", "change_revised", "snr_change_legacy", ...
    "snr_change_revised", "always_fast", "oracle"];
whole = NaN(numel(systems), 2); local = NaN(numel(systems), 2);
configs = ["original", "selected"];
for j = 1:numel(systems)
    for k = 1:2
        r = metrics(metrics.system == systems(j) & metrics.config == configs(k), :);
        whole(j, k) = mean(r.whole_si_sdr_db, 'omitnan');
        local(j, k) = mean(r.transition_si_sdr_db( ...
            ismember(r.condition, transitionSet)), 'omitnan');
    end
end
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 460]);
layout = tiledlayout(1, 2, 'TileSpacing', 'compact');
names = categorical(systems, systems, replace(systems, "_", " "));
nexttile; bar(names, whole); ylabel('Whole-signal SI-SDR (dB)'); grid on;
nexttile; bar(names, local); ylabel('Transition SI-SDR (dB)'); grid on;
legend(configs, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(layout, "Original vs selected controller setting (" + split + ")", ...
    'Interpreter', 'none');
save_figure(fig, out, split + "_original_vs_selected.png");
end

function save_figure(fig, folder, name)
exportgraphics(fig, fullfile(folder, name), Resolution=150);
close(fig);
end
