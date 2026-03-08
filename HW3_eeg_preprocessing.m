%% restart

clear;
clc;
%% load data

filename = "1104_1_112001.csv";

% read table as df
df = readtable(filename);

% info
var = df.Properties.VariableNames;

raw = df{:,var(3:8)};
eventid= df.SoftwareMarker;
startMark = find(eventid == 33024, 1, 'first');
endMark = find(eventid == 33025, 1, 'first');

% data clip
sampleRate=1000;
eg=raw(startMark:endMark,:);
eg=eg';
time = linspace(1/sampleRate, length(eg)/sampleRate, length(eg));

% 視覺化數據，檢查提取的數據是否包含標誌點，繪製提取範圍內的信號
figure;
plot(time, eg(1, :)); % 繪製第 1 通道的提取信號
hold on;
xline((find(eventid == 33024) - startMark) / sampleRate, '--r', 'Start Mark'); % 標誌起點
xline((find(eventid == 33025) - startMark) / sampleRate, '--g', 'End Mark'); % 標誌終點
hold off;
title('Extracted Signal with Event Markers');
xlabel('Time (s)');
ylabel('Voltage (\muV)');
grid on;

%% minus mean

eg_mm= zeros(size(eg));
for i = 1:size(eg,1)
    meanva=mean(eg(i,:));
    eg_mm(i,:) = eg(i,:)-meanva;
end
figure;
hold on
plot(time,eg(1,:));
plot(time,eg_mm(1,:));
hold off
title(var{1+2});
%% Detrending

eg_de= zeros(size(eg));
for i = 1:size(eg,1)
    eg_de(i,:) = detrend(eg_mm(i,:));
end
figure;
hold on
plot(time,eg_mm(1,:));
plot(time,eg_de(1,:));
hold off
title(var{1+2});
%% Notch filter

% 設置 Notch filter
notch_default = designfilt('bandstopiir','FilterOrder',4,...
    'HalfPowerFrequency1',59,'HalfPowerFrequency2',61,...
    'DesignMethod','butter','SampleRate',sampleRate);
[b,a] = tf(notch_default);
eg_no= zeros(size(eg));
for i= 1:size(eg_de,1)
    eg_no(i,:) = filtfilt(b,a,eg_de(i,:));
end

% 初始化濾波後的數據
eg_no = zeros(size(eg));
for i = 1:size(eg_de, 1)
    eg_no(i, :) = filtfilt(b, a, eg_de(i, :)); % 應用 Notch filter
end

% 計算第1通道（C3）的頻譜
[pxx_orig, f] = pwelch(eg(1, :), 500, 300, [], sampleRate); % 原始信號頻譜
[pxx_filtered, f] = pwelch(eg_no(1, :), 500, 300, [], sampleRate); % 濾波後頻譜

% 繪製比較圖 Frequency v.s. Power (有無Notch filter)
figure;
hold on;
plot(f, 10*log10(pxx_orig), 'b', 'DisplayName', 'Before Notch Filter'); % 未濾波
plot(f, 10*log10(pxx_filtered), 'r', 'DisplayName', 'After Notch Filter'); % 濾波後
hold off;

% 圖表標題與標籤
title('Frequency vs. Power (C3 Channel)');
xlabel('Frequency (Hz)');
ylabel('Power Spectral Density (dB)');
legend('Location', 'northeast');
grid on;


% 計算和繪製原始信號的頻譜
figure;
subplot(2,1,1);
[pxx, f] = pwelch(eg(1, :), 500, 300, [], sampleRate); % 計算功率譜
plot(f, 10*log10(pxx));
title('原始信號的頻譜');
xlabel('頻率 (Hz)');
ylabel('功率譜密度 (dB)');
grid on;

% 計算和繪製濾波後信號的頻譜
subplot(2,1,2);
[pxx_no, f] = pwelch(eg_no(1, :), 500, 300, [], sampleRate); % 計算濾波後的功率譜
plot(f, 10*log10(pxx_no));
title('濾波後信號的頻譜');
xlabel('頻率 (Hz)');
ylabel('功率譜密度 (dB)');
grid on;

% 定義參數
num_channels = size(eg, 1); % 通道數
sampleRate = 1000; % 采樣頻率 (Hz)

% 通道名稱
channel_names = {'C3', 'Cz', 'C4', 'F3', 'Fz', 'F4'}; % 修改為你的通道名稱

% 初始化頻譜數據存儲
psd_orig = cell(num_channels, 1); % 原始信號頻譜
psd_filtered = cell(num_channels, 1); % 濾波後信號頻譜
freq = []; % 頻率軸

% 計算頻譜
for ch = 1:num_channels
    % 原始信號的頻譜
    [pxx_orig, f] = pwelch(eg(ch, :), 500, 300, [], sampleRate); % 使用 sampleRate
    psd_orig{ch} = 10*log10(pxx_orig); % 轉為 dB
    freq = f; % 頻率軸

    % 濾波後信號的頻譜
    [pxx_filtered, ~] = pwelch(eg_no(ch, :), 500, 300, [], sampleRate); % 使用 sampleRate
    psd_filtered{ch} = 10*log10(pxx_filtered); % 轉為 dB
