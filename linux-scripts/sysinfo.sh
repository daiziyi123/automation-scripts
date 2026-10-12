#!/usr/bin/env bash
# ============================================================
# sysinfo.sh - 系统信息查看脚本
# 功能：查看 CPU、内存、磁盘、网络、系统版本等信息
# 用法：./sysinfo.sh [选项]
# 选项：
#   -a, --all      显示所有信息（默认）
#   -c, --cpu      仅显示 CPU 信息
#   -m, --memory   仅显示内存信息
#   -d, --disk     仅显示磁盘信息
#   -n, --network  仅显示网络信息
#   -s, --system   仅显示系统信息
#   -h, --help     显示帮助
# ============================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印分隔线
print_line() {
    echo -e "${CYAN}------------------------------------------------------------${NC}"
}

# 打印标题
print_title() {
    print_line
    echo -e "${GREEN}► $1${NC}"
    print_line
}

# CPU 信息
show_cpu() {
    print_title "CPU 信息"
    echo -e "  型号:      $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo -e "  核心数:    $(nproc)"
    echo -e "  架构:      $(uname -m)"
    if command -v lscpu &>/dev/null; then
        echo -e "  主频:      $(lscpu | grep 'CPU MHz' | awk '{print $3}' | head -1) MHz"
        echo -e "  缓存:      $(lscpu | grep 'L3 cache' | awk '{print $3, $4}')"
    fi
    echo -e "  负载:      $(uptime | awk -F'load average:' '{print $2}' | xargs)"
}

# 内存信息
show_memory() {
    print_title "内存信息"
    if command -v free &>/dev/null; then
        free -h | awk '
        NR==1 {printf "  %-12s %-10s %-10s %-10s\n", "类型", "总量", "已用", "可用"}
        NR==2 {printf "  %-12s %-10s %-10s %-10s\n", $1, $2, $3, $7}
        NR==3 {printf "  %-12s %-10s %-10s %-10s\n", $1, $2, $3, $4}
        '
    fi
}

# 磁盘信息
show_disk() {
    print_title "磁盘信息"
    echo -e "  ${YELLOW}文件系统使用情况:${NC}"
    df -h --total 2>/dev/null | grep -v 'tmpfs\|udev' | awk '
    NR==1 {printf "  %-20s %-8s %-8s %-8s %-6s %s\n", "文件系统", "总量", "已用", "可用", "使用率", "挂载点"}
    NR>1  {printf "  %-20s %-8s %-8s %-8s %-6s %s\n", $1, $2, $3, $4, $5, $6}
    '
    echo ""
    echo -e "  ${YELLOW}目录占用 (当前目录 Top 10):${NC}"
    du -sh */ 2>/dev/null | sort -rh | head -10 | awk '{printf "  %-10s %s\n", $1, $2}'
}

# 网络信息
show_network() {
    print_title "网络信息"
    echo -e "  ${YELLOW}网络接口:${NC}"
    if command -v ip &>/dev/null; then
        ip -br addr 2>/dev/null | awk '{printf "  %-15s %-10s %s\n", $1, $2, $3}'
    elif command -v ifconfig &>/dev/null; then
        ifconfig 2>/dev/null | grep -E '^[a-z]' | awk '{printf "  %s\n", $1}'
    fi
    echo ""
    echo -e "  ${YELLOW}监听端口:${NC}"
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | awk 'NR>1 {printf "  %-6s %s\n", $1, $4}' | head -15
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | awk 'NR>2 {printf "  %-6s %s\n", $1, $4}' | head -15
    fi
}

# 系统信息
show_system() {
    print_title "系统信息"
    echo -e "  主机名:    $(hostname)"
    echo -e "  系统:      $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo -e "  内核:      $(uname -r)"
    echo -e "  运行时间:  $(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | cut -d, -f1 | xargs)"
    echo -e "  当前用户:  $(whoami) ($(id -u))"
    echo -e "  Shell:     $SHELL"
    echo -e "  进程数:    $(ps aux | wc -l)"
    echo -e "  登录用户:  $(who | wc -l)"
}

# 帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --all      显示所有信息（默认）"
    echo "  -c, --cpu      仅显示 CPU 信息"
    echo "  -m, --memory   仅显示内存信息"
    echo "  -d, --disk     仅显示磁盘信息"
    echo "  -n, --network  仅显示网络信息"
    echo "  -s, --system   仅显示系统信息"
    echo "  -h, --help     显示此帮助"
}

# 主流程
main() {
    if [ $# -eq 0 ]; then
        show_system
        show_cpu
        show_memory
        show_disk
        show_network
        return
    fi

    case "$1" in
        -a|--all)
            show_system; show_cpu; show_memory; show_disk; show_network ;;
        -c|--cpu)     show_cpu ;;
        -m|--memory)  show_memory ;;
        -d|--disk)    show_disk ;;
        -n|--network) show_network ;;
        -s|--system)  show_system ;;
        -h|--help)    show_help ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
