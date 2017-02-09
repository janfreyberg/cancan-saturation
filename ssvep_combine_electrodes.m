function [crosselecestimate] = ssvep_combine_electrodes(fftdata)
%SSVEP_COMBINE_ELECTRODES Combine electrode data weighted by SNR
%   This function takes frequency data that has been processed with
%   ssvep_combine_harmonic_amplitudes and produces a single amplitude
%   estimate based on the SNR at each electrode.

assert(all(isfield(fftdata,...
        {'powspctrm', 'weightedamplitude'})),...
        'Input fftdata needs the following fields: powspctrm, weightedamplitude');
assert(all(isfield(fftdata.snr,...
        {'snrstimfreq'})),...
        'Input fftdata needs the following fields: snrstimfreq');

if ndims(fftdata.powspctrm) == 2
    fftdata.powspctrm = permute(fftdata.powspctrm, [3, 1, 2]);
end

% weigh by snr at stim freq, but take the amplitude weightedaverage
useelec = ~isnan(mean(fftdata.weightedamplitude, 1));
weight = max(log(fftdata.snr.snrstimfreq), 0);


crosselecestimate = sqrt(...
    sum(fftdata.weightedamplitude(:, useelec).^2 .* weight(:, useelec), 2)./...
    sum(weight(:, useelec), 2)...
);


end
