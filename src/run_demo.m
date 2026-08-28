%RUN_DEMO Reproducible synthetic demonstration of all enhancement methods.
rng(5305);
fs = 16000;
t = (0:1/fs:4-1/fs)';
envelope = 0.5 + 0.5 * sin(2*pi*2.3*t).^2;
clean = 0.5 * envelope .* chirp(t, 120, t(end), 1200, 'logarithmic');
clean(t < 0.3) = 0; % Provide a short noise-only segment for initial PSD estimation.
noise = [0.25*randn(numel(t)/2, 1); filter(1, [1 -0.96], 0.02*randn(numel(t)/2, 1))];
noisy = add_noise_at_snr(clean, noise, 0);
fixedSub = spectral_subtraction(noisy, fs, 1.5);
fixedWiener = wiener_filter(noisy, fs);
adaptive = adaptive_enhance(noisy, fs);
n = min([numel(clean), numel(noisy), numel(fixedSub), numel(fixedWiener), numel(adaptive)]);
snrMetric = @(x) aligned_snr(clean(1:n), x(1:n));
fprintf('Input SNR: %.2f dB\n', snrMetric(noisy));
fprintf('Spectral subtraction: %.2f dB\n', snrMetric(fixedSub));
fprintf('Wiener filter: %.2f dB\n', snrMetric(fixedWiener));
fprintf('Adaptive method: %.2f dB\n', snrMetric(adaptive));
if ~isfolder('results'), mkdir('results'); end
figure('Visible', 'off');
tiledlayout(4, 1);
nexttile; plot(t(1:n), clean(1:n)); title('Clean'); axis tight;
nexttile; plot(t(1:n), noisy(1:n)); title('Noisy'); axis tight;
nexttile; plot(t(1:n), fixedWiener(1:n)); title('Fixed Wiener'); axis tight;
nexttile; plot(t(1:n), adaptive(1:n)); title('Adaptive'); axis tight;
exportgraphics(gcf, fullfile('results', 'demo_waveforms.png'));
close(gcf);

function value = aligned_snr(reference, estimate)
delay = finddelay(reference, estimate, 512);
if delay >= 0
    estimate = estimate(1 + delay:end);
    reference = reference(1:end - delay);
else
    reference = reference(1 - delay:end);
    estimate = estimate(1:end + delay);
end
value = 10*log10(sum(reference.^2) / (sum((reference-estimate).^2) + eps));
end
