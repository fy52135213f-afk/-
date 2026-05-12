%% plot_curve.m — 线路平曲线独立绘图脚本  【v2 修正版】
%  适配 MATLAB R2024b | 配套 curve_calc.py（v2）导出的 curve_data.csv
%
%  【v2 修改说明】
%  ─────────────────────────────────────────────────────────────────────────
%  ★ 修正：控制点 A/B 坐标不再硬编码
%      旧：文件末尾手动填入 add_points = [137.806,305.018; ...]
%      新：从 CSV 中读取分类='线路控制点' 的行，自动获取 A/B 坐标
%      理由：Python 已将控制点 A/B 导出至 CSV，MATLAB 应直接读取，
%            避免手动维护两处数据导致不一致。
%  ─────────────────────────────────────────────────────────────────────────
%
%  使用方法：
%    1. 将本脚本与 curve_data.csv 放在同一文件夹
%    2. 直接运行，无需手动修改任何路径或坐标
%
%  CSV 原始字段（共 7 列，按顺序）：
%    里程 | 点类型 | 局部x | 局部y | 大地X | 大地Y | 分类
%
%  脚本内部统一重命名为：
%    Mileage_m | PtType | LocalX | LocalY | X_m | Y_m | Category
%
%  分类标签：直线段 / 缓和曲线 / 圆曲线 / 主点 / 线路控制点
%  主点标注顺序（按里程升序）：ZH → HY → QZ → YH → HZ
%  控制点标注：从 CSV 分类='线路控制点' 自动读取，不硬编码
% ─────────────────────────────────────────────────────────────────────────────

clearvars; close all; clc;

% ════════════════════════════════════════════════════════════════════════════
%  第 1 步：定位 CSV 文件（与本脚本同目录，自动拼路径）
% ════════════════════════════════════════════════════════════════════════════

script_dir = fileparts(mfilename('fullpath'));
csv_file   = fullfile(script_dir, 'curve_data.csv');

if ~isfile(csv_file)
    error(['找不到文件：%s\n', ...
           '请确认 curve_data.csv 与 plot_curve.m 放在同一文件夹内。'], csv_file);
end

% ════════════════════════════════════════════════════════════════════════════
%  第 2 步：读取 CSV，强制重命名列
%
%  根本原因：readtable 遇到 UTF-8-BOM 或中文列名时，
%  会因变量命名规则把列名改成 VarName1、VarName2…
%  解决方案：读入后立刻按【列序】强制赋予英文列名。
% ════════════════════════════════════════════════════════════════════════════

opts = detectImportOptions(csv_file, 'Encoding', 'UTF-8');

for ci = 1 : length(opts.VariableNames)
    if strcmpi(opts.VariableTypes{ci}, 'char') || ...
       strcmpi(opts.VariableTypes{ci}, 'categorical')
        opts = setvartype(opts, opts.VariableNames{ci}, 'string');
    end
end

T = readtable(csv_file, opts);

expected_cols = 7;
if width(T) ~= expected_cols
    error(['CSV 列数异常：期望 %d 列，实际读到 %d 列。\n', ...
           '请检查 curve_data.csv 是否包含：里程|点类型|局部x|局部y|大地X|大地Y|分类'], ...
           expected_cols, width(T));
end

%  原始 CSV 列顺序：里程 | 点类型 | 局部x | 局部y | 大地X | 大地Y | 分类
T.Properties.VariableNames = ...
    {'Mileage_m', 'PtType', 'LocalX', 'LocalY', 'X_m', 'Y_m', 'Category'};

T.Category = strtrim(T.Category);
T.PtType   = strtrim(T.PtType);

fprintf('=== CSV 读取成功，前 5 行预览 ===\n');
disp(head(T, 5));

% ════════════════════════════════════════════════════════════════════════════
%  第 3 步：按"分类"列筛选数据，并按里程排序
% ════════════════════════════════════════════════════════════════════════════

mask_line    = startsWith(T.Category, '直线') & ~strcmp(T.Category, '主点');
mask_curve   = strcmp(T.Category, '缓和曲线') | strcmp(T.Category, '圆曲线');
mask_main    = strcmp(T.Category, '主点');
% ★ v2 新增：从 CSV 读取控制点（不再硬编码坐标）
mask_control = strcmp(T.Category, '线路控制点');

