# DeepSeek Harness 一键安装器

一键安装 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的 Web GUI（`dsh web`），
并配置**开机静默自启**（无窗口、不自动弹浏览器）与**桌面快捷方式/启动器**。

## Windows 一键安装

在 **PowerShell** 或 **CMD** 中执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1 | iex"
```

安装完成后：桌面出现「DeepSeek Harness」快捷方式，双击即可打开 GUI
（`http://127.0.0.1:3080/`）；登录 Windows 后服务自动在后台静默运行。

## Linux 一键安装

在终端中执行：

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.sh | bash
```

安装完成后：应用菜单/桌面出现「DeepSeek Harness」启动器；登录桌面后服务通过
XDG autostart 自动在后台静默运行。macOS 暂不支持本脚本（请手动
`npm install -g @deepseek-ai/dsh` 后运行 `dsh web`）。

## 安装内容

| 项目 | Windows | Linux |
| --- | --- | --- |
| DSH CLI | 官方 `@deepseek-ai/dsh@0.1.5-rc.3`（npm 官方 registry），安装到 `%LOCALAPPDATA%\DeepSeekHarness\npm` | 同版本，安装到 `~/.local/share/DeepSeekHarness/npm`，均不影响系统全局 npm |
| Node.js | 本机已有 Node ≥ 20.19 时直接复用；否则自动下载官方便携版 Node v22.19.0（免管理员权限/免 root），并做 SHA256 校验 | 同左（linux x64/arm64 官方 tarball） |
| 静默自启 | 启动文件夹快捷方式 → 无窗口运行 `dsh web --no-open`，端口被占用时自动跳过 | XDG autostart（`~/.config/autostart`）→ 后台 nohup 运行，逻辑相同 |
| 桌面快捷方式 | 打开 GUI：服务未运行则先静默拉起；优先使用服务器打印的 token 认证 URL（从共享日志提取并验证），否则回退普通 URL（依赖浏览器内 30 天会话 cookie） | 应用菜单 + 桌面 `.desktop` 启动器，打开逻辑相同 |
| 日志 | `%LOCALAPPDATA%\DeepSeekHarness\logs\`（自启、桌面、服务器三类日志） | `~/.local/share/DeepSeekHarness/logs\` |

## 系统要求

- Windows 10 / 11（x64 或 arm64）或主流 Linux 发行版（x64 / arm64）
- 可访问外网（下载 Node 与 npm 包）
- 不需要管理员权限 / root

## 可选参数

Windows（注意先取脚本再执行）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1'))) -Port 8080"
```

Linux：

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.sh | bash -s -- --port 8080 --workspace ~/projects
```

| Windows 参数 | Linux 参数 | 默认 | 说明 |
| --- | --- | --- | --- |
| `-Port 8080` | `--port 8080` | 3080 | GUI 端口 |
| `-Workspace D:\projects` | `--workspace ~/projects` | 用户主目录 | 服务启动工作目录（影响新会话默认 workspace） |
| `-Version 0.1.5-rc.3` | `--version 0.1.5-rc.3` | 0.1.5-rc.3 | 安装的 DSH 版本 |
| `-NoAutostart` | `--no-autostart` | 关 | 不创建开机自启 |
| `-NoDesktopShortcut` | `--no-desktop` | 关 | 不创建桌面快捷方式 |
| `-NoStart` | `--no-start` | 关 | 安装后不启动服务 |
| `-NoOpen` | `--no-open` | 关 | 安装后不自动打开 GUI |

## 卸载

Windows：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1'))) -Uninstall"
```

Linux：

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.sh | bash -s -- --uninstall
```

卸载会停止本安装器启动的服务进程、删除快捷方式/启动器与安装目录；
**不删除**会话数据目录（用户主目录下的 `.dsh`），如需彻底清除请手动删除。

## 安全与透明性

- 脚本完全开源，可逐行审查后再执行；
- 安装的 DSH 包来自 **npm 官方 registry**（npm 自带 tarball 完整性校验），版本固定；
- Node 便携包来自 **nodejs.org 官方分发**，内嵌 SHA256 校验；
- 不写注册表、不改系统环境变量（Windows）/ 不动系统目录（Linux 用户级安装）、不收集任何数据、不需要管理员权限；
- Windows 安装目录集中在 `%LOCALAPPDATA%\DeepSeekHarness`；Linux 集中在 `~/.local/share/DeepSeekHarness`（自启 1 项 + 桌面/应用菜单启动器）。

## 维护者：如何更新与发布

1. 修改 `install.ps1` / `install.sh`（若 DSH 出新版本，同步修改 `-Version`/`--version` 默认值与文档）；
2. 推送到 GitHub，用 git tag 标记版本（如 `v1.0.0`），jsDelivr 立即生效；
3. 推荐让用户使用带 tag 的地址以获得可复现安装：`@v1.1.0`；`@latest` 始终指向最新版本（缓存约 12 小时）。

本地沙盒自测（所有目录重定向到 %TEMP%，端口 3093，不弹浏览器）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Test
```

```bash
bash install.sh --test
```

## 免责声明

本项目是社区维护的便捷安装脚本，与 DeepSeek Harness 官方项目无关。
