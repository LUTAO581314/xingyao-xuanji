# BAIRUI 发布与验收指南

本文维护 BAIRUI 的构建、便携安装、上游同步与验收边界。当前候选版本为 **`1.18.31-bairui-brand.2`**，以 **Windows 便携版预发布** 为交付目标。此版本包含 BAIRUI 品牌、星杳助理、便携启动与目录选择器更新；它不是全平台稳定版。

## 版本与交付范围

源码同步到 `main`、创建预发布版本、上传可运行制品是不同的交付步骤。GitHub Release 应明确标记为 **Pre-release**，并记录提交、实际附件、验收证据和待完成项。只有源码或配置存在时，不能将对应安装渠道或平台写成已发布。

| 项目                               | 当前范围                                             | 发布时需要确认                                 |
| ---------------------------------- | ---------------------------------------------------- | ---------------------------------------------- |
| BAIRUI 品牌与星杳助理              | 已在源码实现，默认星杳使用原生 agent 配置            | 新二进制的 Web/TUI 实际显示与版本              |
| Windows 便携启动                   | 已有启动、停止、环境与单实例脚本，Web 端口为 `13148` | 安装路径、健康接口、会话数据路径、Web/TUI 互斥 |
| Web 项目目录选择器                 | 已有盘符浏览、`F:\` 目录浏览与新建文件夹实现         | 新二进制运行新界面，创建目录后能选择并打开     |
| 文件完整性                         | 已有 SHA-256 清单生成及校验脚本                      | 针对最终安装文件重新封存并通过校验             |
| Windows 制品                       | 本次预发布的目标制品                                 | 构建、实际启动和文件哈希记录                   |
| npm                                | 支持借助 npm 调用本地构建脚本                        | 未宣称已向 npm registry 发布 BAIRUI 包         |
| Docker/Linux                       | 已提供 Dockerfile、entrypoint 与 Compose 配置        | Linux musl 产物、镜像启动和持久化验收待完成    |
| macOS / 桌面安装包                 | 保留上游源码与相关品牌改动                           | 本次 Windows 便携验收不能代表这些平台已通过    |
| 长期记忆、睡眠整理、画布、自动归档 | 尚未交付                                             | 不列为本次可用功能                             |

目录选择器修复必须进入可执行文件中嵌入的 Web 资源。更新源码、刷新旧服务页面或只替换启动脚本不会让旧二进制拥有新界面。安装新候选后，应核对 `/global/health` 的版本和运行程序路径，再验证目录操作。

## Windows 便携安装

2026-09-20 启动器后续增强：双击入口先检查主程序、Bun、Node/npm、Git/Bash；缺失或无法运行时中文提示补齐，从固定哈希的已发布包恢复后继续启动。源码与本地安装已更新，新增 `windows-x64-online-starter.zip` 单独交付新入口；已发布的 `brand.2` 完整 ZIP 保持原内容，不移动版本标签。恢复代码、固定包元数据和桌面入口纳入本地发行校验清单。Windows PowerShell 5.1 中文脚本统一使用 UTF-8 BOM。

恢复验收脚本 `bairui/test-environment.ps1` 使用实际发行 ZIP，在独立可写目录中验证缺件、坏包拒绝、并发锁、真实恢复、资料保留和中断重试；不得把用户安装目录作为测试目录。

安装根目录是包含 `bairui`、`runtime`、`releases`、`data`、`config`、`cache` 和 `state` 的目录，例如 `F:\OpenCode`。源码目录 `F:\OpenCode\product` 不是便携安装根目录。

```text
F:\OpenCode\
  bairui\
  releases\1.18.31-bairui-brand.2\opencode.exe
  releases\1.18.31-bairui-brand.2\release.json
  runtime\bun\bun.exe
  runtime\node\node.exe
  runtime\git\cmd\git.exe
  runtime\git\bin\bash.exe
  data\
  config\
  cache\
  state\
  logs\bairui\
```

将仓库的 `bairui` 脚本部署到安装目录后，确认安装目录 `bairui/settings.json` 的 `release` 指向本次候选。三个中文 `.cmd` 入口模板如需双击使用，应复制到盘根，详情见 [便携启动说明](../bairui/README.md)。

```powershell
Set-Location F:\OpenCode

# Web 默认项目为安装所在盘根，例如 F:\
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1

# 退出 Web 后再启动 TUI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\stop.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1 -Mode TUI

# 版本检查
.\bairui\bairui.cmd --version
```

Web 绑定 `127.0.0.1:13148`，访问地址为 `http://127.0.0.1:13148/`。Web 与 TUI 共用便携单实例锁。复用服务前，启动器核对进程路径、端口和原生 `/path` 返回的数据位置；验证不符时报告错误。TUI 可以在当前终端退出并释放锁。

默认助理名在 `bairui/settings.json` 的 `assistantName` 中配置。设置在启动时读取，修改名字或版本后需要重启服务。

可选命令注册可仅作用于当前 PowerShell；如需长期注册，可明确使用 `-Scope User`：

