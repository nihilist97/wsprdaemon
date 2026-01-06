#!/bin/bash

id="OQ_OL39ei"

# 检查是否提供了日期参数
if [ -z "$1" ]; then
    # 如果没有提供日期，则使用昨天的日期
    date=$(date -d "yesterday" +"%Y%m%d")
else
    # 如果提供了日期，则使用提供的日期
    date="$1"
fi

echo $date

# 定义基础路径
base_path="$HOME/site_data/ARCH/${id}_daily/$date"
target_dir="$HOME/site_data/ARCH/${id}_daily"

# 检查目录是否存在
if [ ! -d "$base_path" ]; then
    echo "目录不存在: $base_path"
    mkdir -p "$base_path"
    #exit 1
fi

SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
cd ${SCRIPT_DIR}

# 查找所有 .wav 文件并处理
find "$base_path" -type f -name "*.wav" -o -name "*.flac"| while read -r wave_file; do
    echo "处理文件: $wave_file"
    # for wspr/rx888 site
    #python3 wave_power_freq_graph.py -w 1024 -s 10 -f "$wave_file"
    python3 wave_power_freq_graph.py -w 2048 -s 100 -f "$wave_file"
    # for Doppler/usrp site, center frequency = 20 Hz
    #python3 wave_power_freq_graph.py -w 2048 -s 100 -f "$wave_file" -c 20

    # 获取生成的 .png 文件名
    png_file="${wave_file}.png"

    # 检查 .png 文件是否存在
    if [ -f "$png_file" ]; then
        # 构造目标文件名（用 current 替换日期部分）
        png_basename=$(basename "$png_file")
        target_name="${png_basename//$date/current}"
        target_path="$target_dir/$target_name"

        # 如果目标文件已存在，则先删除
        if [ -f "$target_path" ]; then
            rm "$target_path"
            echo "已删除旧文件: $target_path"
        fi

        # 复制文件到目标文件夹
        mv "$png_file" "$target_path"
        echo "已复制文件: $png_file -> $target_path"
    else
        echo "警告: 未找到生成的 .png 文件: $png_file"
    fi
done

