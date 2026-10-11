# 磁盘监控脚本使用说明

## 概述

`DiskMonitor.ps1` 是一个基于 PowerShell 的磁盘监控自动化脚本，用于监控指定盘符的存储空间占用情况，并统计当日新增文件与删除文件。脚本结果同时输出到控制台和日志文件，便于日常运维和审计。

## 功能特性

1. **存储空间占用统计** — 输出各盘符的总容量、已用空间、剩余空间及占用率。
2. **当日新增文件检测** — 基于文件创建时间（`CreationTime`）筛选当天新增的文件，导出为 CSV。
3. **删除文件检测** — 通过快照对比机制，报告自上次运行以来被删除的文件。
4. **日志记录** — 所有运行信息记录到按日期命名的日志文件中。

## 工作原理

### 1. 存储空间占用

通过 WMI 类 `Win32_LogicalDisk` 获取磁盘的 `Size` 和 `FreeSpace` 属性，计算已用空间和占用率，支持自动跳过不存在的盘符。

### 2. 新增文件检测

使用 `Get-ChildItem -Recurse` 遍历目标盘符，筛选 `CreationTime` 在当天 00:00:00 至次日 00:00:00 之间的文件。可通过 `-NewFileDepth` 参数限制扫描深度以加快速度。

### 3. 删除文件检测（快照对比）

由于 Windows 不直接提供"已删除文件列表"，脚本采用快照对比方案：

- 每次运行时，将当前所有文件的完整路径保存为快照文件（`snapshot_YYYY-MM-DD.txt`）。
- 下次运行时，将当前文件列表与最近一次快照进行对比。
- 上次快照中存在但当前不存在的文件，即视为"被删除"。

> **注意**：删除文件检测需要至少运行两次脚本。首次运行仅生成初始快照，不会报告删除文件。

## 使用方法

### 基础运行

```powershell
powershell -ExecutionPolicy Bypass -File "E:\automation-scripts\DiskMonitor.ps1"
```

### 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-Drives` | string[] | `C, D, E` | 要监控的盘符列表 |
| `-OutputDir` | string | `E:\automation-scripts\logs` | 日志与快照存放目录 |
| `-NewFileDepth` | int | `0` | 新增文件扫描的目录深度，`0` 表示不限制 |
| `-NoSnapshot` | switch | 关闭 | 不生成文件快照（跳过删除文件检测） |

### 使用示例

```powershell
# 仅监控 C 盘和 D 盘
powershell -ExecutionPolicy Bypass -File "E:\automation-scripts\DiskMonitor.ps1" -Drives C,D

# 指定日志输出目录
powershell -ExecutionPolicy Bypass -File "E:\automation-scripts\DiskMonitor.ps1" -OutputDir "D:\monitor\logs"

# 限制新增文件扫描深度为 5 层（加快扫描速度）
powershell -ExecutionPolicy Bypass -File "E:\automation-scripts\DiskMonitor.ps1" -NewFileDepth 5

# 只查看空间和新增文件，不生成快照
powershell -ExecutionPolicy Bypass -File "E:\automation-scripts\DiskMonitor.ps1" -NoSnapshot
```

## 输出文件

脚本运行后会在 `-OutputDir` 指定目录下生成以下文件：

```
logs/
├── DiskMonitor_YYYY-MM-DD.log        # 运行日志（含空间占用、新增/删除文件汇总）
├── NewFiles_YYYY-MM-DD.csv           # 当日新增文件清单（CSV 格式）
├── DeletedFiles_YYYY-MM-DD.txt       # 删除文件清单（第二次运行后生成）
└── snapshots/
    └── snapshot_YYYY-MM-DD.txt       # 全量文件路径快照（用于对比删除文件）
```

### CSV 字段说明

`NewFiles_YYYY-MM-DD.csv` 包含以下字段：

| 字段 | 说明 |
|------|------|
| 盘符 | 文件所在盘符（如 `C:\`） |
| 完整路径 | 文件的完整路径 |
| 大小_KB | 文件大小（KB） |
| 创建时间 | 文件创建时间 |

## 定时运行（任务计划程序）

建议每天定时运行一次，以实现每日磁盘变动监控。

### 配置步骤

1. 打开 **任务计划程序**（`taskschd.msc`）。
2. 右侧点击 **创建基本任务**。
3. 名称填写 `磁盘每日监控`，点击下一步。
4. 触发器选择 **每天**，设置运行时间（如 23:00）。
5. 操作选择 **启动程序**。
6. 程序/脚本填写：
   ```
   powershell.exe
   ```
7. 添加参数填写：
   ```
   -ExecutionPolicy Bypass -File "E:\automation-scripts\DiskMonitor.ps1"
   ```
8. 完成创建。

## 注意事项

- **运行权限**：建议以管理员身份运行，以确保能访问系统目录（如 `C:\Windows`、`C:\Program Files`）。
- **扫描耗时**：全盘文件扫描耗时较长（取决于文件数量，通常数分钟至十几分钟），建议在非工作时段运行。
- **快照体积**：快照文件记录了所有文件路径，文件数量多时体积较大，可定期清理 `snapshots` 目录中过旧的快照。
- **编码**：脚本使用 UTF-8（含 BOM）编码，确保中文日志正常显示。
- **删除文件准确性**：快照对比法报告的是"自上次运行以来"的删除文件，若两次运行间隔超过一天，则包含多天内的删除记录。

## 环境要求

- 操作系统：Windows 7 及以上
- PowerShell 版本：5.1 及以上
- 磁盘文件系统：NTFS（推荐，支持完整的时间戳属性）
