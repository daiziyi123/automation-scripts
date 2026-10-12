#!/usr/bin/env bash
# ============================================================
# svcctl.sh - 服务管理脚本
# 功能：管理 systemd 服务的启动、停止、重启、状态查看、开机自启等
# 用法：./svcctl.sh <操作> [服务名]
# 操作：
#   list                列出所有服务
#   status [服务名]     查看服务状态
#   start <服务名>      启动服务
#   stop <服务名>       停止服务
#   restart <服务名>    重启服务
#   enable <服务名>     设置开机自启
#   disable <服务名>    取消开机自启
#   logs <服务名>       查看服务日志
#   failed              查看失败的服务
#   help                显示帮助
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检查 systemctl 是否可用
check_systemctl() {
    if ! command -v systemctl &>/dev/null; then
        echo -e "${RED}错误：未检测到 systemctl，此脚本仅支持 systemd 系统。${NC}"
        exit 1
    fi
}

# 检查是否为 root（部分操作需要）
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${YELLOW}提示：此操作需要 root 权限，尝试使用 sudo...${NC}"
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# 检查服务名参数
check_service_name() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}错误：请指定服务名。${NC}"
        echo -e "用法: $0 $0 <服务名>"
        exit 1
    fi
}

# 列出所有服务
list_services() {
    echo -e "${CYAN}========== 服务列表 ==========${NC}"
    systemctl list-units --type=service --all --no-pager 2>/dev/null | \
        awk 'NR==1 || /\.service/' | \
        awk '{printf "  %-40s %-12s %-12s %s\n", $1, $2, $3, $4}' | head -40
    echo ""
    echo -e "${YELLOW}提示：使用 '$0 status <服务名>' 查看详细状态${NC}"
}

# 查看服务状态
service_status() {
    local svc="$1"
    echo -e "${CYAN}========== $svc 状态 ==========${NC}"
    systemctl status "$svc" --no-pager 2>&1 || true
}

# 启动服务
service_start() {
    check_root
    local svc="$1"
    echo -e "${YELLOW}正在启动 $svc ...${NC}"
    if $SUDO systemctl start "$svc"; then
        echo -e "${GREEN}✓ $svc 已启动${NC}"
    else
        echo -e "${RED}✗ $svc 启动失败${NC}"
        return 1
    fi
}

# 停止服务
service_stop() {
    check_root
    local svc="$1"
    echo -e "${YELLOW}正在停止 $svc ...${NC}"
    if $SUDO systemctl stop "$svc"; then
        echo -e "${GREEN}✓ $svc 已停止${NC}"
    else
        echo -e "${RED}✗ $svc 停止失败${NC}"
        return 1
    fi
}

# 重启服务
service_restart() {
    check_root
    local svc="$1"
    echo -e "${YELLOW}正在重启 $svc ...${NC}"
    if $SUDO systemctl restart "$svc"; then
        echo -e "${GREEN}✓ $svc 已重启${NC}"
    else
        echo -e "${RED}✗ $svc 重启失败${NC}"
        return 1
    fi
}

# 设置开机自启
service_enable() {
    check_root
    local svc="$1"
    if $SUDO systemctl enable "$svc"; then
        echo -e "${GREEN}✓ $svc 已设置为开机自启${NC}"
    else
        echo -e "${RED}✗ 设置失败${NC}"
        return 1
    fi
}

# 取消开机自启
service_disable() {
    check_root
    local svc="$1"
    if $SUDO systemctl disable "$svc"; then
        echo -e "${GREEN}✓ $svc 已取消开机自启${NC}"
    else
        echo -e "${RED}✗ 取消失败${NC}"
        return 1
    fi
}

# 查看服务日志
service_logs() {
    local svc="$1"
    echo -e "${CYAN}========== $svc 日志（最近 50 行） ==========${NC}"
    journalctl -u "$svc" --no-pager -n 50 2>&1 || \
        echo -e "${RED}无法获取日志，请确认服务名正确。${NC}"
}

# 查看失败的服务
show_failed() {
    echo -e "${CYAN}========== 失败的服务 ==========${NC}"
    local failed
    failed=$(systemctl --failed --no-pager 2>/dev/null | grep -c "failed" || true)
    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}当前没有失败的服务。${NC}"
    else
        systemctl --failed --no-pager 2>/dev/null
    fi
}

# 帮助
show_help() {
    echo "用法: $0 <操作> [服务名]"
    echo ""
    echo "操作:"
    echo "  list                列出所有服务"
    echo "  status <服务名>     查看服务状态"
    echo "  start <服务名>      启动服务"
    echo "  stop <服务名>       停止服务"
    echo "  restart <服务名>    重启服务"
    echo "  enable <服务名>     设置开机自启"
    echo "  disable <服务名>    取消开机自启"
    echo "  logs <服务名>       查看服务日志"
    echo "  failed              查看失败的服务"
    echo "  help                显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 list"
    echo "  $0 status nginx"
    echo "  $0 restart nginx"
    echo "  $0 enable ssh"
}

# 主流程
main() {
    check_systemctl

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local action="$1"
    shift

    case "$action" in
        list)    list_services ;;
        status)  check_service_name "${1:-}"; service_status "$1" ;;
        start)   check_service_name "${1:-}"; service_start "$1" ;;
        stop)    check_service_name "${1:-}"; service_stop "$1" ;;
        restart) check_service_name "${1:-}"; service_restart "$1" ;;
        enable)  check_service_name "${1:-}"; service_enable "$1" ;;
        disable) check_service_name "${1:-}"; service_disable "$1" ;;
        logs)    check_service_name "${1:-}"; service_logs "$1" ;;
        failed)  show_failed ;;
        help|-h|--help) show_help ;;
        *)
            echo -e "${RED}未知操作: $action${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
