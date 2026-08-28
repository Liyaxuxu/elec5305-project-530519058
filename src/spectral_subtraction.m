function enhanced = spectral_subtraction(noisy, fs, oversubtraction)
%SPECTRAL_SUBTRACTION Fixed-parameter magnitude spectral subtraction.
if nargin < 3, oversubtraction = 1.5; end
[S, f, t] = stft(noisy, fs, Window=hann(512, 'periodic'), OverlapLength=384, FFTLength=512);
initialFrames = max(1, min(size(S, 2), round(0.25 / max(mean(diff(t)), eps))));
noiseMagnitude = median(abs(S(:, 1:initialFrames)), 2);
cleanMagnitude = max(abs(S) - oversubtraction * noiseMagnitude, 0.03 * abs(S));
enhanced = istft(cleanMagnitude .* exp(1i * angle(S)), fs, Window=hann(512, 'periodic'), OverlapLength=384, FFTLength=512);
enhanced = enhanced(1:min(numel(enhanced), numel(noisy)));
end
