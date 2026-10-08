function [enhanced, diagnostics] = adaptive_enhance(noisy, fs)
%ADAPTIVE_ENHANCE Compatibility wrapper for the change-aware Wiener mode.
[enhanced, diagnostics] = transition_wiener(noisy, fs, "change", NaN);
end
