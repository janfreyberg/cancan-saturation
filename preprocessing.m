clearvars;
ft_defaults
global ft_default
ft_default.showcallinfo = 'no';
ft_default.trackcallinfo = 'no';
ft_default.trackdatainfo = 'no';

% To do
% Include artifact finding
%#ok<*SAGROW>

electrodes = 1:64;
stimulation_freq = 5.0;

% Trial properties
triggers = [16, 32, 64, 100];
% triggers = {'T 16', 'T 32', 'T 64', 'T 100'};
trialdur = 10.0;
discardstart = 0.0;

% provide directory of the data files & naming pattern here
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
    cfg_preproc.detrend = 'yes';  % equivalent to hi-pass filter
    % Rereferencing
    cfg_preproc.reref = 'no';
    cfg_preproc.refchannel = 'all';
    % Filtering
    cfg_preproc.lpfilter = 'yes';
    cfg_preproc.lpfreq = 20;
    % Actual Preprocessing Function
    prep_data = ft_preprocessing(cfg_preproc);
    
    
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
    for trigger = triggers
        cfg_fft.trials = trl(:, 4)' == trigger;
        fft_data(triggers==trigger) = ft_freqanalysis(cfg_fft, prep_data);
    end
    
    % A quick plot
    figure;
    plot(fft_data(4).freq, fft_data(4).powspctrm);
    ylim([0, 20]);
    title(files(isubject).id);
    drawnow;
    
end


