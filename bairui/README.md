# BAIRUI 便携启动

把本目录安装到 U 盘的 `OpenCode\bairui`，与 `runtime`、`releases`、`data`、`config`、`cache`、`state` 同级。脚本默认将自身父目录作为安装根目录，因此换盘符后不需要修改固定路径。源码目录下调试或构建时显式传入 `-Root`。

将本目录中的 `启动BAIRUI.cmd`、`启动BAIRUI终端.cmd`、`停止BAIRUI.cmd` 三个入口模板另行复制到 U 盘根目录，在盘根双击使用。它们按自身位置调用 `OpenCode\bairui` 下的脚本，不在源码或安装子目录中直接运行这些模板。

普通用户解压完整便携包后双击 `启动BAIRUI.cmd` 即可。入口先检查 BAIRUI、Bun、Node/npm、Git/Bash 的关键文件与实际运行状态；环境完整时直接启动，不联网下载。缺失或损坏时显示中文提示，点击「是」后补齐，再自动继续启动。无需全局安装开发工具或管理员权限。

恢复固定使用 `environment-release.json` 指定的已发布便携包，优先寻找 `runtime/downloads`、`releases/downloads` 或安装目录上一层的同名 ZIP，没有时下载约 299 MB。完整包通过固定 SHA-256 校验后才解压，只恢复异常组件，不改变聊天数据、配置和项目文件；组件内额外文件也保留。下载、暂存、缓存都在安装目录内，修复期间禁止另一窗口同时修复；盘内程序仍运行时要求先退出。断网或取消时不启动，已下载完的校验包可供下次重试；中断复制会在下次启动重新修复。错误的本地 ZIP 会明确提示移走或重新下载。恢复主程序前核对包版本与配置一致，不用旧版覆盖新版。

启动配置/脚本本身缺失、盘只读、空间不足等情况需按提示处理或重新解压完整包，不宣称可自行修复任意文件。环境补齐不包含模型权重、账号或密钥；模型连接继续使用原生界面。本轮启动器增强已部署到本地，并作为 `windows-x64-online-starter.zip` 小型在线启动包单独交付；GitHub 原 `brand.2` 完整 ZIP 保持原内容。在线启动包在首次运行时获取同一已发布、固定校验值的完整 ZIP，不包含用户数据和凭据。

维护者使用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\package-starter.ps1 -OutputDirectory <盘内输出目录>` 生成在线启动包及校验文件。该脚本只复制明确列出的运行入口和许可文件。升级主程序版本时必须同步维护恢复包版本、下载地址、大小和 SHA-256；不得只更新 `settings.json`。

命令行直接调用 `start.ps1` 遇到缺件会输出修复指引并退出；加 `-Interactive` 可显示补齐对话框，避免自动化命令被弹窗阻塞。

```powershell
# 从安装目录启动 Web；默认项目是安装所在的整块 U 盘根目录。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1

# TUI 在当前终端运行；自定义项目也必须位于同一盘符。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1 -Mode TUI -Project F:\Workspace\my-project

# 供启动验证使用：运行 Web 服务，但不打开浏览器。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1 -NoBrowser

# 停止本发行版占用 13148 端口的服务，会中断其正在执行的任务。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\stop.ps1

