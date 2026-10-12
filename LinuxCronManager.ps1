<#
.SYNOPSIS
    Linux 定时任务管理脚本 - 通过 WSL/Git Bash 管理 crontab

.DESCRIPTION
    在 Windows 环境下通过 WSL 或 Git Bash 管理 Linux crontab 定时任务，支持：
    1. 列出当前所有定时任务（带行号）
    2. 新增定时任务（支持 cron 表达式校验）
    3. 按行号删除定时任务
    4. 清空所有定时任务
    5. 备份/恢复 crontab
    6. 查看 cron 执行日志

.PARAMETER Action
    操作类型：List | Add | Remove | Clear | Backup | Restore | Logs

.PARAMETER Schedule
    cron 表达式，例如 "*/5 * * * *"

.PARAMETER Command
    要执行的命令，例如 "/usr/bin/echo hello >> /tmp/cron.log"

.PARAMETER LineNumber
    要删除的任务行号（从 1 开始）

.PARAMETER Backend
    Linux 运行环境：Auto | WSL | GitBash，默认 Auto 自动检测

.PARAMETER Comment
    任务备注说明

.EXAMPLE
    # 列出所有定时任务
    .\LinuxCronManager.ps1 -Action List

.EXAMPLE
    # 新增一个每 5 分钟执行的任务
    .\LinuxCronManager.ps1 -Action Add -Schedule "*/5 * * * *" -Command "/usr/bin/date >> /tmp/cron.log" -Comment "每5分钟记录时间"

.EXAMPLE
    # 删除第 3 行的定时任务
    .\LinuxCronManager.ps1 -Action Remove -LineNumber 3

.EXAMPLE
    # 清空所有定时任务
    .\LinuxCronManager.ps1 -Action Clear

.EXAMPLE
    # 备份当前 crontab
    .\LinuxCronManager.ps1 -Action Backup
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('List', 'Add', 'Remove', 'Clear', 'Backup', 'Restore', 'Logs')]
    [string]$Action,

    [string]$Schedule,

    [string]$Command,

    [int]$LineNumber,

    [ValidateSet('Auto', 'WSL', 'GitBash')]
    [string]$Backend = 'Auto',

    [string]$Comment,

    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'

# ============================================================
# 验证 WSL 是否有可用的 Linux 发行版
# ============================================================
function Test-WslDistro {
    # 执行一个简单命令，如果返回 WSL_HELP 则说明无可用发行版
    $output = & wsl -- echo WSL_DISTRO_OK 2>&1 | Out-String
    return $output -match 'WSL_DISTRO_OK'
}

# ============================================================
# 检测可用的 Linux 运行环境
# ============================================================
function Get-LinuxBackend {
    param([string]$Preferred)

    if ($Preferred -eq 'WSL') {
        if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
            throw '未检测到 WSL，请先安装 Windows Subsystem for Linux。'
        }
        if (-not (Test-WslDistro)) {
            throw 'WSL 已安装但未安装 Linux 发行版。请运行 "wsl --install -d Ubuntu" 安装。'
        }
        return 'WSL'
    }

    if ($Preferred -eq 'GitBash') {
        $gitBash = Get-Command bash -ErrorAction SilentlyContinue
        if ($gitBash) { return 'GitBash' }
        throw '未检测到 Git Bash，请先安装 Git for Windows。'
    }

    # Auto 模式：优先 WSL，其次 Git Bash
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        if (Test-WslDistro) {
            return 'WSL'
        }
    }
    $gitBash = Get-Command bash -ErrorAction SilentlyContinue
    if ($gitBash) {
        return 'GitBash'
    }
    throw '未检测到可用的 Linux 运行环境。请安装 WSL 发行版（wsl --install -d Ubuntu）或 Git Bash。'
}

# ============================================================
# 在 Linux 环境中执行命令
# ============================================================
function Invoke-LinuxCommand {
    param(
        [string]$Command,
        [string]$Backend
    )

    if ($Backend -eq 'WSL') {
        $output = & wsl bash -lc $Command 2>&1
    }
    else {
        # Git Bash
        $output = & bash -lc $Command 2>&1
    }

    # 合并输出并转换为字符串
    $result = ($output | Out-String).Trim()
    return $result
}

# ============================================================
# 校验 cron 表达式（基本格式校验）
# ============================================================
function Test-CronExpression {
    param([string]$Expression)

    # cron 表达式格式：分 时 日 月 周
    $fields = $Expression.Trim() -split '\s+'
    if ($fields.Count -ne 5) {
        return $false
    }

    # 每个字段允许的字符：数字、* / , -
    $validPattern = '^[\d*/,\-]+$'
    foreach ($field in $fields) {
        if ($field -notmatch $validPattern) {
            return $false
        }
    }
    return $true
}

