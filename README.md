# MacTaskScheduler

一个原生 macOS 可视化定时任务管理器（SwiftUI），用于替代不易用的 `crontab`。

## 功能

- 任务管理：新增、修改、删除、查询（搜索）
- 任务字段：
  - 名称
  - 脚本路径
  - 参数
  - 工作目录
  - 启用/禁用
- 频次类型：
  - 单次执行（Run Once）
  - 每 X 分钟循环（Repeat Every X Minutes）
  - 指定星期 + 时间（Specific Weekdays）
  - 指定每月第几天 + 时间（Specific Day of Month）
  - 每 X 天 + 锚点日期 + 时间（Every X Days）
  - Cron 表达式（5 字段：`m h dom mon dow`）
- 执行能力：
  - 定时触发
  - 手动立即执行（Run Now）
  - 展示最近一次输出、退出码、上次/下次执行时间

## 技术设计

- UI：SwiftUI（macOS 原生）
- 存储：JSON 文件
  - 路径：`~/Library/Application Support/MacTaskScheduler/tasks.json`
- 调度：应用内轮询（默认 20 秒）+ 规则计算下次触发时间
- 执行：`Process` 执行脚本
  - 脚本可执行时直接运行
  - 否则回退到 `/bin/zsh <script> ...args`

## 项目结构

- `Package.swift`
- `Sources/MacTaskScheduler/MacTaskSchedulerApp.swift`
- `Sources/MacTaskScheduler/Models/TaskItem.swift`
- `Sources/MacTaskScheduler/Models/ScheduleRule.swift`
- `Sources/MacTaskScheduler/Services/CronCalculator.swift`
- `Sources/MacTaskScheduler/Services/TaskStore.swift`
- `Sources/MacTaskScheduler/Services/TaskRunner.swift`
- `Sources/MacTaskScheduler/Services/SchedulerEngine.swift`
- `Sources/MacTaskScheduler/ViewModels/AppViewModel.swift`
- `Sources/MacTaskScheduler/Views/ContentView.swift`
- `Sources/MacTaskScheduler/Views/TaskEditorView.swift`
- `scripts/package_app.sh`

## 编译与运行

### 1) 命令行直接运行

```bash
cd "/Users/panhuahuang/Documents/New project"
swift run
```

### 2) Release 构建

```bash
cd "/Users/panhuahuang/Documents/New project"
swift build -c release
```

生成可执行文件：

```bash
.build/release/MacTaskScheduler
```

### 3) 打包为 `.app`

```bash
cd "/Users/panhuahuang/Documents/New project"
./scripts/package_app.sh
```

生成：

```bash
.build/release/MacTaskScheduler.app
```

## 安装

```bash
cp -R ".build/release/MacTaskScheduler.app" /Applications/
```

首次运行如果出现安全拦截：

- 打开 `系统设置 -> 隐私与安全性`，允许该应用运行

## 使用说明

1. 点击 `Add` 新建任务。
2. 选择脚本路径（可填写参数和工作目录）。
3. 选择执行频次。
4. 保存后任务会计算 `Next Run` 并自动调度。
5. 在详情页可 `Run Now`、启停、编辑、删除。

## 注意事项

- 这是应用内调度器，应用需要保持运行才能触发任务。
- 如果希望“即使关闭主窗口也继续执行”，可将应用最小化并保持进程常驻。
- 如需彻底后台守护，可在后续版本接入 `LaunchAgent`（可扩展）。
