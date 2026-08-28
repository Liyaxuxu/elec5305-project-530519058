function enhanced = wiener_filter(noisy, fs)
%WIENER_FILTER Decision-directed Wiener enhancement baseline.
[S, ~, t] = stft(noisy, fs, Window=hann(512, 'periodic'), OverlapLength=384, FFTLength=512);
initialFrames = max(1, min(size(S, 2), round(0.25 / max(mean(diff(t)), eps))));
noisePsd = median(abs(S(:, 1:initialFrames)).^2, 2) + eps;
gain = zeros(size(S));
priorSnr = ones(size(noisePsd));
for k = 1:size(S, 2)
    posteriorSnr = abs(S(:, k)).^2 ./ noisePsd;
    priorSnr = 0.98 * priorSnr + 0.02 * max(posteriorSnr - 1, 0);
    gain(:, k) = max(priorSnr ./ (1 + priorSnr), 0.05);
    if mean(posteriorSnr) < 2
        noisePsd = 0.95 * noisePsd + 0.05 * abs(S(:, k)).^2;
    end
end
enhanced = istft(gain .* S, fs, Window=hann(512, 'periodic'), OverlapLength=384, FFTLength=512);
enhanced = enhanced(1:min(numel(enhanced), numel(noisy)));
end
