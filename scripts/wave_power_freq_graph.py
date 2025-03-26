#!/usr/bin/env python3

# ./wave_power_freq_graph.py -w 1024 -s 10 -f ~/10sps_iq_record/N0HAQ_OL62ma/20250308/N0HAQ_OL62ma_WWV_10_10sps_iq_20250308.wav

import os, argparse
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import wavfile
from matplotlib.ticker import MultipleLocator

def calculate_power(iq_signal, window_size, step_size, sample_rate):
    """
    计算IQ信号的功率随时间的变化
    :param iq_signal: 输入IQ信号（复数形式）
    :param window_size: 窗口大小
    :param step_size: 步长
    :param sample_rate: 采样率
    :return: 功率数组和时间数组
    """
    power = []
    for i in range(0, len(iq_signal) - window_size, step_size):
        window = iq_signal[i:i + window_size]
        window_power = np.mean(np.abs(window)**2)  # 计算窗口内信号的功率
        power.append(window_power)
    time = np.arange(0, len(power)) * (step_size / sample_rate)  # 计算时间轴
    return np.array(power), time

def calculate_fft(iq_signal, window_size, step_size, sample_rate):
    """
    计算IQ信号的滑动窗口FFT
    :param iq_signal: 输入IQ信号（复数形式）
    :param window_size: 窗口大小
    :param step_size: 步长
    :param sample_rate: 采样率
    :return: FFT频谱数组和时间数组
    """
    fft_spectra = []
    for i in range(0, len(iq_signal) - window_size, step_size):
        # 选择窗函数（例如汉宁窗）
        window = np.hanning(window_size)
        #window = np.hamming(window_size)
        # 对信号加窗
        signal = iq_signal[i:i + window_size] * window
        #signal = iq_signal[i:i + window_size]
        signal_fft = np.fft.fftshift(np.fft.fft(signal))  # 计算FFT并进行fftshift
        fft_spectra.append(np.abs(signal_fft))  # 取幅度谱
    time = np.arange(0, len(fft_spectra)) * (step_size / sample_rate)  # 计算时间轴
    return np.array(fft_spectra), time

def power_to_dBm(power_watt):
    """
    将功率（瓦特）转换为dBm
    :param power_watt: 功率值（瓦特）
    :return: 功率值（dBm）
    """
    return 10 * np.log10(power_watt * 1000)  # 转换为dBm

