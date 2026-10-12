# Linux 命令控制环境与脚本说明

## 概述

本文档记录在 Windows 环境下搭建 Linux 命令运行环境（WSL Ubuntu）、编写定时任务管理脚本 `LinuxCronManager.ps1`、以及创建 Linux 原生管理脚本集（`linux-scripts/`）的全过程，并包含 WSL 使用指南和常用 Linux 命令参考。

## 一、环境搭建

### 1.1 需求背景

需要在 Windows 系统上执行和管理 Linux 命令（特别是 crontab 定时任务），但本机既未安装 WSL Linux 发行版，也未安装 Git Bash。

### 1.2 环境检测结果（安装前）

| 组件 | 检测结果 |
|------|----------|
| WSL (wsl.exe) | 已安装，但无 Linux 发行版 |
| Git Bash | 未安装 |
| PowerShell | 5.1+ |

### 1.3 安装步骤

执行以下命令安装 WSL Ubuntu：

```powershell
wsl --install -d Ubuntu --no-launch
```

安装过程自动完成以下组件：

| 组件 | 说明 |
|------|------|
| 虚拟机平台 | WSL2 运行的基础虚拟化组件 |
| 适用于 Linux 的 Windows 子系统 | WSL 核心组件 |
| Ubuntu | Linux 发行版 |

### 1.4 重启生效

安装完成后**必须重启系统**才能生效（错误码：`WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED`）。

```powershell
shutdown /r /t 5
```

### 1.5 安装后状态

| 项 | 值 |
|----|-----|
| 发行版 | Ubuntu 26.04.1 LTS |
| 内核 | 6.18.40.1-microsoft-standard-WSL2 |
| 架构 | x86_64 |
| 验证命令 | `wsl -- bash -c 'uname -a && cat /etc/os-release \| head -3'` |

---

## 二、WSL 使用指南

### 2.1 进入 WSL

| 方式 | 操作 |
|------|------|
| 开始菜单 | 搜索 **Ubuntu** 并打开 |
| PowerShell | `wsl` 或 `wsl -d Ubuntu` |
| Windows Terminal | 下拉菜单选择 Ubuntu |

### 2.2 文件系统映射

| Windows 路径 | WSL 路径 |
|-------------|----------|
| `C:\` | `/mnt/c/` |
| `D:\` | `/mnt/d/` |
| `E:\` | `/mnt/e/` |
| `E:\automation-scripts\linux-scripts` | `/mnt/e/automation-scripts/linux-scripts` |

> WSL 的 Linux 文件系统在 Windows 中通过 `\\wsl$\Ubuntu\` 访问。

### 2.3 运行 Linux 命令的三种方式

```powershell
# 方式1：进入 WSL 交互终端
wsl

# 方式2：从 Windows 直接执行单条命令
wsl -- ls -la /home
wsl -- df -h
wsl -- bash -c 'echo hello && uname -a'

# 方式3：从 Windows 执行脚本
wsl -- bash /mnt/e/automation-scripts/linux-scripts/sysinfo.sh --all
wsl -- bash -c 'cd /mnt/e/automation-scripts/linux-scripts && ./admin-menu.sh'
```

### 2.4 WSL 管理命令（Windows 侧执行）

```powershell
wsl --list --verbose          # 查看已安装的发行版
wsl -d Ubuntu                 # 进入指定发行版
wsl --shutdown                # 关闭所有 WSL 实例
wsl --update                  # 更新 WSL
wsl --terminate Ubuntu        # 终止指定发行版
wsl --unregister Ubuntu       # 注销（删除）发行版
```

### 2.5 实用技巧

| 技巧 | 说明 |
|------|------|
| 复制粘贴 | `Ctrl+Shift+C` 复制，`Ctrl+Shift+V` 粘贴 |
| 调用 Windows 程序 | WSL 中可直接运行 `notepad.exe`、`explorer.exe .` |
| 打开资源管理器 | `explorer.exe .` 在资源管理器打开当前 WSL 目录 |
| 用 VS Code 编辑 | `code .` |
| 网络互通 | WSL 与 Windows 共享网络，`localhost` 互通 |

---

## 三、定时任务管理脚本（Windows 侧）

### 3.1 脚本信息

- **文件**：`LinuxCronManager.ps1`
- **功能**：在 Windows 上通过 WSL/Git Bash 管理 Linux crontab 定时任务
- **运行环境**：PowerShell 5.1+

### 3.2 支持的操作

| Action | 功能 | 关键参数 |
|--------|------|----------|
| `List` | 列出所有定时任务（带行号） | — |
| `Add` | 新增定时任务 | `-Schedule` `-Command` `-Comment` |
| `Remove` | 按行号删除任务 | `-LineNumber` |
| `Clear` | 清空所有任务 | — |
| `Backup` | 备份当前 crontab | — |
| `Restore` | 从备份恢复 | `-BackupPath`（可选） |
| `Logs` | 查看 cron 执行日志 | — |

### 3.3 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-Action` | string | （必填） | 操作类型 |
| `-Schedule` | string | — | cron 表达式，如 `*/5 * * * *` |
| `-Command` | string | — | 要执行的 Linux 命令 |
| `-LineNumber` | int | — | 要删除的任务行号（从 1 开始） |
| `-Backend` | string | `Auto` | Linux 运行环境：`Auto` / `WSL` / `GitBash` |
| `-Comment` | string | — | 任务备注说明 |
| `-BackupPath` | string | — | 备份文件路径（Restore 时可选） |

