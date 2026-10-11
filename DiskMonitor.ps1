<#
.SYNOPSIS
    磁盘监控脚本 - 监控 C/D/E 盘存储空间占用及当日新增/删除文件

.DESCRIPTION
    1. 输出 C/D/E 盘的总容量、已用空间、剩余空间及占用率
    2. 扫描当日新增文件（基于 CreationTime）
    3. 基于快照对比，输出当日删除的文件
    4. 结果同时输出到控制台和日志文件

.NOTES
    删除文件的检测依赖前一次运行时生成的快照文件。
    首次运行仅生成快照，无法报告删除文件。
    建议每天定时运行一次（可使用 Windows 任务计划程序）。
#>

param(
    # 要监控的盘符列表
    [string[]]$Drives = @('C', 'D', 'E'),

    # 日志与快照存放目录
    [string]$OutputDir = 'E:\automation-scripts\logs',

    # 新增文件扫描的目录深度（0 表示不限制）
    [int]$NewFileDepth = 0,

    # 是否生成删除文件快照
    [switch]$NoSnapshot
)

# ============================================================
# 初始化
# ============================================================
$ErrorActionPreference = 'Continue'
$today = Get-Date -Format 'yyyy-MM-dd'
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$logFile = Join-Path $OutputDir "DiskMonitor_$today.log"
$snapshotDir = Join-Path $OutputDir 'snapshots'
if (-not (Test-Path -LiteralPath $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
}

# 日志函数：同时写入控制台和日志文件
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Write-Log "========== 磁盘监控开始 =========="
Write-Log "运行时间: $timestamp"

# ============================================================
# 1. 存储空间占用
# ============================================================
Write-Log ""
Write-Log "---------- 1. 存储空间占用 ----------"

$diskReport = foreach ($drive in $Drives) {
    $driveLetter = $drive.TrimEnd(':')
    $drivePath = $driveLetter + ':\'

    if (-not (Test-Path -LiteralPath $drivePath)) {
        Write-Log "盘符 $drivePath 不存在，跳过。" -Level 'WARN'
        continue
    }

    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$driveLetter`:'"
    if (-not $disk) {
        Write-Log "无法获取 $drivePath 的磁盘信息。" -Level 'WARN'
        continue
    }

    $totalGB = [math]::Round($disk.Size / 1GB, 2)
    $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB  = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
    $usedPercent = if ($disk.Size -gt 0) {
        [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
    } else { 0 }

    $volumeName = if ($disk.VolumeName) { $disk.VolumeName } else { '(无卷标)' }

    $info = [PSCustomObject]@{
        盘符        = $drivePath
        卷标        = $volumeName
        总容量_GB   = $totalGB
        已用_GB     = $usedGB
        剩余_GB     = $freeGB
        占用率      = "$usedPercent%"
    }
    $info
}

# 输出表格
$diskReport | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
$diskReport | Format-Table -AutoSize | Out-String | ForEach-Object { Add-Content -Path $logFile -Value $_ -Encoding UTF8 }

# ============================================================
# 2. 当日新增文件（基于 CreationTime）
# ============================================================
Write-Log ""
Write-Log "---------- 2. 当日新增文件 ----------"

$todayStart = (Get-Date).Date
$todayEnd   = $todayStart.AddDays(1)

$newFiles = @()
foreach ($drive in $Drives) {
    $drivePath = $drive.TrimEnd(':') + ':\'
    if (-not (Test-Path -LiteralPath $drivePath)) { continue }

    Write-Log "正在扫描 $drivePath 新增文件..."
    try {
        $gciParams = @{
            Path        = $drivePath
            Recurse     = $true
            File        = $true
            Force       = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($NewFileDepth -gt 0) {
            $gciParams['Depth'] = $NewFileDepth
        }

        Get-ChildItem @gciParams | Where-Object {
            $_.CreationTime -ge $todayStart -and $_.CreationTime -lt $todayEnd
        } | ForEach-Object {
            $newFiles += [PSCustomObject]@{
                盘符         = $drivePath
                完整路径     = $_.FullName
                大小_KB      = [math]::Round($_.Length / 1KB, 2)
                创建时间     = $_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
    }
    catch {
        Write-Log "扫描 $drivePath 新增文件出错: $_" -Level 'ERROR'
    }
}

if ($newFiles.Count -gt 0) {
    Write-Log "当日新增文件共 $($newFiles.Count) 个:"
    $newFiles | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    $newFiles | Format-Table -AutoSize | Out-String | ForEach-Object { Add-Content -Path $logFile -Value $_ -Encoding UTF8 }

    $newFileCsv = Join-Path $OutputDir "NewFiles_$today.csv"
    $newFiles | Export-Csv -Path $newFileCsv -NoTypeInformation -Encoding UTF8
    Write-Log "新增文件清单已导出: $newFileCsv"
}
else {
    Write-Log "当日无新增文件。"
}

# ============================================================
# 3. 当日删除文件（基于快照对比）
# ============================================================
Write-Log ""
Write-Log "---------- 3. 当日删除文件 ----------"

# 生成当前快照（仅包含完整路径，便于对比）
$currentFiles = @()
foreach ($drive in $Drives) {
    $drivePath = $drive.TrimEnd(':') + ':\'
    if (-not (Test-Path -LiteralPath $drivePath)) { continue }

    Write-Log "正在生成 $drivePath 文件快照..."
    try {
        $currentFiles += Get-ChildItem -Path $drivePath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    }
    catch {
        Write-Log "生成 $drivePath 快照出错: $_" -Level 'ERROR'
    }
}

Write-Log "当前文件总数: $($currentFiles.Count)"

# 查找最近一次快照
$previousSnapshots = Get-ChildItem -Path $snapshotDir -Filter 'snapshot_*.txt' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

$deletedFiles = @()
if ($previousSnapshots.Count -gt 0) {
    $prevSnapshotFile = $previousSnapshots[0].FullName
    Write-Log "加载上一次快照: $prevSnapshotFile"
    $previousFiles = Get-Content -Path $prevSnapshotFile -Encoding UTF8 -ErrorAction SilentlyContinue

    if ($previousFiles.Count -gt 0) {
        Write-Log "上一次快照文件数: $($previousFiles.Count)"

        # 使用 HashSet 加速对比
        $prevSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($f in $previousFiles) { $prevSet.Add($f) | Out-Null }

        $currSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($f in $currentFiles) { $currSet.Add($f) | Out-Null }

        # 上一次有但现在没有 = 被删除
        foreach ($f in $prevSet) {
            if (-not $currSet.Contains($f)) {
                $deletedFiles += $f
            }
        }

        if ($deletedFiles.Count -gt 0) {
            Write-Log "自上次快照以来删除的文件共 $($deletedFiles.Count) 个:"
            $deletedFiles | ForEach-Object { Write-Host "  [删除] $_" }
            $deletedFiles | ForEach-Object { Add-Content -Path $logFile -Value "  [删除] $_" -Encoding UTF8 }

            $deletedFileTxt = Join-Path $OutputDir "DeletedFiles_$today.txt"
            $deletedFiles | Set-Content -Path $deletedFileTxt -Encoding UTF8
            Write-Log "删除文件清单已导出: $deletedFileTxt"
        }
        else {
            Write-Log "自上次快照以来无删除文件。"
        }
    }
    else {
        Write-Log "上一次快照为空，无法对比。"
    }
}
else {
    Write-Log "未找到历史快照，本次为首次运行，将生成初始快照。"
    Write-Log "（删除文件检测需要至少两次运行，请下次运行后查看。）"
}

# 保存当前快照
if (-not $NoSnapshot) {
    $snapshotFile = Join-Path $snapshotDir "snapshot_$today.txt"
    $currentFiles | Set-Content -Path $snapshotFile -Encoding UTF8
    Write-Log "当前快照已保存: $snapshotFile"
}

# ============================================================
# 汇总
# ============================================================
Write-Log ""
Write-Log "---------- 汇总 ----------"
Write-Log "监控盘符: $($Drives -join ', ')"
Write-Log "新增文件: $($newFiles.Count) 个"
Write-Log "删除文件: $($deletedFiles.Count) 个（相对上次快照）"
Write-Log "日志文件: $logFile"
Write-Log "========== 磁盘监控结束 =========="