# 从源码目录准备构建环境；只影响当前 PowerShell 和之后的子进程。
. F:\OpenCode\product\bairui\env.ps1 -Root F:\OpenCode
```

在 `settings.json` 中修改 `assistantName` 可改名，空值或空白使用默认名字“星杳”；`promptEnabled: false` 关闭 BAIRUI 公共提示词。启动时分别映射为 `BAIRUI_NAME` 与 `BAIRUI_PROMPT_DISABLED`。配置在进程启动时读取；复用已运行服务不会更新其环境，需要用户自行退出该服务后重新启动。

Web 绑定 `127.0.0.1:13148`，使用隐藏子进程，标准输出与错误日志保存在安装根目录的 `logs\bairui`。Web 和 TUI 共用安装根目录 `runtime\bairui-instance.lock.json` 单实例锁，任何一个模式运行时，另一个模式都会明确提示并退出；锁记录进程 ID 和进程启动时间，进程异常退出后下次启动会自动清理过期锁。复用已有服务前，先检查可执行文件路径和监听地址，再通过本机 `/path` 核对 `home`、`state`、`config` 和 `directory` 是否分别对应盘内个人目录、状态目录、配置目录及本次项目目录；同一程序在宿主环境直接启动的服务不会仅因程序路径相同而被接受。路径不符或无法验证时报错，不停止任何进程。新服务启动后也必须通过这项检查才报告就绪和打开浏览器；端口已监听但 API 尚未就绪时，在 30 秒启动期限内继续重试。若设置了 `OPENCODE_SERVER_PASSWORD`，检查使用当前进程的服务凭据。`-NoBrowser` 同样适用于复用已有服务。启动超时会保留进程及日志供检查，不擅自终止程序。

`stop.ps1` 只停止 13148 端口上可执行文件路径与本发行版一致的进程，并在成功停止后移除对应单实例锁；其他程序占用时报告错误。没有监听时，如果锁的所有者已经退出，会清理过期锁。监听状态查询失败会报错，不把查询失败说成服务未运行。TUI 可在其终端内退出，退出时自动释放单实例锁。

`env.ps1` 将 OpenCode 的 XDG 数据、配置、缓存和状态指向安装根目录的 `data`、`config`、`cache`、`state`。临时目录、Bun/npm/pip/node-gyp 等缓存、进程级 AppData、Git 全局配置和 npm 配置位于 `runtime`；OpenCode 的 `Global.home` 通过当前源码支持的 `OPENCODE_TEST_HOME` 指向 `runtime\profile`。关闭宿主 Claude 指令、外部 skills 自动发现和自动更新，忽略 Git 系统配置；已有 OpenCode 文件路径及内联配置环境覆盖值会被清除，盘内配置继续生效。

这些设置只写当前进程环境，并由后续子进程继承，不写用户级或系统级环境变量，不修改 `HOME`、`USERPROFILE` 或 `CODEX_HOME`。PATH 只包含盘内工具和 Windows 系统目录，不自动回退到宿主安装的 Python、npm 或其他开发环境；需要新工具时应安装到盘内。

**便携数据目录不等于权限沙箱。** 脚本没有限制进程的文件访问权限，也没有接管任意工具的存储行为；不遵守这些环境变量的工具、插件、浏览器、显式外部路径及链接仍可能访问或写入宿主。打开系统默认浏览器也可能使用宿主浏览器自己的配置和缓存。需要严格隔离时，应另行使用适当的沙箱或虚拟机；本脚本不承诺宿主零读写。

2026-09-19 已在 Windows PowerShell 5.1 实测默认路径启动和已有服务复用，`/global/health` 返回 `1.18.31-bairui-brand.1`，`/path` 的个人目录、配置、状态及工作区均匹配盘内位置；官方 Web 首页和嵌入脚本返回 200。2026-09-20 将便携 Web 端口统一为 `13148`，并加入 Web/TUI 共用的进程签名锁。实际启动时发现的参数默认路径和盘根创建问题已修复。改盘符和 TUI 交互未实测，不能以静态检查代替。

候选使用 OpenCode 原生 channel 数据库 `data\opencode\opencode-bairui.db`；原版会话仍留在 `data\opencode\opencode.db`，没有迁移或覆盖。两者不自动合并会话，所以候选初次打开时可能没有原版聊天历史。`env.ps1` 明确保留 channel 隔离，避免继承宿主关闭隔离的变量。

默认工作区为安装所在盘符的根目录，例如 `F:\`。这扩大了用户可交给助理处理的文件范围，不等于启动时扫描或搬动全盘文件。自动整理守护、自动归档与长期记忆尚未实现；配置、运行环境及源码仍保留原目录，本目录不包含自动整理器。

## 发行文件保护

发行目录和启动边界文件可以用 SHA-256 清单校验，清单位于安装根目录的 `bairui\bairui-integrity.json`。校验只覆盖发行二进制、发行元数据和 BAIRUI 启动脚本，不覆盖 `data`、`cache`、`state`、`runtime` 等运行时数据，因此不会阻止聊天记录和配置写入。

```powershell
# 发布或更新发行目录后重新生成清单
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\seal-release.ps1 -Root F:\OpenCode

