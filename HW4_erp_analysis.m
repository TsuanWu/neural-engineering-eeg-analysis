%% CSV 檔案導入 MATLAB 並轉換為 EEG 結構

% 讀取 CSV 檔案
data = readmatrix('erp1_122210.csv', 'NumHeaderLines', 11);

% 提取數據中的時間與通道數據
time = data(:, 1); % 第一列為時間 (Timestamp)
channels = data(:, 3:6); % 第 3 至第 6 列為通道數據 (Fz, Pz, O1, O2)

channels = channels'; % 將數據轉置為 [4 x 150300]

% 檢查數據維度
size(channels) % 確認是否為 [N x 4] 的矩陣結構

% 為通道命名
chanlocs_labels = {'Fz', 'Pz', 'O1', 'O2'};

% 初始化通道位置結構
chanlocs = struct('labels', chanlocs_labels, 'X', [], 'Y', [], 'Z', []);

% 採樣頻率
Fs = 1000; % 根據描述，采樣頻率為 1000 Hz

% 建立 EEG 結構
EEG = pop_importdata('dataformat', 'array', 'data', channels, ...
    'setname', 'CSV_import', 'srate', Fs, 'nbchan', 4);
%% 

% 手動設置通道名稱
for i = 1:4
    EEG.chanlocs(i).labels = chanlocs_labels{i};
end

% 設置參考通道（可選）
EEG = pop_reref(EEG, []); % 使用平均參考

%%
% 檢查並修正 EEG 結構
EEG = eeg_checkset(EEG);

%% 定義事件與分段 (Epoching)

% 定義事件
num_trials = 101;
event_interval = 1.48; % 單位為秒
for i = 1:num_trials
    EEG.event(i).type = 'Stimulus'; % 標記事件類型
    EEG.event(i).latency = (i-1) * event_interval * EEG.srate + 1; % 事件起點 (以樣本為單位)
end

% 新增：為事件添加數字代碼
for i = 1:length(EEG.event)
    EEG.event(i).code = 1; % 為每個事件添加數字代碼，例如 '1'
    EEG.event(i).type = 'S1'; % 將事件類型設置為 'S1'
end

EEG = eeg_checkset(EEG);

% 分段數據
EEG = pop_epoch(EEG, {'S1'}, [-0.1 1.48]); % 包括刺激前 100 ms 和刺激後 1.48 秒
EEG = eeg_checkset(EEG);

% 保存未處理的數據 (保留才能比較)
preprocessed_EEG = EEG; 

%%
% 將事件分為「目標條件」和「非目標條件」
for i = 1:num_trials
    if mod(i, 5) == 0 % 每 5 次刺激為目標條件
        EEG.event(i).type = 'Target'; % 設置目標條件
    else
        EEG.event(i).type = 'NonTarget'; % 設置非目標條件
    end
end
EEG = eeg_checkset(EEG);

%% 前處理

% 濾波：帶通濾波 (0.1–50 Hz)
EEG = pop_eegfiltnew(EEG, 0.1, 50);

% 基線校正：刺激前 100 ms 作為基線
EEG = pop_rmbase(EEG, [-100 0]);
%% 檢查

EEG.nbchan       % 應返回 4，表示 4 個通道
size(EEG.data)   % 應返回 [4 x 時間點數 x 試次]，例如 [4 x 150300]
length(EEG.event) % 應返回 110，表示事件數
unique({EEG.event.type}) % 應返回 {'S1'} 或其他正確的事件類型

EEG.trials       % 應返回試次數，例如 100
EEG.pnts         % 每段的時間點數，例如 1580
EEG.xmin         % 應返回 -0.1（刺激前 100 ms）
EEG.xmax         % 應返回 1.48（刺激後 1.48 秒）


% 保存處理後數據
pop_saveset(EEG, 'filename', 'preprocessed_data.set');

%% 繪圖部分

% Step 1. 計算平均 ERP
ERP = mean(EEG.data, 3); % 對所有試次求平均
time_points = linspace(EEG.xmin * 1000, EEG.xmax * 1000, EEG.pnts); % 時間軸 (毫秒)

