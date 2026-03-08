clear all
close all
%% 
% *EEG analysis template*
% 
% Step1: load data

opts = detectImportOptions('1104_3_112635.csv'); % 自動偵測匯入選項
opts.DataLines = 12;                            % 資料從第 12 行開始
opts.VariableNamesLine = 11;                    % 變數名稱在第 11 行
file = readtable('1104_3_112635.csv', opts);
%% 
% Step2: Organize information

data = file{:, 3:8}'; % 提取 C3 ~ F4 資料，轉置成 (通道 x 時間點)
eventid = file.SoftwareMarker; % 事件標記

% 找出所有 33024 的索引位置
event_indices = find(eventid == "33024");

% 定義分段範圍
first_index = event_indices(1); % 第一個 33024

% 分段資料
eegrest = data(:, 1:first_index-1);             % rest: 0 到第一個 33024 之前
eegmove = data(:, first_index:first_index+8647); % move: 第一個 33024 開始的 8.648 秒 (8648 點)

figure;
subplot(2,1,1);
plot(eegrest');
title('Original Rest Data');
subplot(2,1,2);
plot(eegmove');
title('Original Move Data');
%% Step 3: 前處理

sample_rate = 1000; % 取樣率

% 1. 減去平均值
eegrest_mm = eegrest - mean(eegrest, 2);
eegmove_mm = eegmove - mean(eegmove, 2);

figure;
subplot(2,1,1);
plot(eegrest_mm');
title('Rest Data After Mean Removal');
subplot(2,1,2);
plot(eegmove_mm');
title('Move Data After Mean Removal');
%%
% 2. 去趨勢
for i = 1:size(data, 1) % 逐通道處理
    eegrest_de(i, :) = detrend(eegrest_mm(i, :));
    eegmove_de(i, :) = detrend(eegmove_mm(i, :));
end

figure;
subplot(2,1,1);
plot(eegrest_de');
title('Rest Data After Detrending');
subplot(2,1,2);
plot(eegmove_de');
title('Move Data After Detrending');
%%
% 3. Notch Filter (60Hz)
notch_default = designfilt('bandstopiir', 'FilterOrder', 4, ...
    'HalfPowerFrequency1', 59, 'HalfPowerFrequency2', 61, ...
    'DesignMethod', 'butter', 'SampleRate', sample_rate);
for i = 1:size(data, 1)
    eegrest_no(i, :) = filtfilt(notch_default, eegrest_de(i, :));
    eegmove_no(i, :) = filtfilt(notch_default, eegmove_de(i, :));
end

figure;
subplot(2,1,1);
plot(eegrest_no');
title('Rest Data After Notch Filtering');
subplot(2,1,2);
plot(eegmove_no');
title('Move Data After Notch Filtering');
%%
% 4. Band-pass Filter (0.5–50 Hz)
bp_filter = designfilt('bandpassiir', 'FilterOrder', 4, ...
    'PassbandFrequency1', 0.5, 'PassbandFrequency2', 50, ...
    'SampleRate', sample_rate);
for i = 1:size(data, 1)
    eegrest_bp(i, :) = filtfilt(bp_filter, eegrest_no(i, :));
    eegmove_bp(i, :) = filtfilt(bp_filter, eegmove_no(i, :));
end

figure;
subplot(2,1,1);
plot(eegrest_bp');
title('Rest Data After Band-pass Filtering');
subplot(2,1,2);
plot(eegmove_bp');
title('Move Data After Band-pass Filtering');
%% Step 4: 頻譜分析 (STFT)

% Step 1: 定義頻率波段
freq_bands = {
    'Delta (0.5-4 Hz)', [0.5 4];
    'Theta (4-8 Hz)',   [4 8];
    'Alpha (8-13 Hz)',  [8 13];
    'Beta (13-32 Hz)',  [13 32];
    'Gamma (32-100 Hz)',[32 100]
};

% Step 2: STFT 分析和繪圖
window_size = 500; % 視窗大小
overlap = window_size - 33; % 重疊
nfft = 1000; % FFT 點數

% 分析 eegmove
for b = 1:size(freq_bands, 1)
    band_name = freq_bands{b, 1};
    freq_range = freq_bands{b, 2};
    
    % 計算 STFT
    [S, f, t] = spectrogram(eegmove_bp(1, :), hamming(window_size), overlap, nfft, sample_rate);
    S_dB = 10 * log10(abs(S));
    
    % 找出指定頻率範圍
    f_indices = find(f >= freq_range(1) & f <= freq_range(2));
    
    % 繪製頻譜圖
    figure;
    pcolor(t, f(f_indices), S_dB(f_indices, :));
    shading interp;
    axis xy;
    colormap(jet);
    colorbar;
    title(['Action: ' band_name]);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
end

% 分析 eegrest
for b = 1:size(freq_bands, 1)
    band_name = freq_bands{b, 1};
    freq_range = freq_bands{b, 2};
    
    % 計算 STFT
    [S, f, t] = spectrogram(eegrest_bp(1, :), hamming(window_size), overlap, nfft, sample_rate);
    S_dB = 10 * log10(abs(S));
    
    % 找出指定頻率範圍
    f_indices = find(f >= freq_range(1) & f <= freq_range(2));
    
    % 繪製頻譜圖
    figure;
    pcolor(t, f(f_indices), S_dB(f_indices, :));
    shading interp;
    axis xy;
    colormap(jet);
    colorbar;
    title(['Rest: ' band_name]);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
end

%%
% 將 EEG 數據載入 EEGLab
EEG = pop_importdata('dataformat', 'array', 'nbchan', 6, ...
    'data', eegmove_bp, 'setname', 'eegmove_data', 'srate', 1000, 'pnts', 0, 'xmin', 0);
EEG = eeg_checkset(EEG);

% 設定通道名稱
EEG.chanlocs = struct('labels', {'C3', 'Cz', 'C4', 'F3', 'Fz', 'F4'}); % 通道標籤
EEG = eeg_checkset(EEG);

% 載入標準通道位置文件
EEG = pop_chanedit(EEG, 'lookup','ch32.ced');
EEG = eeg_checkset(EEG);

% 儲存 EEG 資料集 (可選)
pop_saveset(EEG, 'filename', 'eegmove_new_data.set', 'filepath', './');

%% 製作bar chart

% Step 1: 設定頻率波段
freq_bands = {'Delta (0.5-4 Hz)', 'Theta (4-8 Hz)', 'Alpha (8-13 Hz)', ...
              'Beta (13-32 Hz)', 'Gamma (32-100 Hz)'}; % 頻率波段名稱
freq_ranges = [0.5 4; 4 8; 8 13; 13 32; 32 100]; % 頻率範圍 (Hz)

% Step 2: 計算功率
N = size(eegmove_bp, 2); % 點數
freqs = (0:N/2) * (1000 / N); % 頻率軸 (Nyquist 頻率)
eegmove_fft = abs(fft(eegmove_bp, N, 2)); % FFT for Move
eegrest_fft = abs(fft(eegrest_bp, N, 2)); % FFT for Rest

% 初始化功率計算
power_move = zeros(length(freq_bands), size(eegmove_bp, 1)); % move 的功率
power_rest = zeros(length(freq_bands), size(eegrest_bp, 1)); % rest 的功率

% 計算每個波段的功率
for b = 1:length(freq_bands)
    % 找出頻率範圍的索引
    band_indices = freqs >= freq_ranges(b, 1) & freqs <= freq_ranges(b, 2);

    % 計算功率 (均方值)
    power_move(b, :) = mean(eegmove_fft(:, band_indices).^2, 2);
    power_rest(b, :) = mean(eegrest_fft(:, band_indices).^2, 2);
end

% Step 3: 平均各通道的功率
mean_power_move = mean(power_move, 2); % 每個波段 Move 狀態平均功率
mean_power_rest = mean(power_rest, 2); % 每個波段 Rest 狀態平均功率

% Step 4: 繪製 Bar Chart
figure;
bar_data = [mean_power_rest, mean_power_move]; % 組合 Rest 和 Move 的功率
bar(bar_data);
set(gca, 'xticklabel', freq_bands); % x 軸標籤設定
legend({'Rest', 'Move'});
ylabel('Power (\muV^2)');
title('Power Comparison Across Frequency Bands');