# ============================================================
# 获取当前 crontab 内容（返回行数组）
# ============================================================
function Get-CrontabContent {
    param([string]$Backend)

    $raw = Invoke-LinuxCommand -Command 'crontab -l 2>/dev/null' -Backend $Backend
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }
    return $raw -split "`n" | Where-Object { $_.Trim() -ne '' }
}

# ============================================================
# 主流程
# ============================================================
Write-Host "========== Linux 定时任务管理 ==========" -ForegroundColor Cyan

try {
    $backend = Get-LinuxBackend -Preferred $Backend
    Write-Host "运行环境: $backend" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "错误: $_" -ForegroundColor Red
    exit 1
}

switch ($Action) {
    'List' {
        Write-Host "当前 crontab 定时任务列表：" -ForegroundColor Green
        Write-Host "----------------------------------------"
        $lines = Get-CrontabContent -Backend $backend
        if ($lines.Count -eq 0) {
            Write-Host "（无定时任务）" -ForegroundColor Yellow
        }
        else {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                Write-Host ("{0,3}. {1}" -f ($i + 1), $lines[$i])
            }
        }
        Write-Host "----------------------------------------"
        Write-Host "共 $($lines.Count) 条任务"
    }

    'Add' {
        if (-not $Schedule -or -not $Command) {
            Write-Host "错误：新增任务必须指定 -Schedule 和 -Command 参数。" -ForegroundColor Red
            exit 1
        }

        if (-not (Test-CronExpression -Expression $Schedule)) {
            Write-Host "错误：cron 表达式格式无效，应为 5 个字段（分 时 日 月 周），例如 '*/5 * * * *'" -ForegroundColor Red
            exit 1
        }

        # 构建任务行
        $taskLine = "$Schedule $Command"
        if ($Comment) {
            $taskLine = "$taskLine # $Comment"
        }

        Write-Host "新增任务：" -ForegroundColor Green
        Write-Host "  $taskLine"
        Write-Host ""

        # 获取现有内容并追加
        $existing = Get-CrontabContent -Backend $backend
        $newContent = $existing + $taskLine

        # 写入 crontab（通过临时文件）
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            $newContent | Set-Content -Path $tempFile -Encoding UTF8 -NoNewline:$false

            if ($backend -eq 'WSL') {
                # 将 Windows 临时文件路径转换为 WSL 路径并安装
                $wslPath = & wsl wslpath -a $tempFile 2>$null
                if (-not $wslPath) {
                    # 手动转换
                    $wslPath = '/mnt/' + $tempFile.Substring(0,1).ToLower() + $tempFile.Substring(2).Replace('\','/')
                }
                & wsl crontab $wslPath
            }
            else {
                & bash -lc "crontab '$tempFile'"
            }

            Write-Host "任务已成功添加到 crontab。" -ForegroundColor Green
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    'Remove' {
        if ($LineNumber -le 0) {
            Write-Host "错误：请指定有效的 -LineNumber（从 1 开始）。" -ForegroundColor Red
            exit 1
        }

        $lines = Get-CrontabContent -Backend $backend
        if ($lines.Count -eq 0) {
            Write-Host "当前没有定时任务，无需删除。" -ForegroundColor Yellow
            exit 0
        }

        if ($LineNumber -gt $lines.Count) {
            Write-Host "错误：行号 $LineNumber 超出范围，当前共 $($lines.Count) 条任务。" -ForegroundColor Red
            exit 1
        }

        $removed = $lines[$LineNumber - 1]
        Write-Host "将删除任务：" -ForegroundColor Yellow
        Write-Host "  $removed"
        $confirm = Read-Host "确认删除？(y/N)"
        if ($confirm -notmatch '^[yY]') {
            Write-Host "已取消。"
            exit 0
        }

        $newLines = $lines | Where-Object { $_ -ne $removed }
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            if ($newLines.Count -gt 0) {
                $newLines | Set-Content -Path $tempFile -Encoding UTF8
            }
            else {
                Set-Content -Path $tempFile -Value '' -Encoding UTF8
            }

            if ($backend -eq 'WSL') {
                $wslPath = & wsl wslpath -a $tempFile 2>$null
                if (-not $wslPath) {
                    $wslPath = '/mnt/' + $tempFile.Substring(0,1).ToLower() + $tempFile.Substring(2).Replace('\','/')
                }
                & wsl crontab $wslPath
            }
            else {
                & bash -lc "crontab '$tempFile'"
            }

            Write-Host "任务已删除。" -ForegroundColor Green
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    'Clear' {
        $lines = Get-CrontabContent -Backend $backend
        if ($lines.Count -eq 0) {
            Write-Host "当前没有定时任务。" -ForegroundColor Yellow
            exit 0
        }

        Write-Host "将清空所有 $($lines.Count) 条定时任务！" -ForegroundColor Yellow
        $confirm = Read-Host "确认清空？输入 YES 继续"
        if ($confirm -ne 'YES') {
            Write-Host "已取消。"
            exit 0
        }

        Invoke-LinuxCommand -Command 'crontab -r' -Backend $backend | Out-Null
        Write-Host "所有定时任务已清空。" -ForegroundColor Green
    }

    'Backup' {
        $lines = Get-CrontabContent -Backend $backend
        if ($lines.Count -eq 0) {
            Write-Host "当前没有定时任务，无需备份。" -ForegroundColor Yellow
            exit 0
        }

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupDir = Join-Path $PSScriptRoot 'cron_backups'
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        $backupFile = Join-Path $backupDir "crontab_backup_$timestamp.txt"
        $lines | Set-Content -Path $backupFile -Encoding UTF8

        Write-Host "crontab 已备份到：" -ForegroundColor Green
        Write-Host "  $backupFile"
    }

    'Restore' {
        if (-not $BackupPath) {
            $backupDir = Join-Path $PSScriptRoot 'cron_backups'
            $backups = Get-ChildItem -Path $backupDir -Filter 'crontab_backup_*.txt' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending

            if ($backups.Count -eq 0) {
                Write-Host "未找到备份文件，请使用 -BackupPath 指定。" -ForegroundColor Red
                exit 1
            }

            Write-Host "可用的备份文件：" -ForegroundColor Green
            for ($i = 0; $i -lt $backups.Count; $i++) {
                Write-Host ("{0,3}. {1}  ({2})" -f ($i+1), $backups[$i].Name, $backups[$i].LastWriteTime)
            }
            $choice = Read-Host "选择要恢复的备份编号"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $backups.Count) {
                $BackupPath = $backups[[int]$choice - 1].FullName
            }
            else {
                Write-Host "无效选择，已取消。" -ForegroundColor Red
                exit 1
            }
        }

        if (-not (Test-Path $BackupPath)) {
            Write-Host "错误：备份文件不存在 - $BackupPath" -ForegroundColor Red
            exit 1
        }

        $content = Get-Content -Path $BackupPath -Encoding UTF8
        Write-Host "将恢复以下 crontab 内容：" -ForegroundColor Yellow
        $content | ForEach-Object { Write-Host "  $_" }

        $confirm = Read-Host "确认恢复？(y/N)"
        if ($confirm -notmatch '^[yY]') {
            Write-Host "已取消。"
            exit 0
        }

        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            $content | Set-Content -Path $tempFile -Encoding UTF8
            if ($backend -eq 'WSL') {
                $wslPath = & wsl wslpath -a $tempFile 2>$null
                if (-not $wslPath) {
                    $wslPath = '/mnt/' + $tempFile.Substring(0,1).ToLower() + $tempFile.Substring(2).Replace('\','/')
                }
                & wsl crontab $wslPath
            }
            else {
                & bash -lc "crontab '$tempFile'"
            }
            Write-Host "crontab 已从备份恢复。" -ForegroundColor Green
        }
        finally {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    'Logs' {
        Write-Host "最近的 cron 执行日志：" -ForegroundColor Green
        Write-Host "----------------------------------------"
        # 尝试多种日志路径
        $logCmd = @'
if [ -f /var/log/syslog ]; then
  grep CRON /var/log/syslog | tail -20
elif [ -f /var/log/cron ]; then
  tail -20 /var/log/cron
elif command -v journalctl &>/dev/null; then
  journalctl -u cron --no-pager -n 20 2>/dev/null || journalctl -u crond --no-pager -n 20 2>/dev/null
else
  echo "未找到 cron 日志文件"
fi
'@
        $logs = Invoke-LinuxCommand -Command $logCmd -Backend $backend
        if ($logs) {
            Write-Host $logs
        }
        else {
            Write-Host "（无 cron 日志输出）" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "========== 操作完成 ==========" -ForegroundColor Cyan
