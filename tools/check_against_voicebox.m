%CHECK_AGAINST_VOICEBOX Check my fixed Wiener filter on stationary noise.
% Compares it with: the same gain rule using the true noise PSD, and
% VOICEBOX specsub in Wiener mode with minimum statistics (Martin 2001) and
% with the MMSE tracker (Gerkmann & Hendriks 2012).
% Uses the 12 stationary development cases (office and traffic, p232).
% VOICEBOX is GPL, so it is not in the repo: download it from
% http://www.ee.ic.ac.uk/hp/staff/dmb/voicebox/voicebox.html and copy the
% needed files into tools/external/voicebox.
% Output goes to results/reference_check/.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'tools', 'external', 'voicebox'));
assert(exist('specsub', 'file') == 2, ...
    'VOICEBOX specsub.m not found in tools/external/voicebox.');
out = fullfile(root, 'results', 'reference_check');
if ~isfolder(out), mkdir(out); end

cases = build_detector_cases(root, "development");
cases = cases(startsWith(string({cases.condition}), "stationary_"));
systems = ["noisy", "fixed_wiener", "fixed_wiener_guard", ...
    "oracle_psd_wiener", "voicebox_minstat_wiener", "voicebox_mmse_wiener"];
window = hamming(512, 'periodic');
rows = table;
for c = 1:numel(cases)
    current = cases(c); fs = current.fs; n = numel(current.clean);
    for system = systems
        started = tic;
        switch system
            case "noisy"
                y = current.noisy;
            case "fixed_wiener"
                y = transition_wiener(current.noisy, fs, "fixed", NaN, ...
                    "combined", struct('causalStartup', true));
            case "fixed_wiener_guard"
                y = transition_wiener(current.noisy, fs, "fixed", NaN, ...
                    "combined", struct('causalStartup', true, ...
                    'noiseFloorGuard', true));
            case "oracle_psd_wiener"
                [X, ~, ~] = stft(current.noisy, fs, Window=window, ...
                    OverlapLength=384, FFTLength=512);
                [N, ~, ~] = stft(current.noise, fs, Window=window, ...
                    OverlapLength=384, FFTLength=512);
                noisePsd = mean(abs(N).^2, 2) + eps;   % stationary noise
                prior = max(abs(X).^2 ./ noisePsd - 1, 0);
                G = max(prior ./ (1 + prior), 0.05);  % same gain rule, no smoothing
                y = istft(G .* X, fs, Window=window, OverlapLength=384, ...
                    FFTLength=512);
            case "voicebox_minstat_wiener"
                y = specsub(current.noisy, fs, struct('g', 2, 'e', 2, ...
                    'am', 1, 'ne', 0, 'ti', 0.008, 'of', 4, 'b', 0.05^2));
            case "voicebox_mmse_wiener"
                y = specsub(current.noisy, fs, struct('g', 2, 'e', 2, ...
                    'am', 1, 'ne', 1, 'ti', 0.008, 'of', 4, 'b', 0.05^2));
        end
        runtime = toc(started);
        y = real(y(:)); y = [y(1:min(end, n)); zeros(max(0, n-numel(y)), 1)];
        % skip the 0.5 s noise-only start when scoring
        keep = round(0.5*fs)+1:n;
        m = transition_metrics(current.clean(keep), current.noise(keep), ...
            y(keep), fs, NaN);
        rows = [rows; table(string(current.id), string(current.condition), ...
            system, m.whole_si_sdr_db, m.stoi, runtime, 'VariableNames', ...
            {'case_id', 'condition', 'system', 'si_sdr_db', 'stoi', ...
            'runtime_s'})]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(out, 'reference_check.csv'));
summary = groupsummary(rows, {'condition', 'system'}, 'mean', ...
    {'si_sdr_db', 'stoi', 'runtime_s'});
writetable(summary, fullfile(out, 'reference_check_summary.csv'));
disp(summary);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 430]);
layout = tiledlayout(1, 2, 'TileSpacing', 'compact');
conditions = unique(rows.condition);
for panel = 1:2
    nexttile;
    values = NaN(numel(systems), numel(conditions));
    for i = 1:numel(systems)
        for j = 1:numel(conditions)
            r = rows(rows.system == systems(i) & rows.condition == conditions(j), :);
            if panel == 1, values(i, j) = mean(r.si_sdr_db, 'omitnan');
            else, values(i, j) = mean(r.stoi, 'omitnan'); end
        end
    end
    bar(categorical(systems, systems, replace(systems, "_", " ")), values);
    if panel == 1, ylabel('SI-SDR (dB)'); else, ylabel('STOI'); end
    grid on;
end
legend(replace(conditions, "_", " "), 'Location', 'southoutside', ...
    'Orientation', 'horizontal');
title(layout, 'Stationary-noise sanity check against reference implementations');
exportgraphics(fig, fullfile(out, 'reference_check.png'), Resolution=150);
close(fig);
