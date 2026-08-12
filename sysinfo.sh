#!/bin/bash
set -euo pipefail

# 定义颜色（优先 tput，MOTD 这种无终端的环境用 ANSI 硬编码兜底）
RED=$(tput setaf 1 2>/dev/null || printf '\033[31m')
GREEN=$(tput setaf 2 2>/dev/null || printf '\033[32m')
YELLOW=$(tput setaf 3 2>/dev/null || printf '\033[33m')
BLUE=$(tput setaf 4 2>/dev/null || printf '\033[34m')
CYAN=$(tput setaf 6 2>/dev/null || printf '\033[36m')
RESET=$(tput sgr0 2>/dev/null || printf '\033[0m')

# 设置 PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 辅助函数：字节数（kB）转可读单位
human_size() {
    local kb=$1
    if [ "$kb" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.1fG\", $kb / 1048576}"
    elif [ "$kb" -ge 1024 ]; then
        awk "BEGIN {printf \"%.1fM\", $kb / 1024}"
    else
        echo "${kb}K"
    fi
}

# 辅助函数：根据百分比返回颜色
pct_color() {
    local pct=$1
    if [ "$pct" -gt 90 ]; then echo "$RED"
    elif [ "$pct" -gt 70 ]; then echo "$YELLOW"
    else echo "$GREEN"
    fi
}

# ---------- 基础信息 ----------
echo "${BLUE}=========================================${RESET}"
echo "${YELLOW}主机名称:${RESET} $(hostname 2>/dev/null || echo 'N/A')"

LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "${YELLOW}内网  IP:${RESET} ${LOCAL_IP:-N/A}"

echo "${BLUE}-----------------------------------------${RESET}"
echo "${YELLOW}当前时间:${RESET} $(date '+%Y-%m-%d %H:%M:%S')"

# 系统版本（兼容无 lsb_release 的环境）
if command -v lsb_release &>/dev/null; then
    echo "${YELLOW}系统版本:${RESET} $(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}')"
elif [ -f /etc/os-release ]; then
    echo "${YELLOW}系统版本:${RESET} $(awk -F= '/^PRETTY_NAME=/ {gsub(/"/,""); print $2}' /etc/os-release)"
else
    echo "${YELLOW}系统版本:${RESET} N/A"
fi

echo "${YELLOW}内核版本:${RESET} $(uname -r)"

# 运行时间（兼容无 -p 的 uptime）
UPTIME_STR=$(uptime -p 2>/dev/null | sed 's/up //' || true)
if [ -z "${UPTIME_STR:-}" ]; then
    UPTIME_STR=$(uptime 2>/dev/null | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' || echo 'N/A')
fi
echo "${YELLOW}运行时间:${RESET} ${UPTIME_STR}"

# CPU 型号（兼容 ARM 设备无 Model name 字段；lscpu 输出值前有大量空格，gsub 去掉）
CPU_MODEL=$(lscpu 2>/dev/null | awk -F: '/^Model name:/ {gsub(/^[[:space:]]+/, "", $2); print $2}' | head -1)
echo "${YELLOW}CPU 型号:${RESET} ${CPU_MODEL:-N/A}"

echo "${YELLOW}CPU 负载:${RESET} $(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^ *//g' || echo 'N/A')"
echo "${YELLOW}运行进程:${RESET} $(ps aux --no-heading 2>/dev/null | wc -l || echo 'N/A')"

LOGIN_USERS=$(who 2>/dev/null | awk '!seen[$1]++ {print $1}' | paste -sd ',' - 2>/dev/null || true)
echo "${YELLOW}登录用户:${RESET} ${LOGIN_USERS:-无}"

# ---------- 内存 / Swap ----------
if [ -r /proc/meminfo ]; then
    MEM_TOTAL=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    MEM_AVAIL=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
    MEM_PCT=$(awk "BEGIN {printf \"%d\", (${MEM_USED} / ${MEM_TOTAL}) * 100}")
    MEM_COLOR=$(pct_color "$MEM_PCT")
    echo "${YELLOW}内存使用:${RESET} $(human_size "$MEM_USED") / $(human_size "$MEM_TOTAL") ${MEM_COLOR}(${MEM_PCT}%)${RESET}"

    SWAP_TOTAL=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
    SWAP_FREE=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
        SWAP_PCT=$(awk "BEGIN {printf \"%d\", (${SWAP_USED} / ${SWAP_TOTAL}) * 100}")
        SWAP_COLOR=$(pct_color "$SWAP_PCT")
        echo "${YELLOW}Swap使用:${RESET} $(human_size "$SWAP_USED") / $(human_size "$SWAP_TOTAL") ${SWAP_COLOR}(${SWAP_PCT}%)${RESET}"
    else
        echo "${YELLOW}Swap使用:${RESET} 未启用"
    fi
else
    echo "${YELLOW}内存使用:${RESET} N/A (无法读取 /proc/meminfo)"
    echo "${YELLOW}Swap使用:${RESET} N/A"
fi

# ---------- 磁盘使用 ----------
echo "${YELLOW}磁盘使用:${RESET}"
df -h 2>/dev/null | awk '
    NR>1 && !/^udev/ && !/^tmpfs/ && !/^devtmpfs/ && !/^squashfs/ && !/^overlay/ && !/^none/ {
        print $6, $3, $2, $5
    }
' | while read -r mount used total pct; do
    pct_num=${pct//%/}
    dcolor=$(pct_color "$pct_num")
    printf "  ${CYAN}%-10s${RESET} %5s / %-5s ${dcolor}(%s)${RESET}\n" "$mount" "$used" "$total" "$pct"
done

echo "${BLUE}=========================================${RESET}"