# 启动前检查发行文件是否被改动或缺失
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\verify-release.ps1 -Root F:\OpenCode

# 可选：把清单覆盖的文件设为只读，减少误改
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\seal-release.ps1 -Root F:\OpenCode -ReadOnly

# 更新前解除只读属性
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\seal-release.ps1 -Root F:\OpenCode -Unseal
```

只读属性是 Windows 文件属性，不是权限沙箱；拥有 U 盘写权限的用户仍可以清除它或重新生成清单。需要防篡改发布时，应把清单和发行包放在受控的发布渠道并增加代码签名。源码目录不自动设为只读，开发和跟随上游更新仍按正常 Git 流程进行。

## Docker 部署

Docker 使用与原版 OpenCode 相同的 Linux musl 发布产物；BAIRUI 镜像只增加品牌身份和默认的“星杳”主智能体，模型、Provider、MCP、会话、权限、插件和原生 CLI 能力仍由 OpenCode 负责。构建前必须先在仓库根目录生成 Linux musl 产物，Windows x64 产物不能直接放进 Linux 镜像：

```powershell
# 在 F:\OpenCode\product 执行；会生成 packages\opencode\dist\opencode-linux-*-musl
bun --cwd packages/opencode run build

# 构建 BAIRUI 镜像
docker build -f packages/opencode/Dockerfile.bairui `
  --build-arg BAIRUI_VERSION=1.18.31-bairui-brand.2 `
  -t bairui:1.18.31-bairui-brand.2 packages/opencode

# 或使用 Compose 构建并启动
docker compose -f docker-compose.bairui.yml up -d --build
docker compose -f docker-compose.bairui.yml ps
```

Compose 默认只绑定本机 `127.0.0.1:13148`，访问地址为 `http://127.0.0.1:13148/`；健康检查为 `http://127.0.0.1:13148/global/health`。停止服务但保留容器卷使用 `docker compose -f docker-compose.bairui.yml stop`，停止并移除容器使用 `docker compose -f docker-compose.bairui.yml down`。不要在没有备份的情况下使用 `down -v`，它会删除 Docker 管理的数据、配置、状态和缓存卷。

默认持久化目录是四个 Docker named volume（`bairui-data`、`bairui-config`、`bairui-state`、`bairui-cache`）以及 Compose 文件旁的 `workspace` 目录。可通过 `BAIRUI_WORKSPACE` 指向 U 盘上的工作区。容器中的 `OPENCODE_CONFIG_CONTENT` 只提供默认星杳 agent；可以用 Compose 环境变量覆盖它，OpenCode 原生配置合并和 Provider/模型选择仍然可用。

默认没有设置服务密码，因而只适合本机回环访问。若要改变端口绑定或接入局域网，应先设置 `OPENCODE_SERVER_PASSWORD`（可选 `OPENCODE_SERVER_USERNAME`），再修改 Compose 的 `ports`；不要把未认证的服务暴露到局域网或公网。

当前仓库只完成 Dockerfile 和 Compose 的静态配置，不能把 Docker 构建或运行验收写成已完成：本机 `docker version` 尚未返回 Docker Server，且当前 `packages/opencode/dist` 只有 Windows x64 产物。完成 Linux musl 构建并启动 Docker daemon 后，再按上述命令验收镜像、`/global/health`、Web 首页和持久化目录。
