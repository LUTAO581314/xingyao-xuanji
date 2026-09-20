# BAIRUI · 星杳

BAIRUI 是基于 [OpenCode](https://github.com/anomalyco/opencode) 开发的个人助理产品，默认助理名为「星杳」。当前产品以 Windows 便携运行、中文使用体验和项目文件操作为主要交付范围，沿用 OpenCode 的模型接入、工具、会话、权限与插件能力。

**当前候选版本：`1.18.31-bairui-brand.2`，属于预发布版本。** 验收范围和未完成项见 [发布指南](docs/bairui-release.md)；源码合入 `main` 不代表所有平台或安装渠道均已发布。

## 当前功能

- **BAIRUI 产品品牌**：Web、TUI 与相关产品入口使用 BAIRUI 标识；内部名称按原生协议保留兼容。
- **星杳助理**：通过原生 agent 配置提供默认助理，TUI 中优先展示。可在便携安装的 `bairui/settings.json` 修改名字，重启后生效。
- **Windows 便携启动**：使用盘内运行时、数据、配置、缓存和日志；Web 地址为 `http://127.0.0.1:13148/`，Web 与 TUI 共用单实例检查。
- **项目目录选择器**：Web 使用新的目录选择界面，可以浏览 Windows 盘符、进入 `F:\` 等目录并新建文件夹。新界面和目录接口随本次候选二进制交付，旧版本服务需要更新后重新启动。
- **发行文件校验**：提供 SHA-256 清单生成与校验脚本，以及可选的 Windows 只读属性设置。

长期记忆、睡眠整理、画布、自动发现及归档全盘新资料尚未交付。默认工作区指向安装所在盘根，表示可以在该工作区处理文件，不代表程序已经自动扫描、整理或记忆整块磁盘。

## 运行 Windows 便携版

便携安装由启动脚本、对应版本二进制和盘内工具共同组成；单独克隆本源码仓库还不能直接运行便携版。完整目录和准备步骤见 [便携启动说明](bairui/README.md) 与 [发布指南](docs/bairui-release.md)。

例如安装根目录为 `F:\OpenCode`，准备好 `releases\1.18.31-bairui-brand.2\opencode.exe` 和 `runtime` 后，在安装根目录执行：

```powershell
Set-Location F:\OpenCode

# 启动 Web，然后在浏览器访问 http://127.0.0.1:13148/
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1

# 停止 Web 后，在当前终端使用 TUI
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\stop.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bairui\start.ps1 -Mode TUI

# 查看当前便携二进制版本
.\bairui\bairui.cmd --version
```

便携路径设置会被子进程继承，但不构成 Windows 文件访问沙箱；工具显式指定的路径和系统浏览器仍可能使用宿主文件。候选版本使用独立的原生 channel 数据库 `data\opencode\opencode-bairui.db`，不会自动合并原版 `opencode.db` 中的会话。

如果更新后仍看到旧目录弹窗，先核对 `/global/health` 返回的版本和 `bairui/settings.json` 的 `release`，退出旧服务，再从更新后的安装目录启动并刷新页面。源码变更不会自动替换已经运行的二进制。

## 从源码构建

使用仓库指定的 Bun 版本和盘内开发环境。下面以已有 `F:\OpenCode` 便携工具链为例，构建当前 Windows 平台二进制及其嵌入 Web 界面：

```powershell
Set-Location F:\OpenCode\product
. .\bairui\env.ps1 -Root F:\OpenCode
$env:OPENCODE_VERSION = '1.18.31-bairui-brand.2'
$env:OPENCODE_CHANNEL = 'bairui'
bun install --frozen-lockfile
bun run build:bairui
```

`npm run build:bairui` 也只是调用本地构建脚本，仍依赖 Bun；这不表示 BAIRUI 已发布到 npm registry。上游的 `npm install -g opencode-ai` 安装的是 OpenCode，不是本仓库的 BAIRUI 候选版本。

Dockerfile 和 Compose 配置已提供，但 Linux musl 产物构建、容器启动与持久化验收仍待完成。具体命令和状态见 [发布指南](docs/bairui-release.md)。

## 仓库与分支

主仓库为 [LUTAO581314/xingyao-xuanji](https://github.com/LUTAO581314/xingyao-xuanji)。

| 分支                   | 用途                          |
| ---------------------- | ----------------------------- |
| `main`                 | BAIRUI 产品主线与后续发布准备 |
| `conversation-archive` | 保留历史对话与项目记录        |
| `product-v2`           | 冻结保留的历史产品分支        |

`origin` 指向本项目仓库，`upstream` 指向 `anomalyco/opencode`。跟进上游时保留历史分支，按 [发布指南](docs/bairui-release.md) 检查兼容边界。

## 上游、文档与许可

BAIRUI 是独立衍生项目，并非 OpenCode 团队制作或官方发行，与该团队无隶属关系。感谢 OpenCode 及其贡献者提供基础实现。本仓库保留 [MIT License](LICENSE) 和上游版权声明；分发源码或二进制时也应包含相应许可文件。

为兼容原生项目、配置和插件，保留 `@opencode-ai/*`、`OPENCODE_*`、`opencode.json`、数据库与协议标识等内部名称。模型、Provider、MCP、权限与会话行为继续基于 OpenCode 实现。

- [BAIRUI 发布与验收指南](docs/bairui-release.md)
- [BAIRUI 便携启动说明](bairui/README.md)
- [上游 README 参考](docs/upstream-readme.md)：保存原说明内容，仅调整相对链接；其中安装渠道属于上游 OpenCode。
- [上游简体中文说明](README.zh.md) 与仓库中的其他多语言 README：保留上游参考内容，不代表 BAIRUI 的发行状态。
- [OpenCode 原生文档](https://opencode.ai/docs) 与 [贡献说明](CONTRIBUTING.md)