end

% 繪製頻譜圖
figure;
hold on;
for ch = 1:num_channels
    plot(freq, psd_filtered{ch}, 'LineWidth', 1.2); % 繪製濾波後的每個通道頻譜
end
hold off;
xlabel('Frequency (Hz)');
ylabel('Log Power Spectral Density (10*log10(\muV^2/Hz))');
title('Filtered Signal Power Spectra (Notch Filter)');
grid on;

% 使用自定義通道名稱作為圖例
legend(channel_names, 'Location', 'northeast');


%% Power spectral density

% FFT
data_length= length(eg_no);
t = (0:data_length-1)/sampleRate;

fft_no = fft(eg_no')';
fft_de = fft(eg_de')';

freq = (0:data_length-1)*sampleRate/data_length;
nyquist = floor(data_length/2)+1;

% plot psd

% figure;
% subplot(2,1,1)
% plot(freq(1:nyquist),abs(fft_de(1:nyquist)))
% 
% subplot(2,1,2)
% plot(freq(1:nyquist),abs(fft_no(1:nyquist)))

figure;
hold on
plot(freq(1:nyquist),abs(fft_de(1:nyquist)))
plot(freq(1:nyquist),abs(fft_no(1:nyquist)))
hold off
%% Band-pass filter

% 設置 Bandpass 濾波器參數
order = 4; 
freq_band = [0.5 50]; % 設定 Bandpass 頻率範圍
bandpass_default = designfilt('bandpassiir', 'FilterOrder', order, ...
    'HalfPowerFrequency1', freq_band(1), 'HalfPowerFrequency2', freq_band(2), ...
    'SampleRate', sampleRate);
[b, a] = tf(bandpass_default);

% 通道名稱
channel_names = {'C3', 'Cz', 'C4', 'F3', 'Fz', 'F6'};

% 應用 Bandpass 濾波器
eg_band = zeros(size(eg_no));
for i = 1:size(eg_no, 1)
    eg_band(i, :) = filtfilt(b, a, eg_no(i, :)); % 雙向濾波，避免相位偏移
end

% 計算頻譜 (以第1通道 C3 為例)
[pxx_no, f] = pwelch(eg_no(1, :), 500, 300, [], sampleRate); % 濾波前頻譜
[pxx_band, f] = pwelch(eg_band(1, :), 500, 300, [], sampleRate); % Bandpass 濾波後頻譜

% 計算電壓 (RMS)
voltage_no = sqrt(pxx_no); % 未濾波信號的電壓
voltage_band = sqrt(pxx_band); % Bandpass 濾波信號的電壓

% 圖1: 繪製比較圖 (有無 Bandpass filter)
figure;
hold on;
plot(f, voltage_no, 'b', 'LineWidth', 1.5, 'DisplayName', 'Before Bandpass Filter'); % 未濾波信號
plot(f, voltage_band, 'r', 'LineWidth', 1.5, 'DisplayName', 'After Bandpass Filter'); % 濾波後信號
hold off;

% 圖表標題與標籤
title('比較有無Bandpass Filter (C3 Channel)');
xlabel('Frequency (Hz)');
ylabel('Voltage (\muV)');
legend('Location', 'northeast');
grid on;

% 限制頻率範圍
xlim([0 60]); % 僅展示 0–60 Hz 範圍


% 圖2:繪製All Channels After Bandpass Filtering
% 初始化 Bandpass 濾波後的數據
eg_band = zeros(size(eg_no));
for i = 1:size(eg_no, 1) % 遍歷所有通道
    eg_band(i, :) = filtfilt(b, a, eg_no(i, :)); % 濾波
end

% 繪製所有通道的 Bandpass 信號
figure;
hold on;
for i = 1:size(eg_band, 1)
    plot(time, eg_band(i, :), 'DisplayName', channel_names{i}); % 繪製每個通道
end
hold off;

% 圖表標題與標籤
title('All Channels After Bandpass Filtering');
xlabel('Time (s)');
ylabel('Voltage (\muV)');
legend('Location', 'northeast'); % 添加圖例
grid on;


% 圖3:繪圖 (Coxmparison of Notch and Bandpass Filtering)
figure;
hold on;
plot(time, eg_no(1, :), 'b', 'DisplayName', 'Data after notch filter'); % Notch 濾波後
plot(time, eg_band(1, :), 'r', 'DisplayName', 'Data after bandpass filter'); % Bandpass 濾波後
hold off;

% 圖表標題與標籤
title('C3: Comparison of Notch and Bandpass Filtering'); % 更具描述性的標題
xlabel('Time (s)'); % x 軸標籤
ylabel('Voltage (\muV)'); % y 軸標籤
legend('Location', 'northeast'); % 圖例位置
grid on; % 添加網格線