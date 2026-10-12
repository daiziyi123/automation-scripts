#!/usr/bin/env bash
# ============================================================
# cleanup.sh - 系统清理脚本
# 功能：清理 apt 缓存、临时文件、系统日志、回收站等
# 用法：./cleanup.sh [选项]
# 选项：
#   -a, --all        执行所有清理操作
#   -c, --cache      清理 apt 缓存
#   -t, --tmp        清理临时文件
#   -l, --logs       清理系统日志
#   -j, --journal    清理 systemd 日志
#   -d, --dry-run    仅显示将执行的操作，不实际删除
#   -h, --help       显示帮助
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=0

# 颜色输出
info()    { echo -e "${CYAN}[信息]${NC} $1"; }
warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }
success() { echo -e "${GREEN}[成功]${NC} $1"; }
error()   { echo -e "${RED}[错误]${NC} $1"; }

# 执行命令（dry-run 时仅显示）
run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${YELLOW}[模拟]${NC} $*"
    else
        eval "$@"
    fi
}

# 获取目录大小（KB）
get_size_kb() {
    du -sk "$1" 2>/dev/null | awk '{print $1}' || echo "0"
}

# 清理 apt 缓存
clean_apt_cache() {
    info "清理 apt 缓存..."
    if ! command -v apt &>/dev/null; then
        warn "未检测到 apt，跳过。"
        return
    fi
    local before after
    before=$(get_size_kb /var/cache/apt/archives)
    run_cmd "apt clean"
    run_cmd "apt autoremove -y"
    after=$(get_size_kb /var/cache/apt/archives)
    local freed=$((before - after))
    success "apt 缓存清理完成，释放约 $((freed / 1024)) MB"
}

# 清理临时文件
clean_tmp() {
    info "清理临时文件..."
    local before after
    before=$(get_size_kb /tmp)
    # 清理 /tmp 中超过 7 天的文件
    run_cmd "find /tmp -type f -atime +7 -delete 2>/dev/null"
    # 清理用户缓存
    run_cmd "find /root/.cache /home/*/.cache -type f -atime +7 -delete 2>/dev/null"
    after=$(get_size_kb /tmp)
    local freed=$((before - after))
    [ "$freed" -lt 0 ] && freed=0
    success "临时文件清理完成，释放约 $((freed / 1024)) MB"
}

# 清理系统日志
clean_logs() {
    info "清理系统日志..."
    local before after
    before=$(get_size_kb /var/log)
    # 清空已归档的压缩日志
    run_cmd "find /var/log -type f -name '*.gz' -delete 2>/dev/null"
    run_cmd "find /var/log -type f -name '*.1' -delete 2>/dev/null"
    # 截断过大的日志文件（>100MB）
    run_cmd "find /var/log -type f -size +100M -exec truncate -s 0 {} \; 2>/dev/null"
    after=$(get_size_kb /var/log)
    local freed=$((before - after))
    [ "$freed" -lt 0 ] && freed=0
    success "系统日志清理完成，释放约 $((freed / 1024)) MB"
}

# 清理 systemd journal 日志
clean_journal() {
    info "清理 systemd 日志..."
    if ! command -v journalctl &>/dev/null; then
        warn "未检测到 journalctl，跳过。"
        return
    fi
    local before after
    before=$(journalctl --disk-usage 2>/dev/null | awk '{print $2}' | sed 's/[^0-9.]//g')
    # 保留最近 3 天的日志，限制总大小 100M
    run_cmd "journalctl --vacuum-time=3d 2>/dev/null"
    run_cmd "journalctl --vacuum-size=100M 2>/dev/null"
    after=$(journalctl --disk-usage 2>/dev/null | awk '{print $2}' | sed 's/[^0-9.]//g')
    success "systemd 日志清理完成（当前占用: ${after:-0}M）"
}

# 清理回收站
clean_trash() {
    info "清理回收站..."
    local trash_dirs=("$HOME/.local/share/Trash" "/root/.local/share/Trash")
    for dir in "${trash_dirs[@]}"; do
        if [ -d "$dir" ]; then
            run_cmd "rm -rf '$dir'/*"
        fi
    done
    success "回收站清理完成。"
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --all        执行所有清理操作（apt缓存、临时文件、日志、回收站）"
    echo "  -c, --cache      仅清理 apt 缓存"
    echo "  -t, --tmp        仅清理临时文件"
    echo "  -l, --logs       仅清理系统日志"
    echo "  -j, --journal    仅清理 systemd 日志"
    echo "  -d, --dry-run    模拟运行，仅显示将执行的操作"
    echo "  -h, --help       显示此帮助"
    echo ""
    echo "示例:"
    echo "  $0 --dry-run --all    预览所有清理操作"
    echo "  $0 -c                 仅清理 apt 缓存"
    echo "  sudo $0 -a            执行全部清理（需 root）"
}

# 主流程
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local do_all=0 do_cache=0 do_tmp=0 do_logs=0 do_journal=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -a|--all)     do_all=1 ;;
            -c|--cache)   do_cache=1 ;;
            -t|--tmp)     do_tmp=1 ;;
            -l|--logs)    do_logs=1 ;;
            -j|--journal) do_journal=1 ;;
            -d|--dry-run) DRY_RUN=1 ;;
            -h|--help)    show_help; exit 0 ;;
            *)
                error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    echo -e "${CYAN}========== 系统清理 ==========${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "当前为模拟模式，不会实际删除文件。"
    fi
    echo ""

    if [ "$do_all" -eq 1 ]; then
        clean_apt_cache
        clean_tmp
        clean_logs
        clean_journal
        clean_trash
    else
        [ "$do_cache" -eq 1 ]   && clean_apt_cache
        [ "$do_tmp" -eq 1 ]     && clean_tmp
        [ "$do_logs" -eq 1 ]    && clean_logs
        [ "$do_journal" -eq 1 ] && clean_journal
    fi

    echo ""
    success "清理操作已完成。"
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "（模拟模式，未实际执行删除。去掉 -d 参数以实际执行。）"
    fi
}

main "$@"
