function summarise_controller_ablation(splits)
%SUMMARISE_CONTROLLER_ABLATION Final tables and statistics for the report.
%   summarise_controller_ablation             % validation and unseen_test
% For each split it saves the final table, paired bootstrap differences,
% the per-condition hypothesis test, the whole-vs-transition ranking, the
% fast-fraction correlation and the reference-system figure.
% Rules: clean_control is left out (Wiener output = input there, so SI-SDR
% is undefined); transition metrics only use level/type/onset/offset
% (type_pause has silent speech at the change); intervals come from a
% bootstrap over the six speech sequences (5000 resamples).
if nargin < 1, splits = ["validation", "unseen_test"]; end
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'results', 'controller_ablation');
transitionSet = ["level", "type", "onset", "offset"];
for split = string(splits)
    metrics = readtable(fullfile(out, split + "_metrics.csv"), TextType='string');
    metrics = metrics(metrics.config == "selected" & ...
        metrics.condition ~= "clean_control", :);
    metrics = add_dfn_runtime(metrics, fullfile(root, 'data', 'dfn_io', split), ...
        fullfile(out, split + "_dfn_runtime.csv"));
    systems = intersect(["noisy", "spectral_subtraction", "fixed", "snr", ...
        "change_legacy", "change_revised", "snr_change_legacy", ...
        "snr_change_revised", "always_fast", "oracle", "ref_voicebox_mmse", ...
        "ref_deepfilternet3"], unique(metrics.system), 'stable');
    systems = systems(:)';
    allSet = unique(metrics.condition)';

    % 1. final table (SNR improvement is paired with the noisy input)
    final = table;
    noisyRows = metrics(metrics.system == "noisy", {'case_id', 'seg_snr_db'});
    noisyRows.Properties.VariableNames{2} = 'noisy_seg_snr_db';
    for s = systems
        r = metrics(metrics.system == s, :);
        t = r(ismember(r.condition, transitionSet), :);
        matched = innerjoin(r(:, {'case_id', 'seg_snr_db'}), noisyRows, ...
            'Keys', 'case_id');
        final = [final; table(s, mean(r.whole_si_sdr_db, 'omitnan'), ...
            mean(r.seg_snr_db, 'omitnan'), ...
            mean(matched.seg_snr_db - matched.noisy_seg_snr_db, 'omitnan'), ...
            mean(r.stoi, 'omitnan'), ...
            mean(t.transition_si_sdr_db, 'omitnan'), ...
            mean(t.steady_si_sdr_db, 'omitnan'), ...
            mean(t.settling_time_s, 'omitnan'), ...
            mean(t.transition_speech_error_db, 'omitnan'), ...
            mean(t.transition_noise_suppression_db, 'omitnan'), ...
            mean(r.fast_state_fraction, 'omitnan'), mean(r.runtime_s, 'omitnan'), ...
            'VariableNames', {'system', 'whole_si_sdr_db', 'seg_snr_db', ...
            'seg_snr_improvement_db', 'stoi', 'transition_si_sdr_db', 'steady_si_sdr_db', ...
            'settling_time_s', 'transition_speech_error_db', ...
            'transition_noise_suppression_db', 'fast_state_fraction', ...
            'runtime_s'})]; %#ok<AGROW>
    end
    writetable(final, fullfile(out, split + "_final_table.csv"));
    fprintf('\n=== %s: final table (clean_control excluded) ===\n', split);
    disp(final);

    % 2. paired differences
    contrasts = {
        'whole_si_sdr_db', "always_fast", "fixed", allSet
        'whole_si_sdr_db', "change_legacy", "fixed", allSet
        'whole_si_sdr_db', "change_revised", "fixed", allSet
        'whole_si_sdr_db', "snr", "fixed", allSet
        'whole_si_sdr_db', "oracle", "fixed", allSet
        'whole_si_sdr_db', "always_fast", "change_legacy", allSet
        'whole_si_sdr_db', "change_legacy", "oracle", allSet
        'whole_si_sdr_db', "fixed", "spectral_subtraction", allSet
        'whole_si_sdr_db', "ref_voicebox_mmse", "always_fast", allSet
        'whole_si_sdr_db', "ref_deepfilternet3", "always_fast", allSet
        'seg_snr_db', "always_fast", "fixed", allSet
        'transition_si_sdr_db', "oracle", "fixed", transitionSet
        'transition_si_sdr_db', "oracle", "change_legacy", transitionSet
        'transition_si_sdr_db', "oracle", "change_revised", transitionSet
        'transition_si_sdr_db', "always_fast", "fixed", transitionSet
        'transition_si_sdr_db', "oracle", "always_fast", transitionSet
        'transition_si_sdr_db', "ref_deepfilternet3", "always_fast", transitionSet
        'stoi', "fixed", "noisy", allSet
        'stoi', "always_fast", "noisy", allSet
        'stoi', "ref_voicebox_mmse", "noisy", allSet
        'stoi', "ref_deepfilternet3", "noisy", allSet};
    paired = table;
    for k = 1:size(contrasts, 1)
        [metric, a, b, conditions] = contrasts{k, :};
        if ~all(ismember([a, b], systems)), continue; end
        if all(isnan(metrics.(metric))), continue; end  % skip metrics with no values
        paired = [paired; contrast_row(metrics, metric, a, b, conditions, ...
            strjoin(conditions, "+"))]; %#ok<AGROW>
    end
    writetable(paired, fullfile(out, split + "_paired_bootstrap.csv"));
    fprintf('=== %s: paired differences (A - B) ===\n', split);
    disp(paired);

    % 3. hypothesis: does the change cue help more for type than for level
    %    changes (compared with SNR-only)?
    hypothesis = table;
    for condition = transitionSet
        for pair = {["change_legacy", "snr"], ["change_revised", "snr"], ...
                ["snr_change_revised", "snr"], ["oracle", "snr"], ["snr", "fixed"]}
            ab = pair{1};
            for metric = ["transition_si_sdr_db", "settling_time_s"]
                hypothesis = [hypothesis; contrast_row(metrics, char(metric), ...
                    ab(1), ab(2), condition, condition)]; %#ok<AGROW>
            end
        end
    end
    % difference-in-differences: (A-B for type/onset/offset) - (A-B for level)
    for condition = ["type", "onset", "offset"]
        for pair = {["change_legacy", "snr"], ["change_revised", "snr"], ...
                ["snr_change_revised", "snr"], ["oracle", "snr"]}
            ab = pair{1};
            for metric = ["transition_si_sdr_db", "settling_time_s"]
                hypothesis = [hypothesis; condition_interaction_row(metrics, ...
                    char(metric), ab(1), ab(2), condition, "level")]; %#ok<AGROW>
            end
        end
    end
    writetable(hypothesis, fullfile(out, split + "_hypothesis_by_condition.csv"));

    % 4. ranking: whole signal vs transition
    ranked = final(~ismember(final.system, "noisy"), :);
    ranked.rank_whole = rank_of(-ranked.whole_si_sdr_db);
    ranked.rank_transition = rank_of(-ranked.transition_si_sdr_db);
    ranked.rank_stoi = rank_of(-ranked.stoi);
    ranked = ranked(:, {'system', 'whole_si_sdr_db', 'rank_whole', ...
        'transition_si_sdr_db', 'rank_transition', 'stoi', 'rank_stoi'});
    writetable(sortrows(ranked, 'rank_whole'), ...
        fullfile(out, split + "_ranking_whole_vs_transition.csv"));
    rho = corrcoef(ranked.rank_whole, ranked.rank_transition);
    fprintf('Spearman rank correlation, whole vs transition SI-SDR: %.2f\n', rho(1, 2));

    % 5. fast-state fraction vs whole SI-SDR (Wiener controllers)
    wiener = final(isfinite(final.fast_state_fraction), :);
    r = corrcoef(wiener.fast_state_fraction, wiener.whole_si_sdr_db);
    writetable(table(split, height(wiener), r(1, 2), rho(1, 2), 'VariableNames', ...
        {'split', 'n_wiener_systems', 'pearson_fast_fraction_vs_whole_si_sdr', ...
        'spearman_rank_whole_vs_transition'}), ...
        fullfile(out, split + "_fast_fraction_correlation.csv"));

    % 6. figure with the reference systems
    plot_references(metrics, systems, out, split, ...
        readtable(fullfile(out, split + "_recovery.csv"), TextType='string'));
