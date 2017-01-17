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
if exist('C:\EEG Data\cancan', 'dir')
    filedir = 'C:\EEG Data\cancan';
elseif exist()
end
filedir = 'C:\EEG Data\cancan';

files = dir([filedir, '\*sat*.eeg']);

% assign group variables to each file
for isubject = 1:numel(files)
    idstart = regexp(files(isubject).name, '(\d)(\d)(\d)[abc]');
    files(isubject).id = files(isubject).name(idstart:(idstart+3));
    if strcmp(files(isubject).id(1), '0')
        files(isubject).group = 0;
    end
end

% Data Analysis Loop
for isubject = 1:numel(files)
    % clear variables
    clear *_data cfg*
    
    % Trial Basics
    cfg_deftrials.dataset = fullfile(filedir, files(isubject).name);
    cfg_deftrials.trialdef.eventtype = 'Toggle';
    cfg_deftrials.trialfun = 'ft_trialfun_general';
    % Trial Timing
    cfg_deftrials.trialdef.prestim = -discardstart;
    cfg_deftrials.trialdef.poststim = trialdur;
    
    trl = [];  % initialise to append
    for trigger = triggers
        cfg_deftrials.trialdef.eventvalue = sprintf('T% 3u', trigger);
        tmp = ft_definetrial(cfg_deftrials);
        % Manually add the trigger code
        tmp.trl(:, 4) = trigger;
        trl = vertcat(trl, tmp.trl);
    end
    
    
    % Trial Preprocessing
    cfg_preproc = cfg_deftrials;
    cfg_preproc.trl = trl;  % update the trl matrix
    cfg_preproc.channel = electrodes;
    cfg_preproc.continuous = 'yes';
    cfg_preproc.demean = 'yes';  % Subtract mean within each trial
    cfg_preproc.detrend = 'no';  % equivalent to hi-pass filter
    % Rereferencing
    cfg_preproc.reref = 'no';
    cfg_preproc.refchannel = 'all';
    % Filtering
    cfg_preproc.lpfilter = 'yes';
    cfg_preproc.lpfreq = 20;
    % Actual Preprocessing Function
    prep_data = ft_preprocessing(cfg_preproc);
    
    
    % Resample data from 5000 to 250 Hz
    cfg_resample = [];
    cfg_resample.resamplefs = 250;
    cfg_resample.detrend = 'no';
    prep_data = ft_resampledata(cfg_resample, prep_data);
    
    
    % FFT
    cfg_fft = [];
    cfg_fft.continuous = 'yes';
    cfg_fft.output = 'pow';
    cfg_fft.method = 'mtmfft';
    cfg_fft.foilim = [0 20];
    % Use the maximum frequency resolution
    cfg_fft.tapsmofrq = 1/(cfg_deftrials.trialdef.prestim + cfg_deftrials.trialdef.poststim);
    cfg_fft.channel = electrodes;
    cfg_fft.keeptrials = 'no';
    for i = 1:numel(triggers)
        trigger = triggers(i);
        cfg_fft.trials = trl(:, 4)' == trigger;
        fft_data(i) = ft_freqanalysis(cfg_fft, prep_data);
    end
    
    
    % Calculate the signal-to-noise ratio
    for i = 1:numel(triggers)
        fft_data(i).snrall = [];
        fft_data(i).snrstimfreq = [];
        fft_data(i).snrharmonics = [];
        fft_data(i).stimfreq = stimfreq;  % add the stimfreq
        fft_data(i).harmonics = 2;  % add the harmonic to analyse
        fft_data(i).noisebins = 20;
        % do the SNR analysis:
        fft_data(i) = ssvep_calculate_snr(fft_data(i));
        fft_data(i) = ssvep_calculate_all_snr(fft_data(i));
    end
    
    
    % Identify noisy electrodes
    noisechannels = false(size(fft_data(1).label));
    % find any electrodes that seem to have been flat
    for i = 1:numel(triggers)
        % anything with crazy high SNRs is a flat channel
        noisechannels = noisechannels | ...
                        any(fft_data(i).snrall > 200, 2);
        % anything with an SNR of below two is irrelevant
    end
    % set those electrodes to NaN in the frequency spectrum
    for i = 1:numel(triggers)
        fft_data(i).powspctrm(noisechannels, :) = NaN;
        fft_data(i).snrall(noisechannels, :) = NaN;
    end
    
    
    % Calculate weighted amplitude
    for i = 1:numel(triggers)
        fft_data(i) = ssvep_combine_harmonic_amplitudes(fft_data);
    end
    
    
    
%     % A quick plot
%     figure;
%     title(files(isubject).id);
%     for i = 1:numel(triggers)
%         subplot(4, 1, i);
%         plot(fft_data(i).freq, fft_data(i).powspctrm(~noisechannels, :));
%         % ylim([0, 25]);
%         xlim(cfg_fft.foilim);
%         % add text to identify channels
%         text(1.8 + zeros(size(fft_data(1).label)),...
%              fft_data(i).snrall(:, find(fft_data(i).freq>=1.8, 1)),...
%              fft_data(i).label);
%     end
%     % topoplot
%     figure;
%     for i = 1:numel(triggers)
%         tmp_data = fft_data(i);
%         tmp_data.snrall = tmp_data.snrall(:, (tmp_data.freq > 4.9 & tmp_data.freq < 5.1) | ...
%                                             (tmp_data.freq > 9.9 & tmp_data.freq < 10.1) | ...
%                                             (tmp_data.freq > 14.9 & tmp_data.freq < 15.1));
%         tmp_data.freq = tmp_data.freq((tmp_data.freq > 4.9 & tmp_data.freq < 5.1) | ...
%                                             (tmp_data.freq > 9.9 & tmp_data.freq < 10.1) | ...
%                                             (tmp_data.freq > 14.9 & tmp_data.freq < 15.1));
%         subplot(2, 2, i);
%         cfg = [];
%         cfg.parameter = 'snrall';
%         cfg.layout = 'biosemi64.lay';
%         cfg.channel = fft_data(i).label(~noisechannels);
%         ft_topoplotTFR(cfg, tmp_data);
%     end
%     drawnow;
    
end


