function [snrall] = ssvep_calculate_all_snr(fftdata)
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
%   should be treated as "noise", both above and below. Default: 10
%   padbins: the number of bins you want to "pad" your stimfreq by, to
%   avoid smoothing causing signal power to leak into the noise band.
%   Default: 2


% check data is correct
assert(isstruct(fftdata), 'The input is not a structure. Pass the result of ft_freqanalysis');
assert(isfield(fftdata, 'freq'), 'Missing the analysed frequencies (fftdata.freq). Pass the result of ft_freqanalysis');
assert(isfield(fftdata, 'powspctrm'), 'Missing the powerspectrum (fftdata.powspctrm). Make sure to set output to ''pow'' in your call to ft_freqanalysis');

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

% get the resolution from the history
try
    freqresolution = fftdata.cfg.tapsmofrq;
catch
    freqresolution = fftdata.cfg.previous{1}.tapsmofrq;
end

if ndims(fftdata.powspctrm) == 2
    fftdata.powspctrm = permute(fftdata.powspctrm, [3, 1, 2]);
end

fftdata.snrall = zeros(size(fftdata.powspctrm));
for trial = 1:size(fftdata.powspctrm, 1)
    for i = 1:numel(fftdata.freq)

        % work out the harmonic frequency
        currfreq = fftdata.freq(i);

        % calculate signal to noise
        stimband = fftdata.freq > currfreq-freqresolution &...
                   fftdata.freq < currfreq+freqresolution;
        noiseband = ~((fftdata.freq > currfreq-padbins*freqresolution) &...
                      (fftdata.freq < currfreq+padbins*freqresolution)) & ...
                    fftdata.freq > currfreq-noisebins*freqresolution &...
                    fftdata.freq < currfreq+noisebins*freqresolution;

        % Calculate SNR and store it in the structure
        snrall(trial, :, i) = mean(fftdata.powspctrm(trial, :, stimband), 3)./...
                                mean(fftdata.powspctrm(trial, :, noiseband), 3);
    end
end

% If there was only one type of rpt, squeeze the data
% disp(size(snrall));
snrall = squeeze(snrall);
% Make the beginning and end NaNs because they don't have any neighbours
snrall(:, 1:noisebins) = NaN;
snrall(:, end-noisebins:end) = NaN;
% disp(size(snrall));

% end function
end
