function [ weightedamplitude ] = ssvep_combine_harmonic_amplitudes( fftdata )
%SSVEP_COMBINE_HARMONIC_AMPLITUDES Summary of this function goes here
%   Detailed explanation goes here


assert(all(isfield(fftdata,...
    {'powspctrm', 'harmonics'})),...
    'Input fftdata needs the following fields: powspctrm, harmonics');
assert(all(isfield(fftdata.snr,...
        {'snrstimfreq', 'snrharmonics'})),...
        'Input fftdata needs the following fields: snr.snrstimfreq, snr.snrharmonics');

if ndims(fftdata.powspctrm) == 2
    fftdata.powspctrm = permute(fftdata.powspctrm, [3, 1, 2]);
end

% Frequencies analysed
freqresolution = mean(diff(fftdata.freq));
stimband = false(size(fftdata.freq));

for i = 1:(fftdata.harmonics+1)
    stimband = stimband |...
               (fftdata.freq > fftdata.stimfreq * i - freqresolution &...
                fftdata.freq < fftdata.stimfreq * i + freqresolution);
end

weight = max(log(fftdata.snr.snrspectrum), 0);
weightedamplitude = zeros([size(fftdata.powspctrm, 1), size(fftdata.powspctrm, 2)]);

for trial = 1:size(fftdata.powspctrm, 1)
    weightedamplitude(trial, :) = sqrt(...
        sum(fftdata.powspctrm(trial, :, stimband).^2 .* weight(trial, :, stimband), 3)./...
        sum(weight(trial, :, stimband), 3)...
        );
end
end