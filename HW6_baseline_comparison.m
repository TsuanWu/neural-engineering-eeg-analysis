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
first_index = event_indices(1);
second_index = event_indices(2);
third_index = event_indices(3);
fourth_index = event_indices(4);

% 分段資料
eeg_segment_1 = data(:, first_index:second_index-1);  % 第一段: 第1個33024到第2個33024之間
eeg_segment_2 = data(:, third_index:fourth_index-1);  % 第二段: 第3個33024到第4個33024之間

figure;
subplot(2,1,1);
plot(eeg_segment_1');
title(['Original data of 1st baseline interval']);
subplot(2,1,2);
plot(eeg_segment_2');
title('Original data of 3rd baseline interval');

%% Step 3: 前處理

sample_rate = 1000; % 取樣率

% 1. 減去平均值
eeg_segment_1_mm = eeg_segment_1 - mean(eeg_segment_1, 2);
eeg_segment_2_mm = eeg_segment_2 - mean(eeg_segment_2, 2);

figure;
subplot(2,1,1);
plot(eeg_segment_1_mm');
title('1st baseline interval data After Mean Removal');
subplot(2,1,2);
plot(eeg_segment_2_mm');
title('3rd baseline interval data After Mean Removal');
%%
% 2. 去趨勢
for i = 1:size(data, 1) % 逐通道處理
    eeg_segment_1_de(i, :) = detrend(eeg_segment_1_mm(i, :));
    eeg_segment_2_de(i, :) = detrend(eeg_segment_2_mm(i, :));
end

figure;
subplot(2,1,1);
plot(eeg_segment_1_de');
title('1st baseline interval data After Detrending');
subplot(2,1,2);
plot(eeg_segment_2_de');
title('3rd baseline interval data After Detrending');
%%
% 3. Notch Filter (60Hz)
notch_default = designfilt('bandstopiir', 'FilterOrder', 4, ...
    'HalfPowerFrequency1', 59, 'HalfPowerFrequency2', 61, ...
    'DesignMethod', 'butter', 'SampleRate', sample_rate);
for i = 1:size(data, 1)
    eeg_segment_1_no(i, :) = filtfilt(notch_default, eeg_segment_1_de(i, :));
    eeg_segment_2_no(i, :) = filtfilt(notch_default, eeg_segment_2_de(i, :));
end

figure;
subplot(2,1,1);
plot(eeg_segment_1_no');
title('1st baseline interval data After Notch Filtering');
subplot(2,1,2);
plot(eeg_segment_2_no');
title('3rd baseline interval data After Notch Filtering');
%%
% 4. Band-pass Filter (0.5–50 Hz)
bp_filter = designfilt('bandpassiir', 'FilterOrder', 4, ...
    'PassbandFrequency1', 0.5, 'PassbandFrequency2', 50, ...
    'SampleRate', sample_rate);
for i = 1:size(data, 1)
    eeg_segment_1_bp(i, :) = filtfilt(bp_filter, eeg_segment_1_no(i, :));
    eeg_segment_2_bp(i, :) = filtfilt(bp_filter, eeg_segment_2_no(i, :));
end


figure;
subplot(2,1,1);  %設定子圖的大小 (行, 列, 第幾張圖) 
plot(eeg_segment_1_bp');
title('1st baseline interval data After Band-pass Filtering');
subplot(2,1,2);
plot(eeg_segment_2_bp');
title('3rd baseline interval data After Band-pass Filtering');
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
nfft = 1000; % FFT 點數(通常建議是2^n且值越大，演算速度最快)

for b = 1:size(freq_bands, 1)
    band_name = freq_bands{b, 1};
    freq_range = freq_bands{b, 2};
    
    % Segment 1
    [S1, f1, t1] = spectrogram(eeg_segment_1_bp(1, :), hamming(window_size), overlap, nfft, sample_rate);
    S1_dB = 10 * log10(abs(S1));
    f_indices1 = find(f1 >= freq_range(1) & f1 <= freq_range(2));
    figure;
    pcolor(t1, f1(f_indices1), S1_dB(f_indices1, :));
    shading interp;
    axis xy;
    colormap(jet);
    colorbar;
    title(['Segment 1: ' band_name]);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');

    % Segment 2
    [S2, f2, t2] = spectrogram(eeg_segment_2_bp(1, :), hamming(window_size), overlap, nfft, sample_rate);
    S2_dB = 10 * log10(abs(S2));
    f_indices2 = find(f2 >= freq_range(1) & f2 <= freq_range(2));
    figure;
    pcolor(t2, f2(f_indices2), S2_dB(f_indices2, :));
    shading interp;
    axis xy;
    colormap(jet);
    colorbar;
    title(['Segment 2: ' band_name]);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
end
%%
% Step 5: 更新 EEG 結構變數
EEG1 = pop_importdata('dataformat', 'array', 'nbchan', 6, ...
    'data', eeg_segment_1_bp, 'setname', 'eeg_segment_1_data', 'srate', 1000, 'pnts', 0, 'xmin', 0);
EEG1 = eeg_checkset(EEG1);

EEG2 = pop_importdata('dataformat', 'array', 'nbchan', 6, ...
    'data', eeg_segment_2_bp, 'setname', 'eeg_segment_2_data', 'srate', 1000, 'pnts', 0, 'xmin', 0);
EEG2 = eeg_checkset(EEG2);

% 設定通道名稱
EEG1.chanlocs = struct('labels', {'C3', 'Cz', 'C4', 'F3', 'Fz', 'F4'}); % 通道標籤
EEG2.chanlocs = struct('labels', {'C3', 'Cz', 'C4', 'F3', 'Fz', 'F4'}); % 通道標籤
EEG1 = eeg_checkset(EEG1);
EEG2 = eeg_checkset(EEG2);

% 載入標準通道位置文件
EEG1 = pop_chanedit(EEG1, 'lookup', 'ch32.ced');
EEG2 = pop_chanedit(EEG2, 'lookup', 'ch32.ced');
EEG1 = eeg_checkset(EEG1);
EEG2 = eeg_checkset(EEG2);

% 儲存 EEG 資料集 (可選)
pop_saveset(EEG1, 'filename', 'Segment1_data.set', 'filepath', './');
pop_saveset(EEG2, 'filename', 'Segment2_data.set', 'filepath', './');
%%
% 製作 Bar Chart 比較
% Step 1: 設定頻率波段
freq_bands = {'Delta (0.5-4 Hz)', 'Theta (4-8 Hz)', 'Alpha (8-13 Hz)', ...
              'Beta (13-32 Hz)', 'Gamma (32-100 Hz)'}; % 頻率波段名稱
freq_ranges = [0.5 4; 4 8; 8 13; 13 32; 32 100]; % 頻率範圍 (Hz)

% Step 2: 計算功率
% 獲取數據點數
N1 = size(eeg_segment_1_bp, 2); % Segment 1 樣本數
N2 = size(eeg_segment_2_bp, 2); % Segment 2 樣本數
Fs = sample_rate; % 取樣頻率

% 計算頻率軸 (只保留非負頻率部分)
freqs1 = linspace(0, Fs / 2, floor(N1 / 2) + 1);
freqs2 = linspace(0, Fs / 2, floor(N2 / 2) + 1);

% 計算 FFT 結果並裁剪 (只保留非負頻率部分)
eeg1_fft = abs(fft(eeg_segment_1_bp, N1, 2));
eeg1_fft = eeg1_fft(:, 1:floor(N1 / 2) + 1); % Segment 1

eeg2_fft = abs(fft(eeg_segment_2_bp, N2, 2));
eeg2_fft = eeg2_fft(:, 1:floor(N2 / 2) + 1); % Segment 2

% 確認頻率軸與 FFT 結果的長度，需為FFT 結果的長度(N)/2 +1
disp(['Segment 1 頻率軸長度: ', num2str(length(freqs1))]);
disp(['Segment 1 FFT 結果長度: ', num2str(size(eeg1_fft, 2))]);

disp(['Segment 2 頻率軸長度: ', num2str(length(freqs2))]);
disp(['Segment 2 FFT 結果長度: ', num2str(size(eeg2_fft, 2))]);


% 初始化功率計算
power_segment_1 = zeros(length(freq_bands), size(eeg_segment_1_bp, 1));
power_segment_2 = zeros(length(freq_bands), size(eeg_segment_2_bp, 1));

% 計算每個波段的功率
for b = 1:length(freq_bands)
    % 找出頻率範圍的索引 (Segment 1 和 Segment 2)
    band_indices_1 = freqs1 >= freq_ranges(b, 1) & freqs1 <= freq_ranges(b, 2);
    band_indices_2 = freqs2 >= freq_ranges(b, 1) & freqs2 <= freq_ranges(b, 2);

    % 計算功率 (均方值)
    power_segment_1(b, :) = mean(eeg1_fft(:, band_indices_1).^2, 2);
    power_segment_2(b, :) = mean(eeg2_fft(:, band_indices_2).^2, 2);
end

% Step 3: 平均各通道的功率
mean_power_segment_1 = mean(power_segment_1, 2); % 每個波段 Segment 1 平均功率
mean_power_segment_2 = mean(power_segment_2, 2); % 每個波段 Segment 2 平均功率

% Step 4: 獨立繪製 Bar Chart
% Segment 1
figure;
bar(mean_power_segment_1, 'FaceColor', [0.2 0.6 0.8]); % 使用單一顏色
set(gca, 'xticklabel', freq_bands); % x 軸標籤設定
ylabel('Power (\muV^2)');
title('Power Across Frequency Bands (Segment 1)');

% Segment 3
figure;
bar(mean_power_segment_2, 'FaceColor', [0.8 0.4 0.2]); % 使用另一顏色
set(gca, 'xticklabel', freq_bands); % x 軸標籤設定
ylabel('Power (\muV^2)');
title('Power Across Frequency Bands (Segment 2)')
figure;
bar_data = [mean_power_segment_1, mean_power_segment_2]; % 組合 Segment 1 和 Segment 2 的功率
bar(bar_data);
set(gca, 'xticklabel', freq_bands); % x 軸標籤設定
legend({'Segment 1', 'Segment 2'});
ylabel('Power (\muV^2)');
title('Power Comparison Across Frequency Bands');