end
end

function row = contrast_row(metrics, metric, a, b, conditions, label)
A = metrics(metrics.system == a & ismember(metrics.condition, conditions), ...
    {'case_id', 'replicate', metric});
B = metrics(metrics.system == b & ismember(metrics.condition, conditions), ...
    {'case_id', metric});
B.Properties.VariableNames{2} = 'other';
J = innerjoin(A, B, 'Keys', 'case_id');
J.difference = J.(metric) - J.other;
J = J(isfinite(J.difference), :);
replicates = unique(J.replicate);
perSequence = arrayfun(@(x) mean(J.difference(J.replicate == x)), replicates);
low = NaN; high = NaN;
if numel(perSequence) >= 2
    rng(19058);
    draws = randi(numel(perSequence), numel(perSequence), 5000);
    boot = mean(perSequence(draws), 1);
    limits = prctile(boot, [2.5, 97.5]); low = limits(1); high = limits(2);
end
row = table(string(metric), a, b, string(label), height(J), ...
    mean(J.difference), low, high, low > 0 || high < 0, 'VariableNames', ...
    {'metric', 'system_a', 'system_b', 'conditions', 'n_cases', ...
    'mean_a_minus_b', 'ci95_low', 'ci95_high', 'ci_excludes_zero'});
end

function row = condition_interaction_row(metrics, metric, a, b, target, baseline)
% difference-in-differences per speech sequence:
% (A-B in target condition) - (A-B in baseline condition)
replicates = unique(metrics.replicate);
difference = NaN(numel(replicates), 1);
for k = 1:numel(replicates)
    rep = replicates(k);
    values = NaN(2, 2);
    conditions = [target, baseline];
    systems = [a, b];
    for c = 1:2
        for s = 1:2
            r = metrics(metrics.replicate == rep & ...
                metrics.condition == conditions(c) & metrics.system == systems(s), :);
            if height(r) == 1, values(c, s) = r.(metric); end
        end
    end
    if all(isfinite(values), 'all')
        difference(k) = (values(1, 1) - values(1, 2)) - ...
            (values(2, 1) - values(2, 2));
    end
