# DeepSeek Harness 一键安装器

一键安装 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的 Web GUI（`dsh web`），
并配置**开机静默自启**（无窗口、不自动弹浏览器）与**桌面快捷方式**。

## 一键安装

在 **PowerShell** 或 **CMD** 中执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1 | iex"
```

也可以下载本仓库的 `install.bat` 后双击运行（效果相同）。

安装完成后：桌面出现「DeepSeek Harness」快捷方式，双击即可打开 GUI
（`http://127.0.0.1:3080/`）；登录 Windows 后服务自动在后台静默运行。

## 安装内容

| 项目 | 说明 |
| --- | --- |
| DSH CLI | 官方 `@deepseek-ai/dsh@0.1.5-rc.3`（npm 官方 registry），安装到 `%LOCALAPPDATA%\DeepSeekHarness\npm`，不影响系统全局 npm |
| Node.js | 本机已有 Node ≥ 20.19 时直接复用；否则自动下载官方便携版 Node v22.19.0（免管理员权限），并做 SHA256 校验 |
| 静默自启 | 启动文件夹快捷方式 → 后台无窗口运行 `dsh web --no-open`，端口被占用时自动跳过 |
| 桌面快捷方式 | 打开 GUI：服务未运行则先静默拉起；优先使用服务器打印的 token 认证 URL（从共享日志提取并验证），否则回退普通 URL（依赖浏览器内 30 天会话 cookie） |
| 日志 | `%LOCALAPPDATA%\DeepSeekHarness\logs\`（自启、桌面、服务器三类日志） |

## 系统要求

- Windows 10 / 11（x64 或 arm64）
- 可访问外网（下载 Node 与 npm 包）
- 不需要管理员权限

## 可选参数

```powershell
# 查看全部参数说明（先下载再查看）
powershell -NoProfile -Command "irm https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1" | more
```

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-Port 8080` | 3080 | GUI 端口 |
| `-Workspace D:\projects` | 用户主目录 | 服务启动工作目录（影响新会话默认 workspace） |
| `-Version 0.1.5-rc.3` | 0.1.5-rc.3 | 安装的 DSH 版本 |
| `-NoAutostart` | 关 | 不创建开机自启 |
| `-NoDesktopShortcut` | 关 | 不创建桌面快捷方式 |
| `-NoStart` | 关 | 安装后不启动服务 |
| `-NoOpen` | 关 | 安装后不自动打开 GUI |

带参数的用法（注意先取脚本再执行）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1'))) -Port 8080"
```

## 卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.ps1'))) -Uninstall"
```

卸载会停止本安装器启动的服务进程、删除两个快捷方式与安装目录；
**不删除**会话数据目录（用户主目录下的 `.dsh`），如需彻底清除请手动删除。

## 安全与透明性

- 脚本完全开源，可逐行审查后再执行；
- 安装的 DSH 包来自 **npm 官方 registry**（npm 自带 tarball 完整性校验），版本固定；
- Node 便携包来自 **nodejs.org 官方分发**，内嵌 SHA256 校验；
- 不写注册表、不改系统环境变量、不收集任何数据、不需要管理员权限；
- 安装目录集中在 `%LOCALAPPDATA%\DeepSeekHarness`，快捷方式共 2 个（桌面 + 启动文件夹）。

## 维护者：如何更新与发布

1. 修改 `install.ps1`（若 DSH 出新版本，同步修改 `-Version` 默认值与文档）；
2. 推送到 GitHub，用 git tag 标记版本（如 `v1.0.0`），jsDelivr 立即生效；
3. 推荐让用户使用带 tag 的地址以获得可复现安装：`@v1.0.0`；`@latest` 始终指向最新版本。

本地沙盒自测（所有目录重定向到 %TEMP%，端口 3093，不弹浏览器）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Test
```

## 免责声明

本项目是社区维护的便捷安装脚本，与 DeepSeek Harness 官方项目无关。