T_line    = sortrows(T(mask_line,    :), 'Mileage_m');
T_curve   = sortrows(T(mask_curve,   :), 'Mileage_m');
T_main    = sortrows(T(mask_main,    :), 'Mileage_m');
T_control = sortrows(T(mask_control, :), 'Mileage_m');   % ★ v2

% 主点标签：ZH HY QZ YH HZ
main_labels = {'ZH', 'HY', 'QZ', 'YH', 'HZ'};
n_main      = min(height(T_main), numel(main_labels));

% 控制点标签：按 PtType 列（'控制点A'/'控制点B'）
n_ctrl = height(T_control);

% ════════════════════════════════════════════════════════════════════════════
%  第 4 步：创建画布并绘图
% ════════════════════════════════════════════════════════════════════════════

fig = figure('Color', 'white', ...
             'Units', 'normalized', ...
             'Position', [0.05 0.05 0.88 0.88]);
ax = axes(fig);
hold(ax, 'on');

% ── 4-1 直线段：蓝色实线 ────────────────────────────────────────────────────
%  坐标系约定：X=北（纵轴），Y=东（横轴）
h_line = [];
if ~isempty(T_line)
    h_line = plot(ax, T_line.Y_m, T_line.X_m, ...
                  '-', ...
                  'Color',       [0.13 0.47 0.71], ...
                  'LineWidth',   1.8, ...
                  'DisplayName', '直线段');
end

% ── 4-2 曲线段（缓和曲线 + 圆曲线）：绿色平滑连线 ──────────────────────────
h_curve = [];
if ~isempty(T_curve)
    h_curve = plot(ax, T_curve.Y_m, T_curve.X_m, ...
                   '-', ...
                   'Color',       [0.17 0.63 0.17], ...
                   'LineWidth',   1.8, ...
                   'DisplayName', '缓和曲线 / 圆曲线');
end

% ── 4-3 主点：红色大散点 + 文字标注 ────────────────────────────────────────
h_main = [];
if ~isempty(T_main) && n_main > 0

    h_main = scatter(ax, T_main.Y_m(1:n_main), T_main.X_m(1:n_main), ...
                     140, ...
                     [0.84 0.15 0.16], ...
                     'filled', ...
                     'MarkerEdgeColor', 'white', ...
                     'LineWidth',       1.2, ...
                     'DisplayName',     '线路主点');

    x_range = range(T.X_m);
    y_range = range(T.Y_m);
    dx_off  = y_range * 0.018;
    dy_off  = x_range * 0.018;

    for k = 1 : n_main
        if mod(k, 2) == 1
            offset_x = +dx_off;
            ha_str   = 'left';
        else
            offset_x = -dx_off;
            ha_str   = 'right';
        end

        text(ax, ...
             T_main.Y_m(k) + offset_x, ...
             T_main.X_m(k) + dy_off, ...
             main_labels{k}, ...
             'FontSize',            10, ...
             'FontWeight',          'bold', ...
             'Color',               [0.65 0.00 0.00], ...
             'HorizontalAlignment', ha_str, ...
             'VerticalAlignment',   'bottom', ...
             'BackgroundColor',     [1 1 1 0.65], ...
             'EdgeColor',           'none');
    end
end

% ── 4-4 控制点 A/B：从 CSV 读取，蓝色菱形 + 文字标注 ─────────────────────
%  ★ v2 核心修改：不再硬编码坐标，改为读取 CSV 中分类='线路控制点' 的行
h_ctrl = [];
if n_ctrl > 0
    h_ctrl = scatter(ax, T_control.Y_m, T_control.X_m, ...
                     120, ...
                     [0.00 0.45 0.74], ...       % 蓝色
                     'filled', ...
                     'd', ...                    % 菱形标记，与主点（圆形）区分
                     'MarkerEdgeColor', 'k', ...
                     'LineWidth',       1.0, ...
                     'DisplayName',     '线路控制点 A/B');

    x_range = range(T.X_m);
    y_range = range(T.Y_m);
    dx_off  = y_range * 0.018;
    dy_off  = x_range * 0.012;

    for k = 1 : n_ctrl
        lbl = char(T_control.PtType(k));        % '控制点A' 或 '控制点B'

        % 控制点标签方向：奇数右偏，偶数左偏
        if mod(k, 2) == 1
            offset_x = +dx_off;
            ha_str   = 'left';
        else
            offset_x = -dx_off;
            ha_str   = 'right';
        end

        text(ax, ...
             T_control.Y_m(k) + offset_x, ...
             T_control.X_m(k) - dy_off, ...     % 向下偏移，避免与主点标注重叠
             lbl, ...
             'FontSize',            9, ...
             'FontWeight',          'bold', ...
             'Color',               [0.00 0.30 0.60], ...   % 深蓝
             'HorizontalAlignment', ha_str, ...
             'VerticalAlignment',   'top', ...
             'BackgroundColor',     [1 1 1 0.60], ...
             'EdgeColor',           'none');
    end
