#!/usr/bin/env bash
# ============================================================
# admin-menu.sh - Linux 统一管理菜单
# 功能：整合系统信息、服务管理、用户管理、系统清理等功能
# 用法：./admin-menu.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 清屏并显示菜单头部
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${BOLD}${GREEN}Linux 系统管理菜单${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   主机: $(hostname -s | awk '{printf "%-36s", $0}')${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   时间: $(date '+%Y-%m-%d %H:%M:%S' | awk '{printf "%-36s", $0}')${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示主菜单
show_menu() {
    echo -e "${BOLD}请选择操作：${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC}  系统信息总览      ${BLUE}(CPU/内存/磁盘/网络)${NC}"
    echo -e "  ${GREEN}2.${NC}  服务管理          ${BLUE}(启动/停止/重启/状态)${NC}"
    echo -e "  ${GREEN}3.${NC}  用户管理          ${BLUE}(增删查改/密码/锁定)${NC}"
    echo -e "  ${GREEN}4.${NC}  系统清理          ${BLUE}(缓存/日志/临时文件)${NC}"
    echo -e "  ${GREEN}5.${NC}  磁盘使用分析"
    echo -e "  ${GREEN}6.${NC}  查看登录用户"
    echo -e "  ${GREEN}7.${NC}  查看系统资源实时监控"
    echo -e "  ${GREEN}8.${NC}  网络连接统计"
    echo -e "  ${GREEN}9.${NC}  查看系统启动项"
    echo ""
    echo -e "  ${YELLOW}0.${NC}  退出"
    echo ""
}

# 暂停等待用户输入
pause() {
    echo ""
    read -rp "按回车键返回菜单..."
}

# 执行子脚本
run_script() {
    local script="$1"
    shift
    if [ -f "$SCRIPT_DIR/$script" ]; then
        bash "$SCRIPT_DIR/$script" "$@"
    else
        echo -e "${RED}错误：脚本 $script 不存在。${NC}"
    fi
}

# 菜单 1: 系统信息
menu_sysinfo() {
    run_script "sysinfo.sh" --all
}

# 菜单 2: 服务管理子菜单
menu_services() {
    while true; do
        show_header
        echo -e "${BOLD}服务管理：${NC}"
        echo -e "  ${GREEN}1.${NC}  列出所有服务"
        echo -e "  ${GREEN}2.${NC}  查看服务状态"
        echo -e "  ${GREEN}3.${NC}  启动服务"
        echo -e "  ${GREEN}4.${NC}  停止服务"
        echo -e "  ${GREEN}5.${NC}  重启服务"
        echo -e "  ${GREEN}6.${NC}  查看服务日志"
        echo -e "  ${GREEN}7.${NC}  查看失败的服务"
        echo -e "  ${YELLOW}0.${NC}  返回上级"
        echo ""
        read -rp "选择: " sub
        case "$sub" in
            1) run_script "svcctl.sh" list; pause ;;
            2) read -rp "服务名: " svc; run_script "svcctl.sh" status "$svc"; pause ;;
            3) read -rp "服务名: " svc; run_script "svcctl.sh" start "$svc"; pause ;;
            4) read -rp "服务名: " svc; run_script "svcctl.sh" stop "$svc"; pause ;;
            5) read -rp "服务名: " svc; run_script "svcctl.sh" restart "$svc"; pause ;;
            6) read -rp "服务名: " svc; run_script "svcctl.sh" logs "$svc"; pause ;;
            7) run_script "svcctl.sh" failed; pause ;;
            0) break ;;
            *) echo -e "${RED}无效选择${NC}"; sleep 1 ;;
        esac
    done
}

# 菜单 3: 用户管理子菜单
menu_users() {
    while true; do
        show_header
        echo -e "${BOLD}用户管理：${NC}"
        echo -e "  ${GREEN}1.${NC}  列出用户"
        echo -e "  ${GREEN}2.${NC}  查看用户信息"
        echo -e "  ${GREEN}3.${NC}  新增用户"
        echo -e "  ${GREEN}4.${NC}  删除用户"
        echo -e "  ${GREEN}5.${NC}  修改密码"
        echo -e "  ${GREEN}6.${NC}  锁定/解锁用户"
        echo -e "  ${GREEN}7.${NC}  用户组管理"
        echo -e "  ${YELLOW}0.${NC}  返回上级"
        echo ""
        read -rp "选择: " sub
        case "$sub" in
            1) run_script "usermgr.sh" list; pause ;;
            2) read -rp "用户名: " u; run_script "usermgr.sh" info "$u"; pause ;;
            3) read -rp "用户名: " u; run_script "usermgr.sh" add "$u"; pause ;;
            4) read -rp "用户名: " u; run_script "usermgr.sh" del "$u"; pause ;;
            5) read -rp "用户名: " u; run_script "usermgr.sh" passwd "$u"; pause ;;
            6)
                read -rp "用户名: " u
                echo -e "  ${GREEN}1.${NC} 锁定   ${GREEN}2.${NC} 解锁"
                read -rp "操作: " op
                [ "$op" = "1" ] && run_script "usermgr.sh" lock "$u"
                [ "$op" = "2" ] && run_script "usermgr.sh" unlock "$u"
                pause ;;
            7) run_script "usermgr.sh" groups; pause ;;
            0) break ;;
            *) echo -e "${RED}无效选择${NC}"; sleep 1 ;;
        esac
    done
}

