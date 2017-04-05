clearvars;
ft_defaults
global ft_default
ft_default.showcallinfo = 'no';
ft_default.trackcallinfo = 'no';
ft_default.trackdatainfo = 'no';


% To do
% Include artifact finding
%#ok<*SAGROW>

electrodes = 'all';
stimfreq = 5.0;

% Trial properties
triggers = [16, 32, 64, 100];
% triggers = {'T 16', 'T 32', 'T 64', 'T 100'};
trialdur = 10.0;
discardstart = 0.0;

% provide directory of the data files & naming pattern here
if exist('C:\EEG Data\cancan\', 'dir')
    filedir = 'C:\EEG Data\cancan\';
elseif exist('/data/group/FANS/cancan/eeg/', 'dir')
    filedir = '/data/group/FANS/cancan/eeg/';
end

files = dir([filedir, '*sat*.eeg.resampled.mat']);

% assign group variables to each file
for isubject = 1:numel(files)
    files(isubject).id = regexprep(files(isubject).name, '(_)', '');
    [idstart, idend] = regexp(files(isubject).id, '(\d+)[ABCabc]');
    files(isubject).id = files(isubject).id(idstart:idend);
    if strcmp(files(isubject).id(1), '0')
        files(isubject).group = 0;
    end
end

% Data Analysis Loop
progressbar; % initialise prog bar
for isubject = 1:numel(files)
    
    %% FFT
    cfg_fft = [];
    cfg_fft.continuous = 'yes';
    cfg_fft.output = 'pow';
    cfg_fft.method = 'mtmfft';
    cfg_fft.foilim = [1 20];
    % Use the maximum frequency resolution
    cfg_fft.tapsmofrq = 1/(cfg_deftrials.trialdef.prestim + cfg_deftrials.trialdef.poststim);
    cfg_fft.channel = electrodes;
    cfg_fft.keeptrials = 'no';
    for i = 1:numel(triggers)
        trigger = triggers(i);
        cfg_fft.trials = trl(:, 4)' == trigger;
        fft_data{isubject, i} = ft_freqanalysis(cfg_fft, prep_data);
    end
    
    
    %% Calculate the signal-to-noise ratio
    for i = 1:numel(triggers)
        fft_data{isubject, i}.snrall = [];
        fft_data{isubject, i}.snrstimfreq = [];
        fft_data{isubject, i}.snrharmonics = [];
        fft_data{isubject, i}.stimpow = [];
        fft_data{isubject, i}.noisepow = [];
        fft_data{isubject, i}.stimfreq = stimfreq;  % add the stimfreq
        fft_data{isubject, i}.harmonics = 2;  % add the harmonic to analyse
        fft_data{isubject, i}.noisebins = 20;
        % do the SNR analysis:
        fft_data{isubject, i} = ssvep_calculate_snr(fft_data{isubject, i});
        fft_data{isubject, i} = ssvep_calculate_all_snr(fft_data{isubject, i});
    end
        
    %% Identify noisy electrodes
    noisechannels = false(size(fft_data{isubject, i}.label));
    % find any electrodes that seem to have been flat
    for i = 1:numel(triggers)
        % anything with crazy high SNRs is a flat channel
        noisechannels = noisechannels | ...
                        any(fft_data{isubject, i}.snrall > 200, 2);
        % any channels with too much power in the noise band shd be removed
        noisechannels = noisechannels | ...
                        fft_data{isubject, i}.noisepow > 15 | fft_data{isubject, i}.noisepow <= 0;
%         % anything with an SNR of below two is irrelevant
%         noisechannels = noisechannels | ...
%                         any(fft_data{isubject, i}.snrstimfreq < 2, 2);
    end
    
    %% re-reference the data and perform analysis again
    cfg_preproc.reref = 'yes';
    cfg_preproc.refchannel = fft_data{isubject, i}.label(~noisechannels);
    % preprocess again
    prep_data = ft_preprocessing(cfg_preproc);
    % resample again
    prep_data = ft_resampledata(cfg_resample, prep_data);
    % fft again
    for i = 1:numel(triggers)
        trigger = triggers(i);
        cfg_fft.trials = trl(:, 4)' == trigger;
        fft_data{isubject, i} = ft_freqanalysis(cfg_fft, prep_data);
    end
    for i = 1:numel(triggers)
        fft_data{isubject, i}.snrall = [];
        fft_data{isubject, i}.snrstimfreq = [];
        fft_data{isubject, i}.snrharmonics = [];
        fft_data{isubject, i}.stimpow = [];
        fft_data{isubject, i}.noisepow = [];
        fft_data{isubject, i}.stimfreq = stimfreq;  % add the stimfreq
        fft_data{isubject, i}.harmonics = 2;  % add the harmonic to analyse
        fft_data{isubject, i}.noisebins = 20;
        % do the SNR analysis:
        fft_data{isubject, i} = ssvep_calculate_snr(fft_data{isubject, i});
        fft_data{isubject, i} = ssvep_calculate_all_snr(fft_data{isubject, i});
    end
end