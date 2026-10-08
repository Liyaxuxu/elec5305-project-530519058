function [noisy, addedNoise, metadata] = generate_dynamic_scene( ...
    clean, noiseA, noiseB, fs, transitionTime, snrBefore, snrAfter)
%GENERATE_DYNAMIC_SCENE Mix two noises around a known transition time.
clean = clean(:);
n = numel(clean);
transitionSample = min(max(round(transitionTime * fs) + 1, 2), n);

noiseA = fit_length(noiseA(:), n);
noiseB = fit_length(noiseB(:), n);
addedNoise = zeros(n, 1);

before = 1:transitionSample - 1;
after = transitionSample:n;
addedNoise(before) = scale_noise(clean(before), noiseA(before), snrBefore);
addedNoise(after) = scale_noise(clean(after), noiseB(after), snrAfter);
noisy = clean + addedNoise;

metadata = struct( ...
    'transitionTime', transitionTime, ...
    'transitionSample', transitionSample, ...
    'snrBefore', snrBefore, ...
    'snrAfter', snrAfter);
end

function output = fit_length(input, n)
if numel(input) < n
    input = repmat(input, ceil(n / numel(input)), 1);
end
output = input(1:n);
end

function scaled = scale_noise(clean, noise, targetSnrDb)
cleanPower = mean(clean.^2) + eps;
noisePower = mean(noise.^2) + eps;
scale = sqrt(cleanPower / (noisePower * 10^(targetSnrDb / 10)));
scaled = scale * noise;
end
