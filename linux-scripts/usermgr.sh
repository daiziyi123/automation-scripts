#!/usr/bin/env bash
# ============================================================
# usermgr.sh - 用户管理脚本
# 功能：管理 Linux 用户的增删查改、密码、用户组等
# 用法：./usermgr.sh <操作> [参数]
# 操作：
#   list                列出所有用户
#   info <用户名>       查看用户信息
#   add <用户名>        新增用户
#   del <用户名>        删除用户
#   passwd <用户名>     修改用户密码
#   lock <用户名>       锁定用户
#   unlock <用户名>     解锁用户
#   groups              列出所有用户组
#   groupadd <组名>     新增用户组
#   groupdel <组名>     删除用户组
#   help                显示帮助
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：用户管理操作需要 root 权限。${NC}"
        echo -e "${YELLOW}请使用 sudo 运行此脚本。${NC}"
        exit 1
    fi
}

check_username() {
    if [ -z "${1:-}" ]; then
        echo -e "${RED}错误：请指定用户名。${NC}"
        exit 1
    fi
}

# 检查用户是否存在
user_exists() {
    id "$1" &>/dev/null
}

# 列出所有用户
list_users() {
    echo -e "${CYAN}========== 用户列表 ==========${NC}"
    awk -F: '$3 >= 1000 {printf "  %-20s UID:%-6s 家目录: %s\n", $1, $3, $6}' /etc/passwd
    echo ""
    echo -e "${YELLOW}（仅显示 UID >= 1000 的普通用户）${NC}"
}

# 查看用户信息
user_info() {
    local user="$1"
    if ! user_exists "$user"; then
        echo -e "${RED}错误：用户 '$user' 不存在。${NC}"
        return 1
    fi
    echo -e "${CYAN}========== 用户 $user 信息 ==========${NC}"
    echo -e "  用户名:    $user"
    echo -e "  UID:       $(id -u "$user")"
    echo -e "  GID:       $(id -g "$user")"
    echo -e "  所属组:    $(id -Gn "$user")"
    echo -e "  家目录:    $(eval echo ~"$user")"
    echo -e "  Shell:     $(getent passwd "$user" | cut -d: -f7)"
    echo -e "  账号状态:  $(passwd -S "$user" 2>/dev/null | awk '{print $2}')"
}

# 新增用户
user_add() {
    local user="$1"
    if user_exists "$user"; then
        echo -e "${RED}错误：用户 '$user' 已存在。${NC}"
        return 1
    fi
    echo -e "${YELLOW}正在创建用户 '$user' ...${NC}"
    useradd -m -s /bin/bash "$user"
    echo -e "${GREEN}✓ 用户 '$user' 已创建。${NC}"
    echo -e "${YELLOW}请为新用户设置密码：${NC}"
    passwd "$user"
}

# 删除用户
user_del() {
    local user="$1"
    if ! user_exists "$user"; then
        echo -e "${RED}错误：用户 '$user' 不存在。${NC}"
        return 1
    fi
    if [ "$user" = "root" ]; then
        echo -e "${RED}错误：不能删除 root 用户！${NC}"
        return 1
    fi
    echo -e "${YELLOW}将删除用户 '$user' 及其家目录。${NC}"
    read -rp "确认删除？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        userdel -r "$user"
        echo -e "${GREEN}✓ 用户 '$user' 已删除。${NC}"
    else
        echo "已取消。"
    fi
}

# 修改密码
user_passwd() {
    local user="$1"
    if ! user_exists "$user"; then
        echo -e "${RED}错误：用户 '$user' 不存在。${NC}"
        return 1
    fi
    passwd "$user"
}

# 锁定用户
user_lock() {
    local user="$1"
    if ! user_exists "$user"; then
        echo -e "${RED}错误：用户 '$user' 不存在。${NC}"
        return 1
    fi
    passwd -l "$user"
    echo -e "${GREEN}✓ 用户 '$user' 已锁定。${NC}"
}

# 解锁用户
user_unlock() {
    local user="$1"
    if ! user_exists "$user"; then
        echo -e "${RED}错误：用户 '$user' 不存在。${NC}"
        return 1
    fi
    passwd -u "$user"
    echo -e "${GREEN}✓ 用户 '$user' 已解锁。${NC}"
}

# 列出用户组
list_groups() {
    echo -e "${CYAN}========== 用户组列表 ==========${NC}"
    awk -F: '$3 >= 1000 {printf "  %-20s GID:%s\n", $1, $3}' /etc/group
}

# 新增用户组
group_add() {
    local group="$1"
    if getent group "$group" &>/dev/null; then
        echo -e "${RED}错误：用户组 '$group' 已存在。${NC}"
        return 1
    fi
    groupadd "$group"
    echo -e "${GREEN}✓ 用户组 '$group' 已创建。${NC}"
}

# 删除用户组
group_del() {
    local group="$1"
    if ! getent group "$group" &>/dev/null; then
        echo -e "${RED}错误：用户组 '$group' 不存在。${NC}"
        return 1
    fi
    groupdel "$group"
    echo -e "${GREEN}✓ 用户组 '$group' 已删除。${NC}"
}

# 帮助
show_help() {
    echo "用法: $0 <操作> [参数]"
    echo ""
    echo "操作:"
    echo "  list                列出所有用户"
    echo "  info <用户名>       查看用户信息"
    echo "  add <用户名>        新增用户"
    echo "  del <用户名>        删除用户"
    echo "  passwd <用户名>     修改用户密码"
    echo "  lock <用户名>       锁定用户"
    echo "  unlock <用户名>     解锁用户"
    echo "  groups              列出所有用户组"
    echo "  groupadd <组名>     新增用户组"
    echo "  groupdel <组名>     删除用户组"
    echo "  help                显示此帮助"
    echo ""
    echo "注意：除 list/info/groups 外，其他操作需要 root 权限。"
}

# 主流程
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local action="$1"
    shift

    case "$action" in
        list)        list_users ;;
        info)        check_username "${1:-}"; user_info "$1" ;;
        add)         check_root; check_username "${1:-}"; user_add "$1" ;;
        del)         check_root; check_username "${1:-}"; user_del "$1" ;;
        passwd)      check_root; check_username "${1:-}"; user_passwd "$1" ;;
        lock)        check_root; check_username "${1:-}"; user_lock "$1" ;;
        unlock)      check_root; check_username "${1:-}"; user_unlock "$1" ;;
        groups)      list_groups ;;
        groupadd)    check_root; check_username "${1:-}"; group_add "$1" ;;
        groupdel)    check_root; check_username "${1:-}"; group_del "$1" ;;
        help|-h|--help) show_help ;;
        *)
            echo -e "${RED}未知操作: $action${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
