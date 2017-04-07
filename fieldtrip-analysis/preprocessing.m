
%% Exported from Jupyter Notebook

%%
% # EEG Preprocessing Notebook
% 
% In this notebook I'll preprocess the data and create new files for resample, reref, etc.

%%
% ### Fresh start
% 
% Clear all and define required variables

%% Cell[1]:

% only run this cell if variables are messed up
clearvars;
ft_defaults;

%%
% ### Setup
% 
% The variables required to run this analysis. Always run this cell first, as it also generates the list of files for you!

%% Cell[ ]:

electrodes = 'all';
stimfreq = 5.0;

triggers = [16, 32, 64, 100];

trialdur = 10.0;
discardstart = 0.0;

% provide directory of the data files & naming pattern here
if exist('C:\EEG Data\cancan\', 'dir')
    filedir = 'C:\EEG Data\cancan\';
elseif exist('/data/group/FANS/cancan/eeg/', 'dir')
    filedir = '/data/group/FANS/cancan/eeg/';
end

files = dir([filedir, '*sat*.eeg']);

for isubject = 1:numel(files)
    files(isubject).id = regexprep(files(isubject).name, '(_)', '');
    [idstart, idend] = regexp(files(isubject).id, '(\d+)[ABCabc]');
    files(isubject).id = files(isubject).id(idstart:idend);
end

%%
% ### Data Analysis Step 1: Defining the trials
% 
% In this section, the trials are defined.

%% Cell[ ]:

%%capture
for isubject = 1:numel(files)
    clear prep_data cfg*
    
    
    % Trial Basics
    cfg_deftrials.dataset = fullfile(filedir, files(isubject).name);
    cfg_deftrials.trialdef.eventtype = 'Toggle';
    cfg_deftrials.trialfun = 'ft_trialfun_general';
    % Trial Timing
    cfg_deftrials.trialdef.prestim = -discardstart;
    cfg_deftrials.trialdef.poststim = trialdur;
    
    trl{isubject} = [];  % initialise to append
    for trigger = triggers
        cfg_deftrials.trialdef.eventvalue = sprintf('T% 3u', trigger);
        disp(sprintf('T% 3u', trigger))
        try
            tmp = ft_definetrial(cfg_deftrials);
        catch
            % If triggers are not as expected, skip subject
            continue
        end
        % Manually add the trigger code
        tmp.trl(:, 4) = trigger;
        trl{isubject} = vertcat(trl{isubject}, tmp.trl);
    end

end

%%
% ### Data Analysis Step 2: Resampling the data
% 
% In this section the data gets "preprocessed" only to the extent that it's snipped to the right length and resampled. In addition, a 50Hz filter and an extreme lowpass filter is applied.

%% Cell[ ]:

%%capture
for isubject = 1:numel(files)
    % Skip participant if no trials defined
    if isempty(trl{isubject})
        continue
    end
    
    % Define the config
    cfg{isubject} = [];
    % I/O
    cfg{isubject}.dataset = fullfile(filedir, files(isubject).name);
    cfg{isubject}.outputfile = [fullfile(filedir, files(isubject).name), '.resampled.mat'];
    % Details of the trial
    cfg{isubject}.trl = trl{isubject}; % previously defined
    cfg{isubject}.channel = electrodes; % defined above
    cfg{isubject}.demean = 'yes';  % Subtract mean within each trial
    cfg{isubject}.detrend = 'yes';  % equivalent to hi-pass filter
    cfg{isubject}.reref = 'no'; % done in step 3
    cfg{isubject}.lpfilter = 'yes'; % low pass filter
    cfg{isubject}.lpfreq = 25;
    
end

% Remove the empty cells so matlab doesn't have a stroke
cfg(cellfun(@isempty, cfg)) = [];
% Preprocess (in parallel)
peercellfun(@ft_preprocessing, cfg);

% Resample the data
cfg = [];
for isubject = 1:numel(files)
    
    if ~exist([fullfile(filedir, files(isubject).name), '.resampled.mat'], 'file')
        continue
    end
    
    
    cfg{isubject}.resamplefs = 250;
    cfg{isubject}.detrend = 'no';
    cfg{isubject}.inputfile = [fullfile(filedir, files(isubject).name), '.resampled.mat'];
    cfg{isubject}.outputfile = [fullfile(filedir, files(isubject).name), '.resampled.mat'];
end

% Remove the empty cells so matlab doesn't have a stroke
cfg(cellfun(@isempty, cfg)) = [];
% Resample (in parallel)
peercellfun(@ft_resampledata, cfg);


%%
% ### Preprocessing Step 3: Doing Preliminary frequency analysis
% 
% Here we do a preliminary FFT analysis, calculate the power in the frequency bands, and then class electrodes as noisy depending on their power spectrum.

%% Cell[ ]:

%%capture
for isubject = 1:numel(files)
    % Skip participant if no data exists so far
    if ~exist([fullfile(filedir, files(isubject).name), '.resampled.mat'], 'file')
        continue
    end
    
    % FFT analysis
    cfg = [];
    cfg.inputfile = [fullfile(filedir, files(isubject).name), '.resampled.mat'];
    cfg.output = 'pow';
    cfg.method = 'mtmfft';
    cfg.foilim = [1, 20];
    cfg.tapsmofrq = 1/(cfg_deftrials.trialdef.prestim + cfg_deftrials.trialdef.poststim);
    cfg.channel = electrodes;
    cfg.keeptrials = 'no';
    
    % Identify Noisy Channels
    noisechannels{isubject} = false([1, 32]);
    for i = 1:numel(triggers)
        % FFT analysis
        trigger = triggers(i);
        cfg.trials = trl{isubject}(:, 4)' == trigger;
        freq = ft_freqanalysis(cfg);
        
        % Extra SNR analysis
        freq.stimfreq = stimfreq;  % add the stimfreq
        freq.harmonics = 2;  % add the harmonic to analyse
        freq.noisebins = 20;

        snr_data = ssvep_calculate_snr(freq);
        snrspectrum = squeeze(permute(ssvep_calculate_all_snr(freq), [2, 3, 1]));
        
        % anything with crazy high SNRs is a flat channel
        noisechannels{isubject} = noisechannels{isubject} | ...
                        any(snrspectrum > 200, 2);
        % any channels with too much or too little power in the noise band is removed
        noisechannels{isubject} = noisechannels{isubject} | ...
                        snr_data.noisepow > 15 | snr_data.noisepow <= 0;
    end
end

clear freq, snr_data, snrspectrum

%%
% ### Preprocessing Step 5: Rereferencing
% 
% Now that we know where the noisy electrodes are, we can rereference without them.

%% Cell[ ]:

%%capture
assert(numel(noisechannels)==numel(files), 'did you run the prev cell for noisechannels?')
cfg = [];
for isubject = 1:numel(files)
    % Skip participant if no noisechannel data (was not processed in prev. cell)
    if isempty(noisechannels{isubject})
        continue
    end

    cfg{isubject}.inputfile = [fullfile(filedir, files(isubject).name), '.resampled.mat'];
    cfg{isubject}.outputfile = [fullfile(filedir, files(isubject).name), '.rereferenced.mat'];
    cfg{isubject}.reref = 'yes';
    cfg{isubject}.refchannel = fft_data{isubject, i}.label(~noisechannels{isubject});
    if numel(fft_data{isubject, i}.label) == 64; cfg{isubject}.channel = 33:64; end

end

% Remove the empty cells so matlab doesn't have a stroke
cfg(cellfun(@isempty, cfg)) = [];
% Do the preprocessing (parallel)
peercellfun(@ft_preprocessing, cfg);

%%
% ### Time / Frequency Analysis Step 1: Fourier Transfer
% 
% If you've already pre-processed data above (i.e. there is a file called `*rereferenced.mat` for every of your participants) you can jump straight in here.

%% Cell[ ]:

%%capture
cfg = [];
for isubject = 1:numel(files)
    % Skip participant if no data exists (probably no triggers)
    if ~exist([fullfile(filedir, files(isubject).name), '.rereferenced.mat'], 'file'), continue, end
    
    for i = 1:numel(triggers)
        cfg{isubject, i}.inputfile = [fullfile(filedir, files(isubject).name), '.rereferenced.mat'];
        cfg{isubject, i}.outputfile = [fullfile(filedir, files(isubject).name), '.fft_', num2str(i), '.mat'];
        cfg{isubject, i}.output = 'pow';
        cfg{isubject, i}.method = 'mtmfft';
        cfg{isubject, i}.foilim = [1, 20];
        cfg{isubject, i}.tapsmofrq = 1/(trialdur - discardstart);
        cfg{isubject, i}.channel = electrodes;
        cfg{isubject, i}.keeptrials = 'no';
        cfg{isubject, i}.trials = trl{isubject}(:, 4)' == triggers(i);
    end
end

% Remove any empty cells from cfg
cfg(cellfun(@isempty, cfg)) = [];
% Do the Freq analysis (in parallel)
peercellfun(@ft_freqanalysis, cfg);


% Append the data from the four separate freq analyses
cfg = [];
for isubject = 1:numel(files)
    % Skip participant if no data exists (probably no triggers)
    if ~exist([fullfile(filedir, files(isubject).name), '.rereferenced.mat'], 'file'), continue, end
    
    cfg{isubject}.outputfile = [fullfile(filedir, files(isubject).name), '.fft.mat'];
    cfg{isubject}.appenddim = 'rpt';
    cfg{isubject}.parameter = 'powspctrm';
    % Add the four separate input files created above
    for i = 1:numel(triggers)
        cfg{isubject}.inputfile{i} = [fullfile(filedir, files(isubject).name), '.fft_', num2str(i), '.mat'];
    end
end

peercellfun(@ft_appendfreq, cfg);

% Delete the 4 individual files we had previously
for isubject = 1:numel(files)
    for i = 1:numel(triggers)
        
    end
end


%%
% ### Time / Frequency analysis Step 2: Signal to noise ratios
% 
% 

%% Cell[ ]:

for isubject = 1:numel(files)
    
    if ~exist([fullfile(filedir, files(isubject).name), '.fft.mat'], 'file')
        continue
    else
        freq = getfield(load([fullfile(filedir, files(isubject).name), '.fft.mat']), 'freq');
    end
    
    freq.stimfreq = stimfreq;
    freq.harmonics = 2;
    freq.noisebins = 20;
    % Create the peak SNR values
    freq.snr = ssvep_calculate_snr(freq);
    % Create an SNR spectrum
    freq.snrspectrum = ssvep_calculate_all_snr(freq);
    
    % Set noisy electrodes to NaNs
    for i = 1:numel(triggers)
        % freq.powspctrm(i, noisechannels{isubject}, :) = NaN;
        freq.snr.snrstimfreq(i, noisechannels{isubject}, :) = NaN;
        freq.snr.snrspectrum(i, noisechannels{isubject}, :) = NaN;
    end
    
    % Save this data to file (overriding the previous freq structure with this one)
    save([fullfile(filedir, files(isubject).name), '.fft.mat'], 'freq');
end

%%
% ### Time / Frequency analysis Step 3: Combine the harmonics and electrodes
% 
% This uses the SNRs calculated earlier to work out the amplitude of the oscillations.

%% Cell[ ]:

%%capture
for isubject = 1:numel(files)
    
    if ~exist([fullfile(filedir, files(isubject).name), '.fft.mat'], 'file')
        continue
    else
        load([fullfile(filedir, files(isubject).name), '.fft.mat']);
    end
        
    % Calculate weighted amplitude
    freq.weightedamplitude = ssvep_combine_harmonic_amplitudes(freq);
    
    % calculate a weighted average by electrode
    freq.crosselecestimate = ssvep_combine_electrodes(freq);
    
    % Save the file again
    save([fullfile(filedir, files(isubject).name), '.fft.mat'], 'freq');
    
    % find the maximal signal electrode on average
    [~, maxelec] = max(mean(freq.snr.snrstimfreq(:, :), 1), [], 2);
end

%%
% ### Create a Results Table
% 
% The results from the previous three steps can be written to a CSV file in this loop.

%% Cell[ ]:

%%capture
data_maxelec = NaN([numel(files), numel(triggers)]);
data_allelec = NaN([numel(files), numel(triggers)]);
for isubject = 1:numel(files)
    
    if ~exist([fullfile(filedir, files(isubject).name), '.fft.mat'], 'file')
        continue
    else
        load([fullfile(filedir, files(isubject).name), '.fft.mat']);
    end
    
    [~, maxelec] = max(mean(freq.snr.snrstimfreq(:, :), 1), [], 2);
    data_maxelec(isubject, 1:4) = freq.weightedamplitude(1:4, maxelec);
    data_allelec(isubject, 1:4) = freq.crosselecestimate;
end

% Initialise a table
allresults = table();
allresults.ID = {files(:).id}';

% Add the data to the table
for i = 1:numel(triggers)
    allresults.(['maxelec_', num2str(triggers(i))]) = data_maxelec(:, i);
    allresults.(['allelec_', num2str(triggers(i))]) = data_allelec(:, i);
end

%%
% ### Write to file
% 
% Save the results table as a CSV file.

%% Cell[ ]:

writetable(allresults, [date, '-allresults.csv'], 'Delimiter', ',');

%%
% ### Final Analysis Step 1: Grand Average
% 
% 

%% Cell[ ]:

%%capture
cfg = [];
cfg.keepindividual = 'no';
cfg.parameter = {'powspctrm', 'weightedamplitude', 'snrspectrum'};

for isubject = 1:numel(files)
    % cfg.inputfile{isubject} = [fullfile(filedir, files(isubject).name), '.fft.mat'];
end

for i = 1:numel(triggers)
    cfg.trials = false([1, numel(triggers)]);
    cfg.trials(i) = true;
    cfg.avgoverrpt = 'yes';
    for isubject = 1:numel(files)
        fftdata{isubject} = getfield(load([fullfile(filedir, files(isubject).name), '.fft.mat']), 'freq');
        fftdata{isubject}.weightedamplitude = repmat(fftdata{isubject}.weightedamplitude, [1, 1, 191]);
        fftdata{isubject} = ft_selectdata(cfg, fftdata{isubject});
    end
    cfg.outputfile = fullfile(filedir, ['saturation_grandav_', num2str(triggers(i)), '.mat']);
    
    % remove empty cells (people who didn't have triggers)
    fftdata(cellfun('isempty', fftdata)) = [];
    % do the grand average
    ft_freqgrandaverage(cfg, fftdata{:});
end

%%
% ### Final Analysis Step 2: Topoplot of SNR
% 
% Check where the SNR is distributed

%% Cell[ ]:

%plot -s 800,800

figure;
cfg = [];
cfg.xlim = [4.9, 5.1];
cfg.parameter = 'weightedamplitude';
% cfg.zlim = [0, 5];
cfg.layout = 'biosemi64.lay';

for i = 1:numel(triggers)
    subplot(2, 2, i);
    data = getfield(load(fullfile(filedir, ['saturation_grandav_', num2str(triggers(i)), '.mat'])), 'grandavg');
    
    ft_topoplotTFR(cfg, data);
    colormap parula
end