end

% ════════════════════════════════════════════════════════════════════════════
%  第 5 步：坐标轴装饰
% ════════════════════════════════════════════════════════════════════════════

axis(ax, 'equal');
grid(ax, 'on');
ax.GridColor     = [0.6 0.6 0.6];
ax.GridAlpha     = 0.4;
ax.GridLineStyle = '--';
ax.Box           = 'on';
ax.FontSize      = 11;
ax.XColor        = [0.2 0.2 0.2];
ax.YColor        = [0.2 0.2 0.2];

xlabel(ax, '大地 Y 坐标（东坐标，m）', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, '大地 X 坐标（北坐标，m）', 'FontSize', 12, 'FontWeight', 'bold');

if ~isempty(T)
    dk_min    = min(T.Mileage_m);
    dk_max    = max(T.Mileage_m);
    title_str = sprintf('线路平曲线模型图   （K%.0f+%.3f  ~  K%.0f+%.3f）', ...
                        floor(dk_min/1000), mod(dk_min,1000), ...
                        floor(dk_max/1000), mod(dk_max,1000));
else
    title_str = '线路平曲线模型图';
end
title(ax, title_str, 'FontSize', 14, 'FontWeight', 'bold');

% ════════════════════════════════════════════════════════════════════════════
%  第 6 步：图例（只显示实际存在的要素）
% ════════════════════════════════════════════════════════════════════════════

legend_handles = [];
if ~isempty(h_line),  legend_handles(end+1) = h_line;  end
if ~isempty(h_curve), legend_handles(end+1) = h_curve; end
if ~isempty(h_main),  legend_handles(end+1) = h_main;  end
if ~isempty(h_ctrl),  legend_handles(end+1) = h_ctrl;  end   % ★ v2 新增

if ~isempty(legend_handles)
    lgd = legend(ax, legend_handles, ...
                 'Location',  'best', ...
                 'FontSize',  10, ...
                 'Box',       'on', ...
                 'EdgeColor', [0.7 0.7 0.7], ...
                 'Color',     'white');
    lgd.Title.String   = '图 例';
    lgd.Title.FontSize = 9;
end

hold(ax, 'off');

% ════════════════════════════════════════════════════════════════════════════
%  第 7 步：命令行输出统计信息
% ════════════════════════════════════════════════════════════════════════════

fprintf('\n线路平曲线图已生成！\n');
fprintf('  数据来源 ：%s\n', csv_file);
fprintf('  总点数   ：%d\n', height(T));
fprintf('    直线段 ：%d 点\n', sum(mask_line));
fprintf('    曲线段 ：%d 点（缓和曲线 %d + 圆曲线 %d）\n', ...
        sum(mask_curve), ...
        sum(strcmp(T.Category,'缓和曲线')), ...
        sum(strcmp(T.Category,'圆曲线')));
fprintf('    主  点 ：%d 个\n', n_main);
if n_main > 0
    fprintf('  主点标注 ：');
    fprintf('%s  ', main_labels{1:n_main});
    fprintf('\n');
end
% ★ v2 新增：控制点统计
fprintf('  控制点   ：%d 个（从 CSV 自动读取，不再硬编码）\n', n_ctrl);
if n_ctrl > 0
    for k = 1 : n_ctrl
        fprintf('    %s：X=%.6f m，Y=%.6f m\n', ...
                char(T_control.PtType(k)), T_control.X_m(k), T_control.Y_m(k));
    end
end
fprintf('\n');
