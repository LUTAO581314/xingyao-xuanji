# BAIRUI 便携启动

把本目录安装到 U 盘的 `OpenCode\bairui`，与 `runtime`、`releases`、`data`、`config`、`cache`、`state` 同级。脚本默认将自身父目录作为安装根目录，因此换盘符后不需要修改固定路径。源码目录下调试或构建时显式传入 `-Root`。

将本目录中的 `启动BAIRUI.cmd`、`启动BAIRUI终端.cmd`、`停止BAIRUI.cmd` 三个入口模板另行复制到 U 盘根目录，在盘根双击使用。它们按自身位置调用 `OpenCode\bairui` 下的脚本，不在源码或安装子目录中直接运行这些模板。

运行前准备好 `runtime\bun\bun.exe`、`runtime\node\node.exe`、`runtime\git\cmd\git.exe`、`runtime\git\bin\bash.exe` 和 `releases\1.18.31-bairui-prompt.1\opencode.exe`。原版 OpenCode 的入口由原部署继续维护，本目录是独立的 BAIRUI 入口。

```powershell
# 从安装目录启动 Web；默认项目是安装所在的整块 U 盘根目录。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1

# TUI 在当前终端运行；自定义项目也必须位于同一盘符。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1 -Mode TUI -Project F:\Workspace\my-project

# 供启动验证使用：运行 Web 服务，但不打开浏览器。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1 -NoBrowser

# 停止本发行版占用 4098 端口的服务，会中断其正在执行的任务。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\stop.ps1

# 从源码目录准备构建环境；只影响当前 PowerShell 和之后的子进程。
. F:\OpenCode\product\bairui\env.ps1 -Root F:\OpenCode
```

在 `settings.json` 中修改 `assistantName` 可改名，空值或空白使用默认名字“星杳”；`promptEnabled: false` 关闭 BAIRUI 公共提示词。启动时分别映射为 `BAIRUI_NAME` 与 `BAIRUI_PROMPT_DISABLED`。配置在进程启动时读取；复用已运行服务不会更新其环境，需要用户自行退出该服务后重新启动。

Web 绑定 `127.0.0.1:4098`，使用隐藏子进程，标准输出与错误日志保存在安装根目录的 `logs\bairui`。复用已有服务前，先检查可执行文件路径和监听地址，再通过本机 `/path` 核对 `home`、`state`、`config` 和 `directory` 是否分别对应盘内个人目录、状态目录、配置目录及本次项目目录；同一程序在宿主环境直接启动的服务不会仅因程序路径相同而被接受。路径不符或无法验证时报错，不停止任何进程。新服务启动后也必须通过这项检查才报告就绪和打开浏览器；端口已监听但 API 尚未就绪时，在 30 秒启动期限内继续重试。若设置了 `OPENCODE_SERVER_PASSWORD`，检查使用当前进程的服务凭据。`-NoBrowser` 同样适用于复用已有服务。启动超时会保留进程及日志供检查，不擅自终止程序。

`stop.ps1` 只停止 4098 端口上可执行文件路径与本发行版一致的进程；其他程序占用时报告错误。监听状态查询失败会报错，不把查询失败说成服务未运行。TUI 可在其终端内退出。

`env.ps1` 将 OpenCode 的 XDG 数据、配置、缓存和状态指向安装根目录的 `data`、`config`、`cache`、`state`。临时目录、Bun/npm/pip/node-gyp 等缓存、进程级 AppData、Git 全局配置和 npm 配置位于 `runtime`；OpenCode 的 `Global.home` 通过当前源码支持的 `OPENCODE_TEST_HOME` 指向 `runtime\profile`。关闭宿主 Claude 指令、外部 skills 自动发现和自动更新，忽略 Git 系统配置；已有 OpenCode 文件路径及内联配置环境覆盖值会被清除，盘内配置继续生效。

这些设置只写当前进程环境，并由后续子进程继承，不写用户级或系统级环境变量，不修改 `HOME`、`USERPROFILE` 或 `CODEX_HOME`。PATH 只包含盘内工具和 Windows 系统目录，不自动回退到宿主安装的 Python、npm 或其他开发环境；需要新工具时应安装到盘内。

**便携数据目录不等于权限沙箱。** 脚本没有限制进程的文件访问权限，也没有接管任意工具的存储行为；不遵守这些环境变量的工具、插件、浏览器、显式外部路径及链接仍可能访问或写入宿主。打开系统默认浏览器也可能使用宿主浏览器自己的配置和缓存。需要严格隔离时，应另行使用适当的沙箱或虚拟机；本脚本不承诺宿主零读写。

2026-09-19 已在 Windows PowerShell 5.1 实测默认路径启动和已有服务复用，`/global/health` 返回 `1.18.31-bairui-prompt.1`，`/path` 的个人目录、配置、状态及工作区均匹配盘内位置；官方 Web 首页和嵌入脚本返回 200。实际启动时发现的参数默认路径和盘根创建问题已修复。改盘符和 TUI 交互未实测，不能以静态检查代替。

候选使用 OpenCode 原生 channel 数据库 `data\opencode\opencode-bairui.db`；原版会话仍留在 `data\opencode\opencode.db`，没有迁移或覆盖。两者不自动合并会话，所以候选初次打开时可能没有原版聊天历史。`env.ps1` 明确保留 channel 隔离，避免继承宿主关闭隔离的变量。

默认工作区为安装所在盘符的根目录，例如 `F:\`。这扩大了用户可交给助理处理的文件范围，不等于启动时扫描或搬动全盘文件。自动整理守护、自动归档与长期记忆尚未实现；配置、运行环境及源码仍保留原目录，本目录不包含自动整理器。