### 3.4 使用示例

```powershell
# 列出所有定时任务
.\LinuxCronManager.ps1 -Action List

# 新增：每 5 分钟记录时间到日志
.\LinuxCronManager.ps1 -Action Add -Schedule "*/5 * * * *" -Command "/usr/bin/date >> /tmp/cron.log" -Comment "每5分钟记录时间"

# 删除第 3 行任务
.\LinuxCronManager.ps1 -Action Remove -LineNumber 3

# 清空所有任务（需输入 YES 确认）
.\LinuxCronManager.ps1 -Action Clear

# 备份当前 crontab
.\LinuxCronManager.ps1 -Action Backup

# 从备份恢复（可选 -BackupPath）
.\LinuxCronManager.ps1 -Action Restore

# 查看 cron 执行日志
.\LinuxCronManager.ps1 -Action Logs
```

### 3.5 脚本特性

- **自动环境检测**：优先使用 WSL，其次 Git Bash，均不可用时给出明确提示
- **WSL 发行版校验**：检测 WSL 是否真正安装了可用的 Linux 发行版
- **cron 表达式校验**：新增任务时校验 5 字段格式（分 时 日 月 周）
- **安全操作**：删除和清空前需二次确认
- **备份恢复机制**：自动将 crontab 备份到 `cron_backups/` 目录
- **临时文件自动清理**：操作完成后清理临时文件

### 3.6 工作原理

```
Windows PowerShell
       │
       ▼
┌─────────────────┐
│ LinuxCronManager│
│     .ps1        │
└────────┬────────┘
         │ 检测环境
    ┌────┴────┐
    ▼         ▼
   WSL     Git Bash
    │         │
    ▼         ▼
  crontab   crontab
```

---

## 四、Linux 原生管理脚本集

位于 `linux-scripts/` 目录，在 WSL 中直接运行（Bash 脚本）。

### 4.1 脚本清单

| 脚本 | 功能 |
|------|------|
| `sysinfo.sh` | 系统信息查看（CPU/内存/磁盘/网络/系统） |
| `svcctl.sh` | systemd 服务管理（启停/重启/自启/日志） |
| `usermgr.sh` | 用户/用户组管理（增删查改/密码/锁定） |
| `cleanup.sh` | 系统清理（apt缓存/临时文件/日志/回收站） |
| `admin-menu.sh` | 统一管理菜单（整合以上全部功能） |

### 4.2 sysinfo.sh — 系统信息

```bash
./sysinfo.sh --all        # 显示所有信息
./sysinfo.sh --cpu        # 仅 CPU
./sysinfo.sh --memory     # 仅内存
./sysinfo.sh --disk       # 仅磁盘
./sysinfo.sh --network    # 仅网络
./sysinfo.sh --system     # 仅系统
```

### 4.3 svcctl.sh — 服务管理

```bash
./svcctl.sh list                # 列出所有服务
./svcctl.sh status nginx        # 查看服务状态
./svcctl.sh start nginx         # 启动
./svcctl.sh stop nginx          # 停止
./svcctl.sh restart nginx       # 重启
./svcctl.sh enable ssh          # 开机自启
./svcctl.sh disable ssh         # 取消自启
./svcctl.sh logs nginx          # 查看日志
./svcctl.sh failed              # 查看失败的服务
```

### 4.4 usermgr.sh — 用户管理

```bash
./usermgr.sh list               # 列出用户
./usermgr.sh info <用户名>       # 用户信息
./usermgr.sh add <用户名>        # 新增用户（需 root）
./usermgr.sh del <用户名>        # 删除用户（需 root）
./usermgr.sh passwd <用户名>     # 修改密码
./usermgr.sh lock <用户名>       # 锁定用户
./usermgr.sh unlock <用户名>     # 解锁用户
./usermgr.sh groups             # 列出用户组
```

### 4.5 cleanup.sh — 系统清理

```bash
./cleanup.sh --dry-run --all    # 预览所有清理（不实际删除）
sudo ./cleanup.sh --all         # 执行全部清理
./cleanup.sh --cache            # 仅清理 apt 缓存
./cleanup.sh --tmp              # 仅清理临时文件
./cleanup.sh --logs             # 仅清理系统日志
./cleanup.sh --journal          # 仅清理 systemd 日志
```

