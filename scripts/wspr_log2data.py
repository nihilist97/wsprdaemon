#!/usr/bin/env python3

import sys
import os
import re
import argparse
import gzip
from datetime import datetime, timedelta
from glob import glob

def parse_args():
    """
    解析命令行参数：
    - -d: 日期（yyyymmdd），如果不指定则取前一天
    - -s: site，默认为 'sysu'
    - -t: 日志类型（ft8, ft4, wspr），默认为 'ft8'
    """
    parser = argparse.ArgumentParser(description="筛选日志文件并保存到指定目录")
    parser.add_argument('-d', '--date', help="日期（yyyymmdd），默认为前一天", default=None)
    parser.add_argument('-s', '--site', help="站点名称，默认为 'sysu'", default='sysu')
    parser.add_argument('-t', '--type', help="日志类型（ft8, ft4, wspr），默认为 'ft8'", default='ft8')
    args = parser.parse_args()

    return args

def filter_logs_by_date(log_file, target_date, log_type):
    """
    从日志文件中筛选出符合目标日期的记录
    """
    filtered_lines = []

    try:
        if log_file.endswith('.gz'):
            with gzip.open(log_file, 'rt') as file:
                lines = file.readlines()
        else:
            with open(log_file, 'r') as file:
                lines = file.readlines()

        for line in lines:
            if log_type == 'wspr':
                # 处理 wspr 日志
                match = re.match(r'^(\d{2})(\d{2})(\d{2}) (\d{2})(\d{2})', line)
                if match:
                    year = int(match.group(1)) + 2000  # 转换为 yyyy
                    month = int(match.group(2))
                    day = int(match.group(3))
                    hour = int(match.group(4))
                    minute = int(match.group(5))
                    log_datetime = datetime(year, month, day, hour, minute)
                    log_date_str = log_datetime.strftime('%Y%m%d')
                    if log_date_str == target_date:
                        new_line = re.sub(
                            r'^(\d{6}) (\d{4})',
                            log_datetime.strftime('%Y%m%d %H:%M:%S'),
                            line
                        )
                        filtered_lines.append(new_line.strip())
            else:
                # 处理 ft8/ft4 日志
                match = re.match(r'^(\d{4}/\d{2}/\d{2})', line)
                if match:
                    log_date = match.group(1).replace('/', '')
                    if log_date == target_date:
                        filtered_lines.append(line.strip())
    except FileNotFoundError:
        print(f"文件 {log_file} 不存在，跳过。")

    print( "found %d records" % (len(filtered_lines)) )

    return filtered_lines

def write_filtered_logs(filtered_lines, output_file, log_type):
    """
    将筛选的记录写入新文件，并添加文件头
    """
    os.makedirs(os.path.dirname(output_file), exist_ok=True)  # 创建目录（如果不存在）
    
    # 定义不同日志类型的文件头
    headers = {
        'ft8': "year/mm/dd hh:mm:ss score sec    frequency   msg",
        'ft4': "year/mm/dd hh:mm:ss score sec    frequency   msg",
        'wspr': "yearmmdd hh:mm:ss  sync snr    dt    frequency callsign       loc  power drift type"
    }
    
    with open(output_file, 'w') as file:
        # 写入文件头
        if log_type in headers:
            file.write(headers[log_type] + '\n')
        
        for line in filtered_lines:
            file.write(line + '\n')

def main():
    # 解析命令行参数
    args = parse_args()

    site = args.site
    log_type = args.type

    log_files = [f'/var/log/{log_type}.log.1', f'/var/log/{log_type}.log']

    yesterday = datetime.now() - timedelta(days=1)
    date_str = yesterday.strftime('%Y%m%d')  # 统一为 yyyymmdd 格式

    if args.date:
        # 确保日期格式为 yyyymmdd
        try:
            datetime.strptime(args.date, '%Y%m%d')
        except ValueError:
            print("日期格式错误，请使用 yyyymmdd 格式")
            sys.exit(1)
        date_str = args.date

        # 根据日志类型定义日志文件路径
        log_files = glob(f'/var/log/{log_type}.log*')  # 获取所有符合日志类型的文件

        # 按照文件修改时间从早到晚排序
        log_files.sort(key=os.path.getmtime)

    # 筛选符合条件的记录
    filtered_lines = []
    for log_file in log_files:
        print( log_file )
        filtered_lines.extend(filter_logs_by_date(log_file, date_str, log_type))

    # 定义输出文件路径
    output_dir = os.path.expanduser(f'~/wspr_record/{date_str[:4]}')
    output_file = os.path.join(output_dir, f'{log_type}_{site}_{date_str}.log')

    # 写入筛选的记录
    write_filtered_logs(filtered_lines, output_file, log_type)
    print(f"筛选的记录已写入 {output_file}")

if __name__ == '__main__':
    main()

