rng(1);
fs = 16000;
clean = sin(2*pi*220*(0:1/fs:1-1/fs))';
noise = randn(size(clean));
noisy = add_noise_at_snr(clean, noise, 0);
measured = 10*log10(mean(clean.^2) / mean((noisy-clean).^2));
assert(abs(measured) < 0.1, 'Noise mixer did not produce the requested SNR.');
outputs = {spectral_subtraction(noisy, fs), wiener_filter(noisy, fs), adaptive_enhance(noisy, fs)};
for k = 1:numel(outputs)
    assert(~isempty(outputs{k}) && all(isfinite(outputs{k})), 'Enhancement output is invalid.');
end

transitionTime = 0.5;
[dynamicNoisy, addedNoise, metadata] = generate_dynamic_scene( ...
    clean, noise, filter(1, [1 -0.9], noise), fs, transitionTime, 5, 0);
assert(numel(dynamicNoisy) == numel(clean) && numel(addedNoise) == numel(clean));
assert(metadata.transitionSample == round(transitionTime * fs) + 1);
for mode = ["fixed", "snr", "change", "oracle"]
    [output, diagnostics] = transition_wiener(dynamicNoisy, fs, mode, transitionTime);
    assert(~isempty(output) && all(isfinite(output)), 'Dynamic Wiener output is invalid.');
    assert(numel(diagnostics.frameTimes) == numel(diagnostics.changeScore));
end
disp('All speech-enhancement tests passed.');
