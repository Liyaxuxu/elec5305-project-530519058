function output = apply_stft_gain(input, fs, gainMatrix)
%APPLY_STFT_GAIN Apply a saved Wiener gain to a signal for error analysis.
windowLength = 512;
overlapLength = 384;
window = hamming(windowLength, 'periodic');
[S, ~, ~] = stft(input, fs, Window=window, ...
    OverlapLength=overlapLength, FFTLength=windowLength);
assert(isequal(size(S), size(gainMatrix)), ...
    'Signal STFT and saved gain must have the same size.');
output = istft(gainMatrix .* S, fs, Window=window, ...
    OverlapLength=overlapLength, FFTLength=windowLength);
output = output(1:min(numel(output), numel(input)));
end
