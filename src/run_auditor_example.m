%RUN_AUDITOR_EXAMPLE Example for dynamic_enhancement_auditor (Figure 1).
% Uses unused p257 speech and an office -> cafeteria change, or a synthetic
% signal if the data is not there.
% To show a detected change it goes through the noise excerpts in a fixed
% order and takes the first one where the revised detector finds the change
% (at most one false alarm). So it is a picked example, not an average case.
% The scan is saved in example_choice.csv.
% DeepFilterNet3 (optional): run this once, then
%   python tools/run_deepfilternet.py data/dfn_io/auditor
% and run this script again.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
voicebox = fullfile(root, 'tools', 'external', 'voicebox');
if isfolder(voicebox), addpath(voicebox); end
raw = fullfile(root, 'data', 'raw');
fs = 16000; changeTime = 3.0; snrDb = 5; duration = 6;
controller = struct;
frozen = fullfile(root, 'results', 'controller_ablation', 'frozen_controller.json');
if isfile(frozen), controller = jsondecode(fileread(frozen)); end
detectorConfig = jsondecode(fileread(fullfile(root, 'results', ...
    'detector_revision', 'frozen_config.json')));
detectorConfig.family = string(detectorConfig.family);

if isfolder(fullfile(raw, 'clean_testset_wav'))
    files = dir(fullfile(raw, 'clean_testset_wav', 'p257_*.wav'));
    [~, order] = sort({files.name}); files = files(order);
    clean = [];
    for k = 186:191   % utterances not used by any other experiment
        [x, rate] = audioread(fullfile(files(k).folder, files(k).name));
        clean = [clean; resample(mean(x, 2), fs, rate)]; %#ok<AGROW>
    end
    clean = 0.6 * clean(1:duration*fs) / max(abs(clean(1:duration*fs)));
    [officeAll, rate] = audioread(fullfile(raw, 'OOFFICE', 'ch01.wav'));
    officeAll = resample(officeAll, fs, rate);
    bFolder = 'PCAFETER'; bName = "cafeteria";
    if ~isfile(fullfile(raw, bFolder, 'ch01.wav'))
        bFolder = 'STRAFFIC'; bName = "traffic";
    end
    [otherAll, rate] = audioread(fullfile(raw, bFolder, 'ch01.wav'));
    otherAll = resample(otherAll, fs, rate);

    % go through the excerpts in order, stop at the first detected one
    starts = 5:7:110;
    choice = table;
    chosen = NaN;
    for s = starts
        a = officeAll(s*fs+1:(s+duration)*fs);
        b = otherAll(s*fs+1:(s+duration)*fs);
        noisy = generate_dynamic_scene(clean, a, b, fs, changeTime, snrDb, snrDb);
        [S, ~, t] = stft(noisy, fs, Window=hamming(512, 'periodic'), ...
            OverlapLength=384, FFTLength=512);
        d = trigger_change_features(robust_change_features(S, t), detectorConfig);
        r = score_change_events(d.frameTimes(d.triggers) + 0.016, changeTime, ...
            duration, 0.5);
        choice = [choice; table(s, r.hit, r.latency, r.falseCount, ...
            'VariableNames', {'noise_start_s', 'detected', 'latency_s', ...
            'false_alarms'})]; %#ok<AGROW>
        if r.hit && r.falseCount <= 1
            chosen = s; break;
        end
    end
    if isnan(chosen)
        warning('No detected example in the scan; using the first excerpt.');
        chosen = starts(1);
    end
    fprintf('Scanned %d excerpt(s); chosen noise start %d s.\n', height(choice), chosen);
    noiseA = officeAll(chosen*fs+1:(chosen+duration)*fs);
    noiseB = otherAll(chosen*fs+1:(chosen+duration)*fs);
    name = sprintf('VoiceBank p257, office -> %s at %d dB', bName, snrDb);
    outDir = fullfile(root, 'results', 'auditor_example');
else
    t = (0:1/fs:duration-1/fs)';
    f0 = 125 + 18*sin(2*pi*0.55*t);
    phase = 2*pi*cumsum(f0)/fs;
    clean = (0.25 + 0.75*abs(sin(2*pi*2.2*t))) .* ...
        (sin(phase) + 0.45*sin(2*phase) + 0.20*sin(3*phase));
    clean = 0.35*clean/max(abs(clean));
    rng(5305);
    noiseA = filter(1, [1 -0.97], randn(size(t)));
    noiseB = filter([1 -0.8], [1 -0.25], randn(size(t)));
    snrDb = 0; name = "Synthetic scene"; choice = table;
    outDir = fullfile(root, 'tmp', 'auditor_example');
end
if ~isfolder(outDir), mkdir(outDir); end
if ~isempty(choice), writetable(choice, fullfile(outDir, 'example_choice.csv')); end

% save the mixture for DeepFilterNet3 and load its output if it exists
noisy = generate_dynamic_scene(clean, noiseA, noiseB, fs, changeTime, snrDb, snrDb);
dfn = fullfile(root, 'data', 'dfn_io', 'auditor');
if ~isfolder(fullfile(dfn, 'noisy')), mkdir(fullfile(dfn, 'noisy')); end
noisyFile = fullfile(dfn, 'noisy', 'example.wav');
rewrite = true;
if isfile(noisyFile)
    previous = audioread(noisyFile);
    rewrite = numel(previous) ~= numel(noisy) || max(abs(previous - noisy)) > 1e-6;
end
if rewrite  % only rewrite when the mixture changed, so DFN output stays valid
    audiowrite(noisyFile, noisy, fs, BitsPerSample=32);
end
extra = struct('name', {}, 'signal', {});
enhancedFile = fullfile(dfn, 'enhanced', 'example.wav');
if isfile(enhancedFile)
    info = dir(enhancedFile); source = dir(noisyFile);
    [y, rate] = audioread(enhancedFile);
    if rate == fs && numel(y) == numel(noisy) && info.datenum >= source.datenum
        extra(1).name = "ref_deepfilternet3"; extra(1).signal = y;
    else
        warning('DeepFilterNet3 output does not match this mixture; rerun the Python step.');
    end
else
    disp('No DeepFilterNet3 output for the example yet (optional).');
end

report = dynamic_enhancement_auditor(clean, noiseA, noiseB, fs, changeTime, ...
    snrDb, snrDb, outDir, struct('controller', controller, ...
    'detectorConfig', detectorConfig, 'extraOutputs', extra, 'name', name));
fprintf('Auditor output written to %s\n', report.outDir);