def main():
    # 解析命令行参数
    parser = argparse.ArgumentParser(description="计算IQ信号的功率和频谱随时间变化")
    parser.add_argument('-f', '--file', required=True, help="wave文件路径")
    parser.add_argument('-w', '--window', type=int, required=True, help="窗口宽度（样本数）")
    parser.add_argument('-s', '--sample_rate', type=int, help="手动指定采样率（Hz），如果不提供则从文件中读取")
    args = parser.parse_args()

    # 读取wave文件
    if args.sample_rate:
        sample_rate = args.sample_rate
        data = wavfile.read(args.file)[1]  # 仅读取数据，忽略文件中的采样率
    else:
        sample_rate, data = wavfile.read(args.file)  # 从文件中读取采样率和数据

    # 将IQ数据转换为复数形式
    if len(data.shape) > 1:
        iq_signal = data[:, 0] + 1j * data[:, 1]  # I为第0列，Q为第1列
    else:
        raise ValueError("输入文件必须是双通道的IQ数据！")

    # 设置窗口大小和步长
    window_size = args.window
    step_size = window_size // 2  # 步长为窗口大小的一半

    # 计算功率随时间变化
    power, time = calculate_power(iq_signal, window_size, step_size, sample_rate)

    # 将功率值转换为瓦特并除以10^10，再转换为dBm
    power_watt = power / 1e16 / 50.  # 转换为瓦特 V^2/R, R = 50 Ohm
    power_dBm = power_to_dBm(power_watt)  # 转换为dBm

    # 将时间转换为小时（00到24）
    time_hours = time / 3600  # 将秒转换为小时

    # 计算纵坐标范围（90%百分位数，并适当放宽）
    lower_percentile = np.percentile(power_dBm, 5)  # 下界为5%百分位数
    upper_percentile = np.percentile(power_dBm, 95)  # 上界为95%百分位数
    margin = 20  # 放宽范围
    y_min = lower_percentile - margin
    y_max = upper_percentile + margin

    # 创建图形
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 4), sharex=True)  # 共享横坐标轴

    # 绘制功率随时间变化的散点图
    ax1.scatter(time_hours, power_dBm, s=6, color='RoyalBlue', label='Signal Power (dBm)')  # 散点图
    ax1.set_ylabel('Power (dBm)')
    ax1.set_title('Signal Power %s' % (os.path.basename(args.file)) )  # 标题显示文件名

    # 设置横坐标刻度为每小时一格
    ax1.xaxis.set_major_locator(MultipleLocator(1))  # 每小时一个主刻度
    ax1.grid(True, which='major', linestyle='--', linewidth=0.5)  # 显示主网格

    # 设置纵坐标范围
    ax1.set_ylim(y_min, y_max)

    # 设置横坐标范围为00到24小时
    ax1.set_xlim(0, 24)

    ax1.legend()

    # 计算FFT频谱
    fft_spectra, fft_time = calculate_fft(iq_signal, window_size, step_size, sample_rate)
    fft_time_hours = fft_time / 3600  # 将秒转换为小时

    # 计算频率轴
    freq = np.fft.fftshift(np.fft.fftfreq(window_size, d=1/sample_rate))  # 频率轴

    # 绘制FFT频谱随时间变化的瀑布图
    #cmap='viridis'
    cmap='plasma'
    cmap='gnuplot'
    cmap='magma'
    extent = [0, 24, freq[0], freq[-1]]  # 设置横坐标范围为0~24小时，纵坐标范围为频率范围
    #im = ax2.imshow(fft_spectra.T, vmin=1E1, vmax=1E5, aspect='auto', origin='lower', extent=extent, cmap=cmap)
    #im = ax2.imshow(np.log10(fft_spectra.T), vmin=2.5, vmax=5., aspect='auto', origin='lower', extent=extent, cmap=cmap)

    im_data = np.log10(fft_spectra.T)

    _range = np.max(im_data) - np.min(im_data)
    im_data = (im_data - np.min(im_data)) / _range
 
 
    p10 = np.percentile(im_data, 30)
    p90 = np.percentile(im_data, 80)
    # 按 0.5 的间隔取整
    vmin = np.round(p10*1.1 * 10) / 10
    vmax = np.round(p90*1.4 * 10) / 10
    im = ax2.imshow(im_data, vmin=vmin, vmax=vmax, aspect='auto', origin='lower', extent=extent, cmap=cmap)

    ax2.set_xlabel('Time (Hours)')
    ax2.set_ylabel('Frequency (Hz)')

    ax2.xaxis.set_major_locator(MultipleLocator(1))  # 每小时一个主刻度
    ax2.grid(True, which='major', linestyle='--', color='grey', linewidth=0.5)  # 显示主网格

    ax2.set_ylim(-3, 3)  # 设置纵坐标范围为-5~5 Hz

    # 调整布局，为colorbar腾出空间
    plt.subplots_adjust(left=0.1, right=0.88, bottom=0.1, top=0.9, hspace=0.)  # 设置空白距离

    # 添加colorbar，并将其放置在更右侧
    cbar_ax = fig.add_axes([0.89, 0.1, 0.02, 0.4])  # [left, bottom, width, height]
    cbar = fig.colorbar(im, cax=cbar_ax, label='Log Magnitude')

    # 设置 colorbar 的数值范围（可选，默认与 imshow 一致）
    #plt.clim(min_value, max_value)

    plt.savefig( args.file+'.png', dpi=150, bbox_inches='tight')

    plt.show()


if __name__ == "__main__":
    main()