### 4.6 admin-menu.sh — 统一菜单

```bash
./admin-menu.sh
```

交互式菜单，整合系统信息、服务管理、用户管理、系统清理、磁盘分析、登录用户、资源监控、网络统计、启动项等功能。

---

## 五、常用 Linux 命令参考

以下是 `sysinfo.sh` 中用到的核心命令，按用途分类。

### 5.1 文本处理三件套（黄金组合）

| 命令 | 作用 | 示例 |
|------|------|------|
| `grep` | 按内容筛选行 | `grep 'model name' /proc/cpuinfo` |
| `cut` | 按分隔符取列 | `cut -d: -f2` 取第2列 |
| `awk` | 可编程逐行处理 | `awk '{print $3}'` 打印第3列 |

三者常通过管道 `|` 串联：
```bash
grep 'model name' /proc/cpuinfo | cut -d: -f2 | xargs
```

### 5.2 系统信息命令

| 命令 | 作用 |
|------|------|
| `uname -a` | 内核与系统信息 |
| `uname -m` | 机器架构（x86_64） |
| `uname -r` | 内核版本 |
| `nproc` | CPU 核心数 |
| `lscpu` | CPU 详细信息 |
| `free -h` | 内存使用情况 |
| `uptime` | 运行时间与负载 |
| `hostname` | 主机名 |
| `whoami` | 当前用户名 |
| `id -u` | 当前用户 UID |
| `who` | 登录用户列表 |
| `ps aux` | 所有进程列表 |
| `wc -l` | 统计行数 |

### 5.3 磁盘命令

| 命令 | 作用 |
|------|------|
| `df -h` | 文件系统磁盘使用 |
| `du -sh */` | 各子目录占用大小 |
| `sort -rh` | 倒序+人类可读排序 |
| `head -10` | 取前10行 |

### 5.4 网络命令

| 命令 | 作用 |
|------|------|
| `ip -br addr` | 网络接口与地址（简洁） |
| `ss -tlnp` | TCP 监听端口 |
| `ifconfig` | 旧版网络配置（备选） |
| `netstat -tlnp` | 旧版端口查看（备选） |

### 5.5 其他实用命令

| 命令 | 作用 |
|------|------|
| `xargs` | 去除首尾空格 / 参数传递 |
| `tr -d '"'` | 删除指定字符（删除双引号） |
| `command -v <cmd>` | 检查命令是否存在 |
| `echo -e` | 输出并解析转义字符 |

---

## 六、常见问题

### Q1: 运行脚本提示"未检测到可用的 Linux 运行环境"

**原因**：未安装 WSL 发行版或 Git Bash。

**解决**：
```powershell
wsl --install -d Ubuntu
# 安装后重启系统
```

### Q2: cron 任务不执行

**排查步骤**：
1. 确认 cron 服务已启动：`wsl sudo service cron start`
2. 查看 cron 日志：`.\LinuxCronManager.ps1 -Action Logs`
3. 确认命令使用绝对路径（如 `/usr/bin/date` 而非 `date`）
4. 手动测试命令是否可执行

### Q3: WSL 中提示 `command not found`

**原因**：软件未安装。

**解决**：`sudo apt update && sudo apt install <命令名>`

### Q4: WSL 中提示 `Permission denied`

**解决**：命令前加 `sudo`，或用 `chmod +x <文件>` 赋予执行权限。

### Q5: cron 表达式格式

```
* * * * * command
│ │ │ │ │
│ │ │ │ └── 星期几 (0-7，0 和 7 都表示周日)
│ │ │ └──── 月份 (1-12)
│ │ └────── 日期 (1-31)
│ └──────── 小时 (0-23)
└────────── 分钟 (0-59)
```

| 表达式 | 含义 |
|--------|------|
| `* * * * *` | 每分钟 |
| `*/5 * * * *` | 每 5 分钟 |
| `0 * * * *` | 每小时整点 |
| `0 0 * * *` | 每天凌晨 0 点 |
| `0 9 * * 1-5` | 工作日每天 9 点 |

---

## 七、项目结构

```
automation-scripts/
├── DiskMonitor.ps1              # 磁盘监控脚本
├── LinuxCronManager.ps1         # Linux 定时任务管理脚本（Windows 侧）
├── docs/
│   ├── DiskMonitor.md           # 磁盘监控脚本说明
│   └── LinuxCronManager.md      # 本文档
├── linux-scripts/               # Linux 原生管理脚本集
│   ├── sysinfo.sh               # 系统信息
│   ├── svcctl.sh                # 服务管理
│   ├── usermgr.sh               # 用户管理
│   ├── cleanup.sh               # 系统清理
│   └── admin-menu.sh            # 统一管理菜单
└── logs/                        # 磁盘监控日志（gitignore）
```
