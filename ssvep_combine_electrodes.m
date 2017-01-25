function [fftdata] = ssvep_combine_electrodes(fftdata)
%SSVEP_COMBINE_ELECTRODES Combine electrode data weighted by SNR
%   This function takes frequency data that has been processed with
%   ssvep_combine_harmonic_amplitudes and produces a single amplitude
%   estimate based on the SNR at each electrode.

assert(all(isfield(fftdata,...
    {'powspctrm', 'snrstimfreq', 'snrharmonics', 'weightedamplitude'})),...
    'Input fftdata needs the following fields: powspctrm, snrstimfreq, snrharmonics');

% weigh by snr at stim freq, but take the amplitude weightedaverage
useelec = ~isnan(fftdata.weightedamplitude);

fftdata.crosselecestimate = sqrt(...
    sum(fftdata.weightedamplitude(useelec).^2 .* fftdata.snrstimfreq(useelec))./...
    sum(fftdata.snrstimfreq(useelec))...
);


end

