function [snrdata] = ssvep_calculate_snr(fftdata)
%SSVEP_CALC_SNR Calculate the signal to noise ratio in SSVEP
%   The input to this function should be a fieldtrip data structure that is
%   the result of ft_freqanalysis with some modification.
%   In particular, the modification should be including the fields:
%   stimfreq: the stimulation frequency
%   
%   Also the optional fields:
%   harmonics: a 1xN vector of integers larger than 1 to indicate which
%   harmonics should be included in the analysis, eg [2, 3, 4]. Default:[]
%   noisebins: the number of bins around the signal frequency that
%   should be treated as "noise", default: 10
%   padbins: the number of bins you want to "pad" your stimfreq by, to
%   avoid smoothing causing signal power to leak into the noise band


% check data is correct
assert(isstruct(fftdata), 'The input is not a structure. Pass the result of ft_freqanalysis');
assert(isfield(fftdata, 'freq'), 'Missing the analysed frequencies (fftdata.freq). Pass the result of ft_freqanalysis');
assert(isfield(fftdata, 'powspctrm'), 'Missing the powerspectrum (fftdata.powspctrm). Make sure to set output to ''pow'' in your call to ft_freqanalysis');
assert(isfield(fftdata, 'stimfreq'), 'Missing the stimulation frequency (fftdata.stimfreq). Make sure to manually add the stimulation frequency to the result of ft_freqanalysis.');

% set defaults
if isfield(fftdata, 'noisebins')
    noisebins = fftdata.noisebins;
else
    noisebins = 10;
end
if isfield(fftdata, 'padbins')
    padbins = fftdata.padbins;
else
    padbins = 2;
end
if isfield(fftdata, 'harmonics')
    harmonics = fftdata.harmonics;
else
    harmonics = [];
end

% get the resolution from the history
try
    freqresolution = fftdata.cfg.tapsmofrq;
catch
    freqresolution = fftdata.cfg.previous{1}.tapsmofrq;
end

if ndims(fftdata.powspctrm) == 2
    fftdata.powspctrm = permute(fftdata.powspctrm, [3, 1, 2]);
end


% Process the stimulation frequency (fundamental)
stimband = fftdata.freq > fftdata.stimfreq-freqresolution &...
           fftdata.freq < fftdata.stimfreq+freqresolution;
noiseband = ~((fftdata.freq > fftdata.stimfreq-padbins*freqresolution) &...
              (fftdata.freq < fftdata.stimfreq+padbins*freqresolution)) & ...
            fftdata.freq > fftdata.stimfreq-noisebins*freqresolution &...
            fftdata.freq < fftdata.stimfreq+noisebins*freqresolution;


% calculate power in the stimband and noiseband
for trial = 1:size(fftdata.powspctrm, 1)
    fftdata.stimpow(trial, :) = squeeze(mean(fftdata.powspctrm(trial, :, stimband), 3));
    fftdata.noisepow(trial, :) = squeeze(mean(fftdata.powspctrm(trial, :, noiseband), 3));
    fftdata.snrstimfreq(trial, :) = squeeze(fftdata.stimpow(trial, :)) ./ squeeze(fftdata.noisepow(trial, :));
end

% Process the harmonics (if requested)
if ~isempty(harmonics)
    fftdata.snrharmonics = zeros(size(fftdata.snrstimfreq, 1), size(fftdata.snrstimfreq, 2), numel(harmonics));
    
    for trial = 1:size(fftdata.powspctrm, 1)
        for i = 1:harmonics

            % work out the harmonic frequency
            currfreq = fftdata.stimfreq * (i + 1);

            % deal with case in which harmonic is outside of range
            if currfreq < fftdata.freq(1) || currfreq > fftdata.freq(end)
                fftdata.snrharmonics(:, i) = NaN;
                continue
            end

            % calculate signal to noise
            stimband = fftdata.freq > currfreq-freqresolution &...
                       fftdata.freq < currfreq+freqresolution;
            noiseband = ~((fftdata.freq > currfreq-2*freqresolution) &...
                          (fftdata.freq < currfreq+2*freqresolution)) & ...
                        fftdata.freq > currfreq-noisebins*freqresolution &...
                        fftdata.freq < currfreq+noisebins*freqresolution;

            % Calculate SNR and store it in the structure
            fftdata.snrharmonics(trial, :, i) = mean(fftdata.powspctrm(trial, :, stimband), 3)./...
                                                  mean(fftdata.powspctrm(trial, :, noiseband), 3);
        end
    end
end


% Before returning, remove the frequency data
snrdata = rmfield(fftdata, {'powspctrm'});

end
