function [cases, manifest] = build_detector_cases(repoRoot, split)
%BUILD_DETECTOR_CASES Reproducible disjoint excerpts and matched controls.
fs = 16000; duration = 8; n = duration*fs;
folder = fullfile(repoRoot, 'data', 'raw');
if split == "development"
    speaker = "p232"; firstFile = 30; noiseStart = 70;
else
    assert(split == "validation");
    speaker = "p257"; firstFile = 90; noiseStart = 200;
end
files = dir(fullfile(folder, 'clean_testset_wav', speaker+"_*.wav"));
[~, order] = sort({files.name}); files = files(order);
[office, rate] = audioread(fullfile(folder, 'OOFFICE', 'ch01.wav'));
office = resample(office, fs, rate);
[traffic, rate] = audioread(fullfile(folder, 'STRAFFIC', 'ch01.wav'));
traffic = resample(traffic, fs, rate);
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
    a = office(start:start+n-1); a = a-mean(a);
    b = traffic(start:start+n-1); b = b-mean(b);
    target = mean(clean.^2);
    a = a*sqrt(target/mean(a.^2));
    b = b*sqrt(target/mean(b.^2));
    typeNoise = [a(1:cut-1); b(cut:end)];
    % Speech-pause case retains the EXACT same noise as its active partner.
    pauseMask = ones(n, 1);
    lo = cut-round(0.25*fs); hi = cut+round(0.25*fs);
    pauseMask(lo:hi) = 0;
    fade = round(0.02*fs);
    pauseMask(lo-fade:lo-1) = linspace(1, 0, fade);
    pauseMask(hi+1:hi+fade) = linspace(0, 1, fade);
    conditions = ["level", "type", "onset", "offset", "type_pause", ...
        "stationary_office", "stationary_traffic", "clean_control"];
    noises = {[a(1:cut-1)/sqrt(10); a(cut:end)], typeNoise, ...
        [zeros(cut-1, 1); b(cut:end)], [b(1:cut-1); zeros(n-cut+1, 1)], ...
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
        if isempty(cases)
            cases = current;
        else
            cases(end+1) = current; %#ok<AGROW>
        end
        manifest = [manifest; table(id, split, speaker, r, seed, ...
            strjoin(names, ";"), conditions(j), (start-1)/fs, ...
            duration, eventTime, 'VariableNames', {'case_id','split', ...
            'speaker','replicate','seed','speech_files','condition', ...
            'noise_start_s','duration_s','change_time_s'})]; %#ok<AGROW>
    end
end
end
