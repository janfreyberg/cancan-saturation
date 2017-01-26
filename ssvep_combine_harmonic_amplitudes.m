function [ fftdata ] = ssvep_combine_harmonic_amplitudes( fftdata )
%SSVEP_COMBINE_HARMONIC_AMPLITUDES Summary of this function goes here
%   Detailed explanation goes here


assert(all(isfield(fftdata,...
    {'powspctrm', 'snrstimfreq', 'snrharmonics'})),...
    'Input fftdata needs the following fields: powspctrm, snrstimfreq, snrharmonics');

% Frequencies analysed
freqresolution = fftdata.cfg.tapsmofrq;
stimband = false(size(fftdata.freq));
for i = 1:(fftdata.harmonics+1)
    stimband = stimband |...
               (fftdata.freq > fftdata.stimfreq * i - freqresolution &...
                fftdata.freq < fftdata.stimfreq * i + freqresolution);
end

weight = max(log(fftdata.snrall), 0);

fftdata.weightedamplitude = sqrt(...
    sum(fftdata.powspctrm(:, stimband).^2 .* weight(:, stimband), 2)./...
    sum(weight(:, stimband), 2)...
    );

end