function run_controller_ablation(phase)
%RUN_CONTROLLER_ABLATION Main experiment: compare the controllers.
%   run_controller_ablation("develop")   pick the fast-state settings on p232
%   run_controller_ablation("validate")  frozen settings, validation split
%   run_controller_ablation("test")      frozen settings, office -> cafeteria
%
% Checks if the change-aware controller helps because it detects the change
% or just because it adapts faster more often. All systems use the same
% mixtures and Wiener equation: fixed, snr, change_legacy, change_revised,
% snr_change_legacy, snr_change_revised, always_fast and oracle.
% References: spectral subtraction, VOICEBOX MMSE (if tools/external/voicebox
% exists) and DeepFilterNet3 (if a complete set of enhanced WAVs exists).
% Onset/offset use a -30 dB floor instead of digital silence.
% For DeepFilterNet3: run this once, then
%   python tools/run_deepfilternet.py data/dfn_io/<split>
% and run this again.
% "original" = old fast-state settings, "selected" = chosen on development.
arguments
    phase (1,1) string {mustBeMember(phase, ["develop", "validate", "test"])}
end
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'results', 'controller_ablation');
if ~isfolder(out), mkdir(out); end
splits = struct('develop', "development", 'validate', "validation", ...
    'test', "unseen_test");
split = splits.(char(phase));

quietFloorDb = -30;
[cases, manifest] = build_detector_cases(root, split, quietFloorDb);
writetable(manifest, fullfile(out, split + "_manifest.csv"));
dfnFolder = fullfile(root, 'data', 'dfn_io', split);
export_mixtures(cases, fullfile(dfnFolder, 'noisy'));
detectorConfig = jsondecode(fileread(fullfile(root, 'results', ...
    'detector_revision', 'frozen_config.json')));
detectorConfig.family = string(detectorConfig.family);

fprintf('Computing detectors for %d %s cases...\n', numel(cases), split);
legacy = cell(size(cases)); revised = cell(size(cases));
for c = 1:numel(cases)
    [S, ~, t] = stft(cases(c).noisy, cases(c).fs, ...
        Window=hamming(512, 'periodic'), OverlapLength=384, FFTLength=512);
    legacy{c} = scene_change_detector(S, t, "combined");
    revised{c} = trigger_change_features(robust_change_features(S, t), ...
        detectorConfig);
end

original = struct('fastNoiseAlpha', 0.90, 'fastGainAlpha', 0.55, ...
    'holdSeconds', 0.35, 'releaseSeconds', 0, 'noiseFloorGuard', false, ...
    'gainFloor', 0.05);
