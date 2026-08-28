function noisy = add_noise_at_snr(clean, noise, targetSNR)
%ADD_NOISE_AT_SNR Scale and add noise at a requested global SNR.
clean = clean(:);
noise = noise(:);
if numel(noise) < numel(clean)
    noise = repmat(noise, ceil(numel(clean) / numel(noise)), 1);
end
noise = noise(1:numel(clean));
cleanPower = mean(clean.^2) + eps;
noisePower = mean(noise.^2) + eps;
scale = sqrt(cleanPower / (noisePower * 10^(targetSNR / 10)));
noisy = clean + scale * noise;
end