```powershell
. .\bairui\register-command.ps1 -Scope Process
bairui --help
```

启动环境将 OpenCode 数据、配置、缓存、状态及常见工具缓存指向盘内。它不构成 Windows 权限沙箱；显式外部路径、插件及系统浏览器仍可能访问宿主文件。候选使用原生 channel 数据库 `data\opencode\opencode-bairui.db`，原版会话保留在 `data\opencode\opencode.db`，二者不会自动迁移或合并。

## 构建与安装制品

使用仓库指定的 Bun 版本。下面示例使用已有盘内环境，只改变当前 PowerShell 及其子进程环境。显式设置版本与 channel，避免构建脚本从当前分支名推导另一套预览版本。

```powershell
Set-Location F:\OpenCode\product
. .\bairui\env.ps1 -Root F:\OpenCode
$env:OPENCODE_VERSION = '1.18.31-bairui-brand.2'
$env:OPENCODE_CHANNEL = 'bairui'
bun install --frozen-lockfile
bun run build:bairui
```

`build:bairui` 执行当前平台构建，并包含 Web 资源；`--skip-install` 要求依赖已经准备好。Windows x64 输出位于 `packages/opencode/dist/opencode-windows-x64/bin/opencode.exe`。将本次输出及记录版本、源码提交和构建时间的 `release.json` 放到安装目录的对应 `releases` 子目录，更新便携设置，退出旧进程后再启动验证。保留旧版本制品有助于回退；不要覆盖正在使用的二进制或原版会话数据库。

npm 可以在 Bun 已安装并位于 PATH 时调用本地脚本：

```powershell
npm run build:bairui
```

这条命令不发布 npm 包，也不表示 BAIRUI 已上架 npm registry。依赖安装仍按 Bun workspace 工具链进行。上游 `opencode-ai` 包不等同于本项目的候选制品。

按根目录 `AGENTS.md`，类型检查和测试从对应包目录运行，不从仓库根目录运行测试。例如：

```powershell
Set-Location F:\OpenCode\product\packages\opencode
bun typecheck

Set-Location F:\OpenCode\product\packages\app
bun typecheck
bun test src/components/directory-picker-domain.test.ts src/components/directory-picker.test.ts

Set-Location F:\OpenCode\product\packages\tui
bun typecheck
bun test test/util/presentation.test.ts
```

具体执行结果应填入下方验收记录。已有失败、环境限制或未执行检查都应记录清楚，不能由一次成功构建推断整套回归已通过。

## 发行文件校验

在安装目录准备好最终二进制、元数据与脚本后生成校验清单：

```powershell
Set-Location F:\OpenCode
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\seal-release.ps1 -Root F:\OpenCode -Release 1.18.31-bairui-brand.2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\verify-release.ps1 -Root F:\OpenCode
```

可在封存时加 `-ReadOnly` 减少误改，更新前用 `seal-release.ps1 -Root F:\OpenCode -Unseal` 解除。清单覆盖发行二进制、元数据及启动边界文件，排除会话数据、配置、缓存、状态、运行时工具链与日志。只读属性和自带清单不等于代码签名，校验结果应随制品的版本和哈希一起记录。

## Docker 配置与后续验收

仓库已有 [Dockerfile](../packages/opencode/Dockerfile.bairui) 和 [Compose](../docker-compose.bairui.yml)。**Docker 交付仍待 Linux musl 构建和运行验证**；不能把 Windows `.exe` 放入 Linux 镜像，也不能把 Compose 静态解析成功当作镜像已运行。

在前述候选版本和 channel 环境下，从仓库根目录生成包含 Linux musl 的完整构建矩阵，再构建镜像：

```powershell
Set-Location F:\OpenCode\product
bun --cwd packages/opencode run build
docker compose -f docker-compose.bairui.yml config
docker build -f packages/opencode/Dockerfile.bairui `
  --build-arg BAIRUI_VERSION=1.18.31-bairui-brand.2 `
  -t bairui:1.18.31-bairui-brand.2 packages/opencode
docker compose -f docker-compose.bairui.yml up -d --build
docker compose -f docker-compose.bairui.yml ps
Invoke-WebRequest http://127.0.0.1:13148/global/health
Invoke-WebRequest http://127.0.0.1:13148/
```

Compose 的镜像标签和构建参数需与本次候选一致。验证前停止占用同一端口的 Windows 服务。默认绑定 `127.0.0.1:13148`，以 named volume 保存数据、配置、状态与缓存，并将 `./workspace` 挂载为 `/workspace`；通过 `BAIRUI_WORKSPACE` 可指定其他工作区。改变监听地址供网络访问前应配置 `OPENCODE_SERVER_PASSWORD`。

`docker compose -f docker-compose.bairui.yml stop` 停止服务，`down` 移除容器并保留卷；`down -v` 会删除持久化卷。Docker 验收还需要实际重启后确认数据保留。Docker Server 不可用或 Linux 产物缺失时，在 Release 中继续标注为未验证，不附带未经验证的镜像发布声明。

