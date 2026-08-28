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
disp('All speech-enhancement tests passed.');
