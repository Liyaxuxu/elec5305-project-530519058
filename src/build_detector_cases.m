function [cases, manifest] = build_detector_cases(repoRoot, split, quietFloorDb)
%BUILD_DETECTOR_CASES Make the 48 test cases (6 sequences x 8 conditions).
% split: "development", "validation" or "unseen_test".
% unseen_test uses cafeteria noise (PCAFETER) instead of traffic, and p257
% files and office excerpts that were not used anywhere else.
% quietFloorDb: level of the "quiet" part in onset/offset. Default -Inf is
% digital silence (October audit). The ablation uses -30 dB to avoid the
% zero-initialisation failure observed with the trackers tested here.
if nargin < 3, quietFloorDb = -Inf; end
quiet = 10^(quietFloorDb/20);
fs = 16000; duration = 8; n = duration*fs;
folder = fullfile(repoRoot, 'data', 'raw');
noiseAName = "office";
noiseBName = "traffic"; noiseBFolder = 'STRAFFIC'; noiseBStart = [];
if split == "development"
    speaker = "p232"; firstFile = 30; noiseStart = 70;
elseif split == "validation"
    speaker = "p257"; firstFile = 90; noiseStart = 200;
else
    assert(split == "unseen_test", 'Unknown split.');
    speaker = "p257"; firstFile = 138; noiseStart = 250;
    noiseBName = "cafeteria"; noiseBFolder = 'PCAFETER'; noiseBStart = 20;
    assert(isfile(fullfile(folder, 'PCAFETER', 'ch01.wav')), ...
        'DEMAND PCAFETER is required for unseen_test. See data/README.md.');
end
if isempty(noiseBStart), noiseBStart = noiseStart; end
files = dir(fullfile(folder, 'clean_testset_wav', speaker+"_*.wav"));
[~, order] = sort({files.name}); files = files(order);
assert(numel(files) >= firstFile+47, 'Not enough %s utterances.', speaker);
[office, rate] = audioread(fullfile(folder, 'OOFFICE', 'ch01.wav'));
office = resample(office, fs, rate);
[traffic, rate] = audioread(fullfile(folder, noiseBFolder, 'ch01.wav'));
traffic = resample(traffic, fs, rate);
assert(numel(office) >= (noiseStart+6*duration)*fs && ...
    numel(traffic) >= (noiseBStart+6*duration)*fs, ...
    'Noise recording is too short for the requested excerpts.');
cases = struct([]); manifest = table;
for r = 1:6
    seed = 530519058+r;
    rng(seed);
    selected = firstFile+(r-1)*8+(0:7);
    speech = []; names = strings(1, 8);
    for j = 1:8
        file = files(selected(j)); names(j) = string(file.name);
        [x, rate] = audioread(fullfile(file.folder, file.name));
        speech = [speech; resample(mean(x, 2), fs, rate)]; %#ok<AGROW>
    end
    assert(numel(speech) >= n-0.5*fs, 'Speech sequence is too short.');
    clean = [zeros(0.5*fs, 1); speech(1:n-0.5*fs)];
    clean = clean/(max(abs(clean))+eps)*0.6;
    envelope = movmean(clean.^2, round(0.02*fs));
    possible = find(envelope > 0.04*max(envelope) & ...
        (1:n)' >= 2.5*fs & (1:n)' <= 4.5*fs);
    assert(~isempty(possible));
    cut = possible(randi(numel(possible)));
    changeTime = (cut-1)/fs;
    start = (noiseStart+(r-1)*duration)*fs+1;
    startB = (noiseBStart+(r-1)*duration)*fs+1;
    a = office(start:start+n-1); a = a-mean(a);
    b = traffic(startB:startB+n-1); b = b-mean(b);
    target = mean(clean.^2);
    a = a*sqrt(target/mean(a.^2));
    b = b*sqrt(target/mean(b.^2));
    typeNoise = [a(1:cut-1); b(cut:end)];
    % pause case uses exactly the same noise as the type case
    pauseMask = ones(n, 1);
    lo = cut-round(0.25*fs); hi = cut+round(0.25*fs);
    pauseMask(lo:hi) = 0;
    fade = round(0.02*fs);
    pauseMask(lo-fade:lo-1) = linspace(1, 0, fade);
    pauseMask(hi+1:hi+fade) = linspace(0, 1, fade);
    conditions = ["level", "type", "onset", "offset", "type_pause", ...
        "stationary_office", "stationary_"+noiseBName, "clean_control"];
    noises = {[a(1:cut-1)/sqrt(10); a(cut:end)], typeNoise, ...
        [quiet*b(1:cut-1); b(cut:end)], [b(1:cut-1); quiet*b(cut:end)], ...
        typeNoise, a, b, zeros(n, 1)};
    for j = 1:numel(conditions)
        reference = clean;
        if conditions(j) == "type_pause", reference = clean.*pauseMask; end
        eventTime = changeTime;
        if j > 5, eventTime = NaN; end
        id = split+"_"+r+"_"+conditions(j);
        current = struct('id', id, 'split', split, 'replicate', r, ...
            'condition', conditions(j), 'clean', reference, 'noise', noises{j}, ...
            'noisy', reference+noises{j}, 'changeTime', eventTime, 'fs', fs);
        [snrBefore, snrAfter] = segment_snr(reference, noises{j}, cut, fs);
        if isempty(cases)
            cases = current;
        else
            cases(end+1) = current; %#ok<AGROW>
        end
        manifest = [manifest; table(id, split, speaker, r, seed, ...
            strjoin(names, ";"), conditions(j), noiseAName, (start-1)/fs, ...
            duration, eventTime, noiseBName, (startB-1)/fs, ...
            snrBefore, snrAfter, quietFloorDb, ...
            'VariableNames', {'case_id','split', ...
            'speaker','replicate','seed','speech_files','condition', ...
            'noise_a_name','noise_start_s','duration_s','change_time_s', ...
            'noise_b_name','noise_b_start_s','snr_before_db', ...
            'snr_after_db','quiet_floor_db'})]; %#ok<AGROW>
    end
end
end

function [before, after] = segment_snr(speech, noise, cut, fs)
% SNR before/after the change, skipping the 0.5 s noise-only start
% (Inf = no noise)
first = round(0.5*fs)+1;
before = 10*log10(sum(speech(first:cut-1).^2)/sum(noise(first:cut-1).^2));
after = 10*log10(sum(speech(cut:end).^2)/sum(noise(cut:end).^2));
end