## GitHub 主线与上游同步

| 名称                   | 目标或用途                                          |
| ---------------------- | --------------------------------------------------- |
| `origin`               | `https://github.com/LUTAO581314/xingyao-xuanji.git` |
| `upstream`             | `https://github.com/anomalyco/opencode.git`         |
| `main`                 | BAIRUI 产品主线                                     |
| `conversation-archive` | 历史对话与记录，保留                                |
| `product-v2`           | 已冻结的历史产品分支，保留                          |

上表是本项目的远程约定，先用 `git remote -v` 核对实际配置。首次整理原克隆时，将 OpenCode 远程保留为 `upstream`，将本项目设为 `origin`；已有对应远程时核对 URL，不重复添加。不要将 BAIRUI 产品变更推到上游仓库。

后续审阅上游改动：

```powershell
git fetch origin main
git fetch upstream dev
git log --oneline --decorate -5
git diff main...upstream/dev -- packages/opencode packages/core packages/tui packages/app packages/ui
```

合并上游时重点复核品牌资产、星杳显示与配置、便携启动和单实例检查、项目目录接口及 Web 选择器、校验脚本、构建与 Docker 配置。保留原生 `@opencode-ai/*` 包名、`OPENCODE_*` 环境变量、`opencode.json`、数据库表、API 与插件协议标识。保留 `conversation-archive` 和冻结的 `product-v2`，不重写其历史或删除分支。

## 候选验收与发布记录

Windows 预发布验收关注实际将要上传的制品。至少记录版本与提交、构建、健康接口、嵌入 Web 资源、`F:\` 目录浏览与新建文件夹、便携路径和完整性校验。TUI 交互、改盘符、Provider/MCP/插件等未实测范围应作为候选的已知限制；稳定版发布前再完成相应回归。Docker/Linux 验收独立记录，不由 Windows 验收结果代替。

发布前检查提交及附件不含 API key、凭据、个人会话数据库、缓存、进程状态或 `node_modules`。制品应附版本、来源提交、SHA-256 与 MIT 许可；GitHub Release 标记 **Pre-release**。任何失败或未完成检查必须保留在发布说明中。

2026-09-20 本机验收记录如下。最终来源提交与构建时间见附件 `release.json`，上传结果以 GitHub Release 页面为准。

| 检查项         | 本次结果                                                                                                                    |
| -------------- | --------------------------------------------------------------------------------------------------------------------------- |
| 版本           | `1.18.31-bairui-brand.2`                                                                                                    |
| 构建           | `bun run build:bairui` 退出 0；嵌入 Web 构建及二进制版本自检通过                                                            |
| 测试           | 目录选择器 29 项、语言字典 5 项、HTTP/提示词 11 项、TUI 展示辅助函数 1 项通过                                               |
| 类型检查       | 后端通过；前端完整检查受 Windows 符号链接检出问题阻碍；全量原生回归未完成                                                   |
| 二进制 SHA-256 | `398cabfdc3425a06c23682e864c60fc14d41718c36ed17d8474af4be982bbc82`                                                          |
| 安装版 Web     | 13148 端口健康接口返回 brand.2，嵌入页面可加载                                                                              |
| 实际浏览器操作 | Chrome 显示 C/D/E/F；点击 F 后可见 OpenCode、Workspace；新建目录与真实文件系统核对成功；选择 Workspace 成功；测试目录已删除 |
| 便携路径       | 启动器核对 home/config/state 均在安装目录，工作区是 F 盘；bairui channel 数据保留                                           |
| 单实例         | Web 运行时 TUI 启动被正确拒绝；交互 TUI、改盘符完整验收尚未完成                                                             |
| 发行清单       | 打包脚本对干净目录生成并验证 SHA-256 清单；校验失败则不生成 ZIP                                                             |
| Docker         | Compose 静态校验通过；本机无可用 Docker Server，Linux musl 产物及容器运行未验收                                             |
| npm            | 仅提供调用 Bun 的本地构建命令；未发布 registry 安装包                                                                       |
| 历史           | 保留 conversation-archive、product-v2 和上游 Git 历史                                                                       |

旧版选择器曾通过假定 `sdk.api.local` 存在的测试，但真实兼容 API 不包含该字段。本次改用已生成、带认证的 `sdk.client.local`，探测扩展能力后再访问；不支持该扩展的上游服务继续回退到原生文件接口。增加真实生成 SDK 的传输测试，防止只验证虚构客户端形状。

## 上游归属与许可

BAIRUI 基于 OpenCode 的 MIT 许可源码开发，是独立衍生项目，与 OpenCode 团队无隶属关系。本仓库保留上游 [MIT 许可和版权声明](../LICENSE)，分发时须同时保留。原生使用方式可参考 [上游 README](upstream-readme.md) 与 [OpenCode 文档](https://opencode.ai/docs)，其中上游安装渠道和发布状态不适用于 BAIRUI。