frozenPath = fullfile(out, 'frozen_controller.json');
if phase == "develop"
    selected = select_controller(cases, original, out, legacy);
    fid = fopen(frozenPath, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', jsonencode(selected, PrettyPrint=true));
    clear cleanup;
else
    assert(isfile(frozenPath), 'Run run_controller_ablation("develop") first.');
    selected = jsondecode(fileread(frozenPath));
    assert(isfield(selected, 'gainFloor'), ...
        'frozen_controller.json is from an older version: rerun "develop".');
end
disp('Selected controller setting:'); disp(selected);

systems = ["noisy", "fixed", "snr", "change_legacy", "change_revised", ...
    "snr_change_legacy", "snr_change_revised", "always_fast", "oracle"];
voiceboxFolder = fullfile(root, 'tools', 'external', 'voicebox');
if isfolder(voiceboxFolder), addpath(voiceboxFolder); end
systems(end+1) = "spectral_subtraction";
if exist('specsub', 'file') == 2
    systems(end+1) = "ref_voicebox_mmse";
else
    disp('VOICEBOX not on the path: reference system skipped.');
end
if validate_dfn_outputs(cases, dfnFolder)
    systems(end+1) = "ref_deepfilternet3";
else
    disp('No DeepFilterNet3 outputs found: reference system skipped.');
end
configIndependent = ["noisy", "spectral_subtraction", ...
    "ref_voicebox_mmse", "ref_deepfilternet3"];
configs = {original, selected};
configNames = ["original", "selected"];

metricRows = struct([]); recoveryRows = struct([]);
for c = 1:numel(cases)
    current = cases(c);
    fprintf('Case %d/%d: %s\n', c, numel(cases), current.id);
    cache = struct;
    for k = 1:numel(configNames)
        for system = systems
            if any(system == configIndependent) && isfield(cache, char(system))
                result = cache.(char(system));  % does not depend on the setting
            else
                result = run_system(system, current, configs{k}, ...
                    legacy{c}, revised{c}, dfnFolder);
                if any(system == configIndependent)
                    cache.(char(system)) = result;
                end
            end
            m = transition_metrics(current.clean, current.noise, ...
                result.output, current.fs, current.changeTime, result.gain);
            row = struct('case_id', current.id, 'replicate', current.replicate, ...
                'condition', current.condition, 'config', configNames(k), ...
                'system', system, 'whole_si_sdr_db', m.whole_si_sdr_db, ...
                'seg_snr_db', m.seg_snr_db, ...
                'stoi', m.stoi, 'transition_si_sdr_db', m.transition_si_sdr_db, ...
                'steady_si_sdr_db', m.steady_si_sdr_db, ...
                'settling_time_s', m.settling_time_s, ...
                'transition_speech_error_db', m.transition_speech_error_db, ...
                'transition_noise_suppression_db', ...
                m.transition_noise_suppression_db, ...
                'fast_state_fraction', result.fastFraction, ...
                'n_triggers', result.nTriggers, 'runtime_s', result.runtime);
            metricRows = append_row(metricRows, row);
            if isfinite(current.changeTime)
                recoveryRows = append_row(recoveryRows, recovery_rows( ...
                    current, configNames(k), system, result.output));
            end
        end
    end
end
metrics = struct2table(metricRows);
writetable(metrics, fullfile(out, split + "_metrics.csv"));
writetable(struct2table(recoveryRows), fullfile(out, split + "_recovery.csv"));
values = {'whole_si_sdr_db', 'seg_snr_db', 'stoi', 'transition_si_sdr_db', ...
    'steady_si_sdr_db', 'settling_time_s', 'transition_speech_error_db', ...
    'transition_noise_suppression_db', 'fast_state_fraction', 'runtime_s'};
summary = groupsummary(metrics, {'config', 'system'}, 'mean', values);
writetable(summary, fullfile(out, split + "_summary.csv"));
byCondition = groupsummary(metrics, {'config', 'system', 'condition'}, ...
    'mean', values);
writetable(byCondition, fullfile(out, split + "_by_condition.csv"));
disp(summary(summary.config == "selected", :));
plot_onset_noise_estimate(split);
plot_controller_ablation(split);
end

function selected = select_controller(cases, original, out, legacy)
% Small grid search for the fast state. Uses the oracle trigger so detector
% mistakes don't affect the choice. The noise-floor guard is left out
% because it overestimated the noise during speech.
search = struct([]);
best = -inf;
selected = original;
for fastGain = [0.55, 0.75]
    for holdTime = [0.35, 0.70]
        for release = [0, 0.30]
            for gainFloor = [0.05, 0.10]  % two maximum-attenuation settings
                guard = false;
                config = original;
                config.gainFloor = gainFloor;
                config.fastGainAlpha = fastGain;
                config.holdSeconds = holdTime;
                config.releaseSeconds = release;
                config.noiseFloorGuard = guard;
                whole = NaN(numel(cases), 1); local = NaN(numel(cases), 1);
                for c = 1:numel(cases)
                    current = cases(c);
                    options = config; options.causalStartup = true;
                    options.detector = legacy{c};  % cached; unused by oracle
                    output = transition_wiener(current.noisy, current.fs, ...
                        "oracle", current.changeTime, "combined", options);
                    output = real(output(1:numel(current.clean)));
                    whole(c) = sisdr(current.clean, output);
                    if isfinite(current.changeTime)
                        r = round(current.changeTime*current.fs)+1: ...
                            round((current.changeTime+0.75)*current.fs);
                        local(c) = sisdr(current.clean(r), output(r));
                    end
                end
                objective = mean(whole, 'omitnan') + mean(local, 'omitnan');
                row = config;
                row.mean_whole_si_sdr_db = mean(whole, 'omitnan');
                row.mean_transition_si_sdr_db = mean(local, 'omitnan');
                row.objective = objective;
                search = append_row(search, row);
                fprintf('gain %.2f hold %.2f release %.2f floor %.2f: %.3f\n', ...
                    fastGain, holdTime, release, gainFloor, objective);
                if objective > best
                    best = objective; selected = config;
                end
            end
        end
    end
end
writetable(struct2table(search), fullfile(out, 'development_controller_search.csv'));
end

function result = run_system(system, current, config, legacyDetector, ...
    revisedDetector, dfnFolder)
options = config; options.causalStartup = true;
options.detector = legacyDetector;  % cached; triggers unused by non-change modes
gain = []; fastFraction = NaN; nTriggers = NaN;
started = tic;
switch system
    case "noisy"
        output = current.noisy;
    case "spectral_subtraction"
        % course baseline, noise from the first 250 ms (noise-only start)
        output = spectral_subtraction(current.noisy, current.fs);
    case "ref_deepfilternet3"
        [output, rate] = audioread(fullfile(dfnFolder, 'enhanced', ...
            current.id + ".wav"));
        assert(rate == current.fs, 'DeepFilterNet output must be 16 kHz.');
    case "ref_voicebox_mmse"
        pp = struct('g', 2, 'e', 2, 'am', 1, 'ne', 1, 'ti', 0.008, ...
            'of', 4, 'b', 0.05^2);
        output = specsub(current.noisy, current.fs, pp);
    otherwise
        mode = system;
        if startsWith(system, "change_") || startsWith(system, "snr_change_")
            if endsWith(system, "_legacy")
                options.detector = legacyDetector;
            else
                options.detector = revisedDetector;
            end
            mode = erase(system, ["_legacy", "_revised"]);
        end
        [output, diag] = transition_wiener(current.noisy, current.fs, mode, ...
            current.changeTime, "combined", options);
        gain = diag.gainMatrix;
        active = diag.decisionTimes > 0.5;
        fastFraction = mean(diag.fastWeight(active) > 0);
        nTriggers = sum(diag.triggers);
end
result = struct('output', real(output(:)), 'gain', gain, ...
    'runtime', toc(started), 'fastFraction', fastFraction, ...
    'nTriggers', nTriggers);
end

function rows = recovery_rows(current, configName, system, output)
rows = struct([]);
n = numel(current.clean);
output = [output(1:min(end, n)); zeros(max(0, n-numel(output)), 1)];
for relativeStart = -0.5:0.1:2.4
    first = round((current.changeTime + relativeStart)*current.fs) + 1;
    last = first + round(0.1*current.fs) - 1;
    if first < 1 || last > n, continue; end
    rows = append_row(rows, struct('case_id', current.id, ...
        'condition', current.condition, 'config', configName, ...
        'system', system, 'relative_time_s', relativeStart + 0.05, ...
        'local_si_sdr_db', sisdr(current.clean(first:last), output(first:last))));
end
end

function export_mixtures(cases, folder)
% save mixtures as 32-bit float wav so nothing gets clipped or rescaled
if ~isfolder(folder), mkdir(folder); end
for c = 1:numel(cases)
    x = cases(c).noisy;
    audiowrite(fullfile(folder, cases(c).id + ".wav"), x, cases(c).fs, ...
        BitsPerSample=32);
end
end

function rows = append_row(rows, row)
if isempty(row), return; end
if isempty(rows)
    rows = row;
else
    rows(end+1:end+numel(row)) = row;
end
end

function value = sisdr(reference, estimate)
reference = reference - mean(reference); estimate = estimate - mean(estimate);
target = reference*(reference'*estimate)/(reference'*reference + eps);
residual = sum((estimate - target).^2);
if residual < 1e-12*sum(target.^2), value = NaN; return; end
value = 10*log10((sum(target.^2) + eps)/(residual + eps));
end