end
difference = difference(isfinite(difference));
low = NaN; high = NaN;
if numel(difference) >= 2
    rng(19058);
    draws = randi(numel(difference), numel(difference), 5000);
    boot = mean(difference(draws), 1);
    limits = prctile(boot, [2.5, 97.5]); low = limits(1); high = limits(2);
end
label = target + "_minus_" + baseline;
row = table(string(metric), a, b, label, numel(difference), ...
    mean(difference, 'omitnan'), low, high, low > 0 || high < 0, ...
    'VariableNames', {'metric', 'system_a', 'system_b', 'conditions', ...
    'n_cases', 'mean_a_minus_b', 'ci95_low', 'ci95_high', ...
    'ci_excludes_zero'});
end

function ranks = rank_of(values)
[~, order] = sort(values);
ranks = zeros(size(values));
ranks(order) = 1:numel(values);
end

function metrics = add_dfn_runtime(metrics, folder, savedCopy)
% use the DeepFilterNet3 runtime saved by the python script
% (the MATLAB timing only covers reading the file). If data/dfn_io is not
% there, use the copy saved in results/controller_ablation.
file = fullfile(folder, 'runtime.csv');
if ~isfile(file), file = savedCopy; end
if ~isfile(file) || ~any(metrics.system == "ref_deepfilternet3"), return; end
runtime = readtable(file, TextType='string');
for k = find(metrics.system == "ref_deepfilternet3")'
    match = runtime.case_id == metrics.case_id(k);
    if any(match), metrics.runtime_s(k) = runtime.runtime_s(match); end
end
end

function plot_references(metrics, systems, out, split, recovery)
show = intersect(["fixed", "always_fast", "oracle", "spectral_subtraction", ...
    "ref_voicebox_mmse", "ref_deepfilternet3"], systems, 'stable');
show = show(:)';
recovery = recovery(recovery.config == "selected" & ...
    ismember(recovery.condition, ["level", "type", "onset", "offset"]), :);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1150 450]);
layout = tiledlayout(1, 2, 'TileSpacing', 'compact');
nexttile; hold on;
for s = show
    r = recovery(recovery.system == s, :);
    times = unique(r.relative_time_s);
    plot(times, arrayfun(@(x) mean(r.local_si_sdr_db(r.relative_time_s == x), ...
        'omitnan'), times), 'LineWidth', 1.4, 'DisplayName', replace(s, "_", " "));
end
xline(0, '--k', 'HandleVisibility', 'off');
xlabel('Time relative to the change (s)'); ylabel('Mean local SI-SDR (dB)');
grid on; legend('Location', 'southoutside', 'NumColumns', 3);
nexttile; hold on;
for s = show
    r = metrics(metrics.system == s, :);
    scatter(mean(r.runtime_s, 'omitnan')/8, mean(r.whole_si_sdr_db, 'omitnan'), ...
        80, 'filled', 'DisplayName', replace(s, "_", " "));
end
set(gca, 'XScale', 'log', 'XLim', [0.004, 0.06], ...
    'XTick', [0.005, 0.01, 0.02, 0.04]);
xlabel('Real-time factor (processing time / 8 s signal, log scale)');
ylabel('Whole-signal SI-SDR (dB)'); grid on;
title(layout, "Classical controllers vs reference systems (" + split + ")", ...
    'Interpreter', 'none');
exportgraphics(fig, fullfile(out, split + "_modern_reference.png"), Resolution=150);
close(fig);
end