% 計算 P1、N1 和 P300 的振幅與延遲（以 Fz 通道為例）
channel_idx = 1; % 以 Fz 通道為例
% P1
[P1_amp, P1_idx] = max(ERP(channel_idx, time_points >= 80 & time_points <= 130));
P1_latency = time_points(time_points >= 80 & time_points <= 130);
P1_latency = P1_latency(P1_idx);

% N1
[N1_amp, N1_idx] = min(ERP(channel_idx, time_points >= 100 & time_points <= 150));
N1_latency = time_points(time_points >= 100 & time_points <= 150);
N1_latency = N1_latency(N1_idx);

% P300
[P300_amp, P300_idx] = max(ERP(channel_idx, time_points >= 300 & time_points <= 500));
P300_latency = time_points(time_points >= 300 & time_points <= 500);
P300_latency = P300_latency(P300_idx);

% 顯示結果
disp(['P1: Amplitude = ', num2str(P1_amp), ', Latency = ', num2str(P1_latency), ' ms']);
disp(['N1: Amplitude = ', num2str(N1_amp), ', Latency = ', num2str(N1_latency), ' ms']);
disp(['P300: Amplitude = ', num2str(P300_amp), ', Latency = ', num2str(P300_latency), ' ms']);


% Step 2. 繪製每個通道的 ERP，拆分為 P1、N1 和 P300 圖
for i = 1:EEG.nbchan
    % P1 圖
    figure;
    plot(time_points, ERP(i, :), 'b');
    hold on;
    plot(100, ERP(i, find(time_points >= 100, 1)), 'ro'); % P1
    title(['P1 for Channel: ', EEG.chanlocs(i).labels]);
    xlabel('Time (ms)');
    ylabel('Amplitude (μV)');
    legend('ERP', 'P1');
    hold off;
    saveas(gcf, ['Channel_' EEG.chanlocs(i).labels '_P1.png']);

    % N1 圖
    figure;
    plot(time_points, ERP(i, :), 'b');
    hold on;
    plot(200, ERP(i, find(time_points >= 200, 1)), 'go'); % N1
    title(['N1 for Channel: ', EEG.chanlocs(i).labels]);
    xlabel('Time (ms)');
    ylabel('Amplitude (μV)');
    legend('ERP', 'N1');
    hold off;
    saveas(gcf, ['Channel_' EEG.chanlocs(i).labels '_N1.png']);

    % P300 圖
    figure;
    plot(time_points, ERP(i, :), 'b');
    hold on;
    plot(300, ERP(i, find(time_points >= 300, 1)), 'mo'); % P300
    title(['P300 for Channel: ', EEG.chanlocs(i).labels]);
    xlabel('Time (ms)');
    ylabel('Amplitude (μV)');
    legend('ERP', 'P300');
    hold off;
    saveas(gcf, ['Channel_' EEG.chanlocs(i).labels '_P300.png']);
end

% Step 3. 為每個通道生成比較圖
% 計算目標和非目標條件的平均 ERP
target_ERP = mean(EEG.data(:, :, strcmp({EEG.event.type}, 'Target')), 3);
nontarget_ERP = mean(EEG.data(:, :, strcmp({EEG.event.type}, 'NonTarget')), 3);

% 繪製目標與非目標條件的比較圖
for i = 1:EEG.nbchan
    figure;
    plot(time_points, target_ERP(i, :), 'r', 'DisplayName', 'Target');
    hold on;
    plot(time_points, nontarget_ERP(i, :), 'b', 'DisplayName', 'NonTarget');
    title(['Comparison of Target and Non-Target ERP for ', EEG.chanlocs(i).labels]);
    xlabel('Time (ms)');
    ylabel('Amplitude (μV)');
    legend;
    hold off;

    % 保存圖像
    saveas(gcf, ['Target_vs_NonTarget_' EEG.chanlocs(i).labels '.png']);
end


% Step 4. 保存數據與圖像
pop_saveset(EEG, 'filename', 'final_preprocessed_data.set');