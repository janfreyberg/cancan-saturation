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

files = dir([filedir, '*sat*.eeg']);

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
    % clear variables
    clear prep_data cfg*
    
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
        % try statement because sometimes the triggers are fucked
        try
            tmp = ft_definetrial(cfg_deftrials);
        catch
            continue
        end
        % Manually add the trigger code
        tmp.trl(:, 4) = trigger;
        trl = vertcat(trl, tmp.trl); %#ok<AGROW>
    end
    % build in a check if trl is full up
    if isempty(trl)
        continue
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
    
    
    % Calculate the signal-to-noise ratio
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
        
    % Identify noisy electrodes
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
    
    % re-reference the data and perform analysis again
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
        

    
    % set those electrodes to NaN in the frequency spectrum
    for i = 1:numel(triggers)
        fft_data{isubject, i}.powspctrm(noisechannels, :) = NaN;
        fft_data{isubject, i}.snrall(noisechannels, :) = NaN;
        fft_data{isubject, i}.snrstimfreq(noisechannels, :) = NaN;
    end
    
    
    % Calculate weighted amplitude
    for i = 1:numel(triggers)
        fft_data{isubject, i}.weightedamplitude = [];
        fft_data{isubject, i} = ssvep_combine_harmonic_amplitudes(fft_data{isubject, i});
    end
    
    % calculate a weighted average by electrode
    for i = 1:numel(triggers)
        fft_data{isubject, i}.crosselecestimate = [];
        fft_data{isubject, i} = ssvep_combine_electrodes(fft_data{isubject, i});
    end
    % TODO
    
    % find the maximal signal electrode on average
    [~, maxelec] = max(mean([fft_data{isubject, 4}.snrstimfreq], 2));
    
    % display the amplitude at those spots
%     disp([fft_data{isubject, 1).weightedamplitude(maxelec),...
%             fft_data{isubject, 2).weightedamplitude(maxelec),...
%             fft_data{isubject, 3).weightedamplitude(maxelec),...
%             fft_data{isubject, 4).weightedamplitude(maxelec)]);
    
    
    % add these values to a large running variable
    stim_16_maxelec(isubject, 1) = fft_data{isubject, 1}.weightedamplitude(maxelec);
    stim_32_maxelec(isubject, 1) = fft_data{isubject, 2}.weightedamplitude(maxelec);
    stim_64_maxelec(isubject, 1) = fft_data{isubject, 3}.weightedamplitude(maxelec);
    stim_100_maxelec(isubject, 1) = fft_data{isubject, 4}.weightedamplitude(maxelec);
    % now the crosselec estimate
    stim_16_allelec(isubject, 1) = fft_data{isubject, 1}.crosselecestimate;
    stim_32_allelec(isubject, 1) = fft_data{isubject, 2}.crosselecestimate;
    stim_64_allelec(isubject, 1) = fft_data{isubject, 3}.crosselecestimate;
    stim_100_allelec(isubject, 1) = fft_data{isubject, 4}.crosselecestimate;
    
    
%     % A quick plot
%     figure;
%     title(files(isubject).id);
%     for i = 1:numel(triggers)
%         subplot(4, 1, i);
%         plot(fft_data{isubject, i}.freq, fft_data{isubject, i}.snrall(~noisechannels, :));
%         % ylim([0, 25]);
%         xlim(cfg_fft.foilim);
%         % add text to identify channels
%         text(1.8 + zeros(size(fft_data{isubject, 1).label)),...
%              fft_data{isubject, i}.snrall(:, find(fft_data{isubject, i}.freq>=1.8, 1)),...
%              fft_data{isubject, i}.label);
%     end
% 
%     % topoplot
%     figure;
%     for i = 1:numel(triggers)
%         tmp_data = fft_data{isubject, i};
%         subplot(2, 2, i);
%         cfg = [];
%         cfg.parameter = 'weightedamplitude';
%         tmp_data.weightedamplitude = repmat(tmp_data.weightedamplitude, 1, 2);
%         tmp_data.freq = [4.9, 5.1];
%         cfg.layout = 'biosemi64.lay';
%         cfg.channel = tmp_data.label(~noisechannels);
%         ft_topoplotTFR(cfg, tmp_data);
%     end
%     drawnow;
    % update progress bar
    progressbar(isubject/numel(files));
end

% write data so far to file
ids = {files(:).id}';
allresults = table(ids, stim_16_maxelec, stim_32_maxelec, stim_64_maxelec, stim_100_maxelec,...
                    stim_16_allelec, stim_32_allelec, stim_64_allelec, stim_100_allelec);
writetable(allresults, [date, '-allresults.csv'], 'Delimiter', ',')

% Create an average topoplot
cfg_grandav = [];
cfg_grandav.keepindividual = 'no';
cfg_grandav.parameter = {'weightedamplitude', 'snrstimfreq'};
cfg_grandav.foilim = repmat(fft_data{isubject, i}.freq(1), 1, 2);

for i = 1:numel(triggers)
    grandav_data{i} = ft_freqgrandaverage(cfg_grandav, fft_data{:, i});
    
    subplot(2, 2, i);
    cfg = [];
    cfg.parameter = 'weightedamplitude';
%     tmp_data.weightedamplitude = repmat(tmp_data.weightedamplitude, 1, 2);
%     tmp_data.freq = [4.9, 5.1];
    cfg.layout = 'biosemi64.lay';
    cfg.channel = grandav_data{i}.label(~noisechannels);
%     cfg.zlim = [0, 4];
    ft_topoplotTFR(cfg, grandav_data{i});
end