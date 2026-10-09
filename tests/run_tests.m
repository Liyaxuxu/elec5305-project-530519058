testDir = fileparts(mfilename('fullpath'));
addpath(testDir);

rng(1);
fs = 16000;
clean = sin(2*pi*220*(0:1/fs:1-1/fs))';
noise = randn(size(clean));
noisy = add_noise_at_snr(clean, noise, 0);
measured = 10*log10(mean(clean.^2) / mean((noisy-clean).^2));
assert(abs(measured) < 0.1, 'Noise mixer did not produce the requested SNR.');
spectralOutput = spectral_subtraction(noisy, fs);
assert(~isempty(spectralOutput) && all(isfinite(spectralOutput)), ...
    'Spectral-subtraction output is invalid.');

transitionTime = 0.5;
[dynamicNoisy, addedNoise, metadata] = generate_dynamic_scene( ...
    clean, noise, filter(1, [1 -0.9], noise), fs, transitionTime, 5, 0);
assert(numel(dynamicNoisy) == numel(clean) && numel(addedNoise) == numel(clean));
assert(metadata.transitionSample == round(transitionTime * fs) + 1);
for mode = ["fixed", "snr", "change", "oracle"]
    [output, diagnostics] = transition_wiener(dynamicNoisy, fs, mode, transitionTime);
    assert(~isempty(output) && all(isfinite(output)), 'Dynamic Wiener output is invalid.');
    assert(numel(diagnostics.frameTimes) == numel(diagnostics.changeScore));
    assert(numel(diagnostics.meanGain) == numel(diagnostics.frameTimes));
    assert(all(isfinite(diagnostics.meanNoisePsd)));
    assert(all(size(diagnostics.gainMatrix) > 0));
    separated = apply_stft_gain(clean, fs, diagnostics.gainMatrix);
    assert(~isempty(separated) && all(isfinite(separated)));
    if mode == "fixed"
        assert(all(abs(diagnostics.noiseAlpha - 0.995) < 1e-12), ...
            'Fixed controller changed its noise-update rate.');
        assert(all(abs(diagnostics.gainAlpha - 0.90) < 1e-12), ...
            'Fixed controller changed its gain-smoothing rate.');
        assert(all(diagnostics.gainMatrix >= 0.05 - eps, 'all') && ...
            all(diagnostics.gainMatrix <= 1 + eps, 'all'), ...
            'Wiener gain is outside its documented range.');
        reconstructed = apply_stft_gain(dynamicNoisy, fs, diagnostics.gainMatrix);
        relativeError = norm(output - reconstructed) / max(norm(output), eps);
        assert(relativeError < 1e-9, ...
            'Saved Wiener gains do not reproduce the enhancer output.');
    end
end
window = hamming(512, 'periodic');
[S, ~, frameTimes] = stft(dynamicNoisy, fs, Window=window, ...
    OverlapLength=384, FFTLength=512);
for cue = ["log_spectrum", "spectral_flux", "modulation", "combined"]
    detector = scene_change_detector(S, frameTimes, cue);
    assert(numel(detector.score) == size(S, 2));
    assert(all(isfinite(detector.score)));
end
test_detector_revision;
disp('All speech-enhancement tests passed.');