# 菜单 4: 系统清理
menu_cleanup() {
    while true; do
        show_header
        echo -e "${BOLD}系统清理：${NC}"
        echo -e "  ${GREEN}1.${NC}  预览所有清理（dry-run）"
        echo -e "  ${GREEN}2.${NC}  执行全部清理"
        echo -e "  ${GREEN}3.${NC}  仅清理 apt 缓存"
        echo -e "  ${GREEN}4.${NC}  仅清理临时文件"
        echo -e "  ${GREEN}5.${NC}  仅清理系统日志"
        echo -e "  ${YELLOW}0.${NC}  返回上级"
        echo ""
        read -rp "选择: " sub
        case "$sub" in
            1) run_script "cleanup.sh" --dry-run --all; pause ;;
            2) run_script "cleanup.sh" --all; pause ;;
            3) run_script "cleanup.sh" --cache; pause ;;
            4) run_script "cleanup.sh" --tmp; pause ;;
            5) run_script "cleanup.sh" --logs; pause ;;
            0) break ;;
            *) echo -e "${RED}无效选择${NC}"; sleep 1 ;;
        esac
    done
}

# 菜单 5: 磁盘使用分析
menu_disk() {
    show_header
    echo -e "${BOLD}磁盘使用分析：${NC}"
    echo ""
    echo -e "${CYAN}--- 文件系统 ---${NC}"
    df -h --total 2>/dev/null | grep -v 'tmpfs\|udev'
    echo ""
    echo -e "${CYAN}--- 当前目录下各子目录占用 Top 10 ---${NC}"
    du -sh */ 2>/dev/null | sort -rh | head -10
    echo ""
    echo -e "${CYAN}--- /var 目录占用 Top 10 ---${NC}"
    du -sh /var/* 2>/dev/null | sort -rh | head -10
    pause
}

# 菜单 6: 登录用户
menu_logged() {
    show_header
    echo -e "${BOLD}当前登录用户：${NC}"
    echo ""
    who | awk '{printf "  用户: %-15s 终端: %-10s 来源: %s  登录时间: %s %s\n", $1, $2, $3, $4, $5}'
    echo ""
    echo -e "${CYAN}最近登录记录：${NC}"
    last -n 10 2>/dev/null | head -10
    pause
}

# 菜单 7: 实时监控
menu_monitor() {
    show_header
    echo -e "${BOLD}系统资源实时监控（按 Ctrl+C 退出）：${NC}"
    echo ""
    if command -v top &>/dev/null; then
        top -d 2
    elif command -v htop &>/dev/null; then
        htop
    else
        echo -e "${YELLOW}未安装 top/htop，显示一次资源快照：${NC}"
        free -h
        echo ""
        ps aux --sort=-%cpu | head -10
        pause
    fi
}

# 菜单 8: 网络连接统计
menu_network() {
    show_header
    echo -e "${BOLD}网络连接统计：${NC}"
    echo ""
    if command -v ss &>/dev/null; then
        echo -e "${CYAN}--- 连接状态统计 ---${NC}"
        ss -s 2>/dev/null
        echo ""
        echo -e "${CYAN}--- 各端口连接数 Top 10 ---${NC}"
        ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oP ':\K\d+$' | sort | uniq -c | sort -rn | head -10
        echo ""
        echo -e "${CYAN}--- 活跃 TCP 连接 ---${NC}"
        ss -tn state established 2>/dev/null | head -20
    else
        echo -e "${YELLOW}未安装 ss 命令${NC}"
    fi
    pause
}

# 菜单 9: 启动项
menu_boot() {
    show_header
    echo -e "${BOLD}系统启动项：${NC}"
    echo ""
    if command -v systemctl &>/dev/null; then
        echo -e "${CYAN}--- 开机自启的服务 ---${NC}"
        systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null | head -30
    fi
    pause
}

# 主循环
main() {
    while true; do
        show_header
        show_menu
        read -rp "请输入选择 [0-9]: " choice
        case "$choice" in
            1) menu_sysinfo; pause ;;
            2) menu_services ;;
            3) menu_users ;;
            4) menu_cleanup ;;
            5) menu_disk ;;
            6) menu_logged ;;
            7) menu_monitor ;;
            8) menu_network ;;
            9) menu_boot ;;
            0)
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入。${NC}"
                sleep 1
                ;;
        esac
    done
}

main "$@"
