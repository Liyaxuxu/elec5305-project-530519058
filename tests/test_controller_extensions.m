function test_controller_extensions
% Tests for the new controller modes and options.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root, 'src'));
rng(11); fs = 16000; n = 4*fs; time = (0:n-1)'/fs;
clean = 0.1*sin(2*pi*210*time); clean(time < 0.5) = 0;
noise = 0.03*randn(n, 1); noisy = clean + noise;
base = struct('causalStartup', true);

% 1. default options match the explicitly specified settings
explicit = base;
explicit.fastNoiseAlpha = 0.90; explicit.fastGainAlpha = 0.55;
explicit.holdSeconds = 0.35; explicit.releaseSeconds = 0;
explicit.noiseFloorGuard = false; explicit.gainFloor = 0.05;
for mode = ["fixed", "snr", "change", "oracle"]
    y1 = transition_wiener(noisy, fs, mode, 2.0, "combined", base);
    y2 = transition_wiener(noisy, fs, mode, 2.0, "combined", explicit);
    assert(isequal(y1, y2), 'Default options changed mode %s.', mode);
end
[~, d] = transition_wiener(noisy, fs, "oracle", 2.0, "combined", base);
fast = d.fastWeight > 0;
assert(all(d.noiseAlpha(fast) == 0.90) && all(d.gainAlpha(fast) == 0.55), ...
    'Oracle fast state does not use the original fast rates.');
assert(abs(sum(fast)*0.008 - 0.35) < 0.01, 'Hold time is not 0.35 s.');

% 2. always-fast uses the fast rates after the noise-only start
[~, d] = transition_wiener(noisy, fs, "always_fast", NaN, "combined", base);
active = d.decisionTimes > 0.5;
assert(all(d.noiseAlpha(active) == 0.90) && all(d.gainAlpha(active) == 0.55));

% 3. SNR + change is never slower than SNR alone
[~, dSnr] = transition_wiener(noisy, fs, "snr", 2.0, "combined", base);
[~, dBoth] = transition_wiener(noisy, fs, "snr_change", 2.0, "combined", base);
assert(all(dBoth.noiseAlpha(active) <= dSnr.noiseAlpha(active) + 1e-12));
assert(all(dBoth.gainAlpha(active) <= dSnr.gainAlpha(active) + 1e-12));

% 4. the release ramp goes smoothly from fast to slow
options = base; options.releaseSeconds = 0.2;
[~, d] = transition_wiener(noisy, fs, "oracle", 2.0, "combined", options);
w = d.fastWeight(active);
assert(max(w) == 1 && sum(w > 0 & w < 1) >= 20, 'Release ramp missing.');
assert(all(diff(w(find(w == 1, 1, 'last'):end)) <= 1e-12), ...
    'Release ramp is not monotonic.');

% 5. noise onset after silence: without the guard the estimate stays near
%    zero, with the guard it at least goes up
onsetNoise = noise; onsetNoise(time < 2.0) = 0;
onsetNoisy = clean + onsetNoise;
[~, off] = transition_wiener(onsetNoisy, fs, "fixed", 2.0, "combined", base);
guarded = base; guarded.noiseFloorGuard = true;
[~, on] = transition_wiener(onsetNoisy, fs, "fixed", 2.0, "combined", guarded);
late = off.decisionTimes > 3.5;
[N, ~, ~] = stft(onsetNoise, fs, Window=hamming(512, 'periodic'), ...
    OverlapLength=384, FFTLength=512);
truePower = mean(abs(N(:, end-50:end)).^2, 'all');
assert(mean(on.meanNoisePsd(late)) > mean(off.meanNoisePsd(late)), ...
    'Guard did not raise the collapsed onset estimate.');
fprintf('Onset noise estimate / true power: guard off %.2e, guard on %.2f\n', ...
    mean(off.meanNoisePsd(late))/truePower, mean(on.meanNoisePsd(late))/truePower);

% 6. new modes and the guard are still causal, and the gain decomposition works
future = noisy; future(time >= 2.5) = 10*randn(sum(time >= 2.5), 1);
safe = d.decisionTimes < 2.5;
for mode = ["always_fast", "snr_change", "oracle"]
    [y, a] = transition_wiener(noisy, fs, mode, 2.0, "combined", guarded);
    [~, b] = transition_wiener(future, fs, mode, 2.0, "combined", guarded);
    assert(max(abs(a.gainMatrix(:, safe) - b.gainMatrix(:, safe)), [], 'all') < 1e-10, ...
        'Future samples changed past gains in mode %s.', mode);
    parts = apply_stft_gain(clean, fs, a.gainMatrix) + ...
        apply_stft_gain(noise, fs, a.gainMatrix);
    assert(norm(y - parts)/norm(y) < 1e-9);
    assert(all(a.gainMatrix >= 0.05 - eps, 'all') && ...
        all(a.gainMatrix <= 1 + eps, 'all'));
end

% 7. metric helper: perfect output gives NaN SI-SDR
m = transition_metrics(clean, noise, clean, fs, 2.0, []);
assert(isnan(m.whole_si_sdr_db));
m = transition_metrics(clean, noise, noisy, fs, 2.0, ones(512, 497));
assert(isfinite(m.transition_si_sdr_db) && isfinite(m.steady_si_sdr_db));
assert(isfinite(m.seg_snr_db) && m.seg_snr_db >= -10 && m.seg_snr_db <= 35, ...
    'Segmental SNR outside its clamped range.');
disp('Controller extension tests passed (defaults, modes, release, guard, causality).');
end
