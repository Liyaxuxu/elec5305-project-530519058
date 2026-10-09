function test_detector_revision
% Behavioral tests: event accounting, no future leakage, gain decomposition.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
rng(9); fs = 16000; n = 4*fs; time = (0:n-1)'/fs;
clean = 0.1*sin(2*pi*210*time); clean(time<0.5) = 0;
noise = 0.03*randn(n,1); noisy = clean+noise;
window = hamming(512,'periodic');
[S,~,t] = stft(noisy,fs,Window=window,OverlapLength=384,FFTLength=512);
features = robust_change_features(S,t);
assert(numel(features.noiseOccupancyDb)==numel(t));
future = noisy; future(time>=2.5) = 10*randn(sum(time>=2.5),1);
[S2,~,t2] = stft(future,fs,Window=window,OverlapLength=384,FFTLength=512);
features2 = robust_change_features(S2,t2);
safe = t+0.016 < 2.5;
assert(max(abs(features.floorScore(safe)-features2.floorScore(safe)))<1e-10);
assert(max(abs(features.noiseOccupancyDb(safe)- ...
    features2.noiseOccupancyDb(safe)))<1e-10);
for family = ["floor","legacy"]
    config = struct('family',family,'threshold',6, ...
        'persistenceFrames',4,'speechWeight',0.75);
    d1 = trigger_change_features(features,config);
    d2 = trigger_change_features(features2,config);
    assert(isequal(d1.triggers(safe),d2.triggers(safe)), ...
        'Future audio changed a past trigger.');
end
guarded = struct('family',"floor",'threshold',6, ...
    'persistenceFrames',4,'speechWeight',0.75, ...
    'noiseOccupancyThresholdDb',-8);
d = trigger_change_features(features,guarded);
assert(isfield(d,'noisePresent') && numel(d.noisePresent)==numel(t));
options = struct('causalStartup',true);
for mode = ["fixed","snr","change","oracle"]
    [y,d] = transition_wiener(noisy,fs,mode,2.0,"combined",options);
    [~,d2] = transition_wiener(future,fs,mode,2.0,"combined",options);
    assert(max(abs(d.gainMatrix(:,safe)-d2.gainMatrix(:,safe)),[],'all')<1e-10);
    decomposition = apply_stft_gain(clean,fs,d.gainMatrix)+ ...
        apply_stft_gain(noise,fs,d.gainMatrix);
    assert(norm(y-decomposition)/norm(y)<1e-9);
end
custom = options; custom.fastNoiseAlpha = 0.96;
custom.fastGainAlpha = 0.75; custom.fastHoldSeconds = 0.20;
[~,d] = transition_wiener(noisy,fs,"oracle",2.0,"combined",custom);
assert(any(abs(d.noiseAlpha-0.96)<1e-12));
assert(any(abs(d.gainAlpha-0.75)<1e-12));
% Stronger causality test inside the original 250 ms initialization interval.
future = noisy; future(time>=0.15) = 2*randn(sum(time>=0.15),1);
[~,a] = transition_wiener(noisy,fs,"fixed",NaN,"combined",options);
[~,b] = transition_wiener(future,fs,"fixed",NaN,"combined",options);
safe = a.decisionTimes<0.15;
assert(max(abs(a.meanNoisePsd(safe)-b.meanNoisePsd(safe)))<1e-10);
r = score_change_events([1.2;3.1;3.2;6.0],3,8,1);
assert(r.hit && abs(r.latency-0.1)<1e-9 && r.falseCount==3);
r = score_change_events([1.2;4.6],3,8,1);
assert(~r.hit && isnan(r.latency) && r.falseCount==2);
r = score_change_events([0.2;1.5;4.5],NaN,8,1);
assert(~r.isChange && ~r.hit && r.falseCount==2);
r = score_change_events([],3,8,1);
assert(~r.hit && isnan(r.latency) && r.falseCount==0);
disp('Detector revision tests passed (causality, event scoring, decomposition).');
end
