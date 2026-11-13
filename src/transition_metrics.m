function m = transition_metrics(clean, noise, output, fs, changeTime, gainMatrix)
%TRANSITION_METRICS All the metrics for one output.
% m = transition_metrics(clean, noise, output, fs, changeTime, gainMatrix)
% Whole signal: SI-SDR, segmental SNR, STOI. Around the change: SI-SDR in
% 0-0.75 s and 1.5-2.5 s, settling time, and (if the gain is given) speech
% error and noise suppression. These are NaN when there is no change.
clean = clean(:); noise = noise(:);
n = numel(clean);
output = real(output(:));
output = [output(1:min(end, n)); zeros(max(0, n - numel(output)), 1)];

m = struct('whole_si_sdr_db', si_sdr(clean, output), ...
    'seg_snr_db', segmental_snr(clean, output, fs), 'stoi', NaN, ...
    'transition_si_sdr_db', NaN, 'steady_si_sdr_db', NaN, ...
    'settling_time_s', NaN, 'transition_speech_error_db', NaN, ...
    'transition_noise_suppression_db', NaN);
if exist('stoi', 'file') == 2
    m.stoi = stoi(output, clean, fs);
end
if ~isfinite(changeTime), return; end

transition = region(changeTime, changeTime + 0.75, fs, n);
steady = region(changeTime + 1.5, changeTime + 2.5, fs, n);
m.transition_si_sdr_db = si_sdr(clean(transition), output(transition));
m.steady_si_sdr_db = si_sdr(clean(steady), output(steady));
m.settling_time_s = settling_time(clean, output, fs, changeTime);
if nargin >= 6 && ~isempty(gainMatrix)
    speech = fit(apply_stft_gain(clean, fs, gainMatrix), n);
    residual = fit(apply_stft_gain(noise, fs, gainMatrix), n);
    m.transition_speech_error_db = 10*log10( ...
        (sum((speech(transition) - clean(transition)).^2) + eps) / ...
        (sum(clean(transition).^2) + eps));
    if mean(noise(transition).^2) > 1e-12
        m.transition_noise_suppression_db = 10*log10( ...
            (sum(noise(transition).^2) + eps) / ...
            (sum(residual(transition).^2) + eps));
    end
end
end

function value = segmental_snr(reference, estimate, fs)
% mean SNR over 32 ms frames with speech, clamped to [-10, 35] dB
% (Loizou 2013); silent frames are skipped
frame = round(0.032*fs); starts = 1:frame:numel(reference)-frame+1;
values = NaN(size(starts));
peak = max(reference.^2);
for k = 1:numel(starts)
    index = starts(k):starts(k)+frame-1;
    signal = sum(reference(index).^2);
    if mean(reference(index).^2) < 1e-4*peak, continue; end
    frameSnr = 10*log10(signal/(sum((reference(index)-estimate(index)).^2) + eps));
    values(k) = min(max(frameSnr, -10), 35);
end
value = mean(values, 'omitnan');
end

function index = region(startTime, endTime, fs, n)
index = max(1, round(startTime*fs) + 1):min(n, round(endTime*fs));
end

function y = fit(x, n)
x = real(x(:));
y = [x(1:min(end, n)); zeros(max(0, n - numel(x)), 1)];
end

function value = si_sdr(reference, estimate)
% exact reconstruction gives NaN (same as run_detector_revision.m)
reference = reference - mean(reference); estimate = estimate - mean(estimate);
target = reference*(reference'*estimate)/(reference'*reference + eps);
residual = sum((estimate - target).^2);
if residual < 1e-12*sum(target.^2), value = NaN; return; end
value = 10*log10((sum(target.^2) + eps)/(residual + eps));
end

function seconds = settling_time(reference, estimate, fs, changeTime)
% start of the first 3 blocks (100 ms each) whose error is within 1.5 dB
% of the median error from 1.5 s after the change
block = round(0.10*fs);
startSample = round(changeTime*fs) + 1;
starts = startSample:block:(numel(reference) - block + 1);
errorDb = arrayfun(@(s) 10*log10(mean( ...
    (estimate(s:s+block-1) - reference(s:s+block-1)).^2) + eps), starts);
late = starts >= round((changeTime + 1.5)*fs);
if ~any(late), seconds = NaN; return; end
target = median(errorDb(late));
stable = abs(errorDb - target) <= 1.5;
first = find(conv(double(stable), ones(1, 3), 'valid') >= 3, 1);
if isempty(first)
    seconds = NaN;
else
    seconds = (starts(first) - startSample)/fs;
end
end
