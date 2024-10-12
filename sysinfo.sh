#!/bin/bash

# 定义颜色
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

# 设置 PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 显示系统信息
echo "${BLUE}---------------------------------${RESET}"
echo "${YELLOW}当前时间:${RESET} $(date '+%Y-%m-%d %H:%M:%S')"
echo "${YELLOW}系统版本:${RESET} $(lsb_release -d | awk -F'\t' '{print $2}')"
echo "${YELLOW}内核版本:${RESET} $(uname -r)"
echo "${YELLOW}运行时间:${RESET} $(uptime -p | sed 's/up //')"
echo "${YELLOW}CPU 型号:${RESET} $(lscpu | grep 'Model name' | head -n 1 | awk -F: '{print $2}' | sed 's/^ *//g')"
echo "${YELLOW}CPU 负载:${RESET} $(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//g')"

# 内存使用
MEM_TOTAL=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
MEM_USED=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
MEM_USED=$((MEM_TOTAL - MEM_USED))
MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
MEM_USED_MB=$((MEM_USED / 1024))
MEM_PERCENT=$(awk "BEGIN {print int((${MEM_USED_MB}/${MEM_TOTAL_MB}) * 100)}")
if [ "$MEM_PERCENT" -gt 90 ]; then
    MEM_COLOR=$RED
else
    MEM_COLOR=$GREEN
fi
echo "${YELLOW}内存使用:${RESET} ${MEM_USED_MB}M/${MEM_TOTAL_MB}M ${MEM_COLOR}(${MEM_PERCENT}%)${RESET}"

# 磁盘使用
DISK_TOTAL=$(df -h / | awk '/\// {print $2}')
DISK_USED=$(df -h / | awk '/\// {print $3}')
DISK_PERCENT=$(df -h / | awk '/\// {print $5}' | sed 's/%//')
if [ "$DISK_PERCENT" -gt 90 ]; then
    DISK_COLOR=$RED
else
    DISK_COLOR=$GREEN
fi
echo "${YELLOW}磁盘使用:${RESET} ${DISK_USED}/${DISK_TOTAL} ${DISK_COLOR}(${DISK_PERCENT}%)${RESET}"
echo "${BLUE}---------------------------------${RESET}"
