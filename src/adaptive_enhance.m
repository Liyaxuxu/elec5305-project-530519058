function enhanced = adaptive_enhance(noisy, fs)
%ADAPTIVE_ENHANCE Blend subtraction and Wiener gains using estimated SNR.
[S, ~, t] = stft(noisy, fs, Window=hann(512, 'periodic'), OverlapLength=384, FFTLength=512);
initialFrames = max(1, min(size(S, 2), round(0.25 / max(mean(diff(t)), eps))));
noisePsd = median(abs(S(:, 1:initialFrames)).^2, 2) + eps;
previousGain = ones(size(noisePsd));
Y = zeros(size(S));
for k = 1:size(S, 2)
    posterior = abs(S(:, k)).^2 ./ noisePsd;
    frameSnrDb = 10 * log10(max(mean(posterior - 1), eps));
    wienerGain = max((posterior - 1) ./ posterior, 0.05);
    alpha = min(max((5 - frameSnrDb) / 15, 0), 1);
    subtractionGain = max(1 - (1 + 1.5 * alpha) ./ sqrt(posterior), 0.03);
    targetGain = alpha * subtractionGain + (1 - alpha) * wienerGain;
    gain = 0.65 * previousGain + 0.35 * targetGain;
    Y(:, k) = gain .* S(:, k);
    previousGain = gain;
    if mean(posterior) < 1.8
        noisePsd = 0.97 * noisePsd + 0.03 * abs(S(:, k)).^2;
    end
end
enhanced = istft(Y, fs, Window=hann(512, 'periodic'), OverlapLength=384, FFTLength=512);
enhanced = enhanced(1:min(numel(enhanced), numel(noisy)));
end
