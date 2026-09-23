#!/usr/bin/env bash
# DeepSeek Harness one-click installer (Linux x64/arm64)
#   curl -fsSL https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.sh | bash
# Installs @deepseek-ai/dsh, silent autostart (XDG), desktop launcher, starts and opens the Web GUI.
# Windows users: use the PowerShell one-liner (install.ps1) instead.
set -euo pipefail

NODE_MIN="20.19.0"
DSH_VERSION="0.1.5-rc.3"
NODE_VERSION="v22.19.0"
PORT=3080
WORKSPACE=""
NO_AUTOSTART=0
NO_DESKTOP=0
NO_START=0
NO_OPEN=0
UNINSTALL=0
TEST_MODE=0
HELPER_OVERRIDE=""
OS="$(uname -s)"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --port N           GUI port (default 3080)
  --workspace DIR    server working directory (default $HOME)
  --version V        @deepseek-ai/dsh version (default 0.1.5-rc.3)
  --no-autostart     skip autostart entry
  --no-desktop       skip desktop launcher
  --no-start         do not start the server after install
  --no-open          do not open the GUI after install
  --uninstall        stop the server and remove installed files
  --test             sandbox test mode (temp dirs, port 3093, no browser)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --version) DSH_VERSION="$2"; shift 2 ;;
    --no-autostart) NO_AUTOSTART=1; shift ;;
    --no-desktop) NO_DESKTOP=1; shift ;;
    --no-start) NO_START=1; shift ;;
    --no-open) NO_OPEN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --test) TEST_MODE=1; shift ;;
    --helper-dir) HELPER_OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

step() { echo "==> $*"; }
ok() { echo "    [OK] $*"; }
warn() { echo "    [!] $*"; }
fail() { echo "    [XX] $*" >&2; }

case "$OS" in
  Linux) ;;
  MINGW*|MSYS*|CYGWIN*)
    if [ "$TEST_MODE" = "1" ]; then
      warn "running sandbox test under $OS (Linux-only branches are skipped)"
    else
      fail "Windows 请使用 PowerShell 一键安装 (README 中的 install.ps1 命令)。"
      exit 1
    fi
    ;;
  Darwin) fail "macOS 暂不支持本脚本, 请手动安装 Node.js 后执行: npm install -g @deepseek-ai/dsh"; exit 1 ;;
  *) fail "unsupported OS: $OS"; exit 1 ;;
esac

command -v curl >/dev/null 2>&1 || { fail "需要 curl, 请先安装 (Debian/Ubuntu: sudo apt install curl)"; exit 1; }

# ---------------- 目录 ----------------
if [ "$TEST_MODE" = "1" ]; then
  HELPER_DIR="${HELPER_OVERRIDE:-$(mktemp -d)/dsh-oneclick-test}"
  DESKTOP_DIR="$HELPER_DIR/Desktop"
  AUTOSTART_DIR="$HELPER_DIR/autostart"
  DSH_HOME_TEST="$HELPER_DIR/home"
  if [ "$PORT" = "3080" ]; then PORT=3093; fi
  [ -z "$WORKSPACE" ] && WORKSPACE="$HELPER_DIR/workspace"
else
  HELPER_DIR="${HELPER_OVERRIDE:-${XDG_DATA_HOME:-$HOME/.local/share}/DeepSeekHarness}"
  DESKTOP_DIR="$HOME/Desktop"
  AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
  DSH_HOME_TEST=""
fi
[ -n "$WORKSPACE" ] || WORKSPACE="$HOME"
LOG_DIR="$HELPER_DIR/logs"
NPM_DIR="$HELPER_DIR/npm"
mkdir -p "$HELPER_DIR" "$LOG_DIR" "$WORKSPACE" 2>/dev/null || true

# ---------------- Uninstall ----------------
if [ "$UNINSTALL" = "1" ]; then
  step "卸载 DeepSeek Harness 一键安装"
  DSH_BIN="$NPM_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"
  step "停止本安装器启动的服务进程"
  pkill -f "$DSH_BIN" 2>/dev/null && ok "已停止服务进程" || ok "没有运行中的服务进程"
  for f in \
    "${AUTOSTART_DIR}/dsh-harness.desktop" \
    "$HOME/Desktop/dsh-harness.desktop" \
    "$HOME/.local/share/applications/dsh-harness.desktop"; do
    if [ -e "$f" ]; then rm -f "$f"; ok "删除 $f"; fi
  done
  if [ -d "$HELPER_DIR" ]; then rm -rf "$HELPER_DIR"; ok "删除 $HELPER_DIR"; fi
  echo ""
  echo "卸载完成。会话数据目录 (~/.dsh) 已保留, 如不再需要可手动删除。"
  exit 0
fi

# ---------------- 1. Node.js ----------------
ver_ge() { # $1 a, $2 b -> true if a >= b (semver triples)
  local lo
  lo="$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)"
  [ "$lo" = "$1" ]
}

step "检查 Node.js"
NODE=""
NPM_CLI=""
if command -v node >/dev/null 2>&1; then
  NODE_V="$(node --version | sed 's/^v//')"
  if ver_ge "$NODE_MIN" "$NODE_V"; then
    NODE="$(command -v node)"
    ok "复用本机 Node $NODE_V ($NODE)"
  else
    warn "本机 Node $NODE_V 低于 $NODE_MIN, 改用便携版 $NODE_VERSION"
  fi
fi

if [ -z "$NODE" ]; then
  case "$(uname -m)" in
    x86_64|amd64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) fail "不支持的 CPU 架构: $(uname -m)"; exit 1 ;;
  esac
  case "$ARCH" in
    x64)   SHA="c0649af18e6a24f6fe5535a3e86b341dd49a8e71117c8b68bde973ef834f16f2" ;;
    arm64) SHA="d32817b937219b8f131a28546035183d79e7fd17a86e38ccb8772901a7cd9009" ;;
  esac
  NODE_ROOT="$HELPER_DIR/node"
  NODE_DIR="$NODE_ROOT/node-$NODE_VERSION-linux-$ARCH"
  NODE="$NODE_DIR/bin/node"
  if [ ! -x "$NODE" ]; then
    TARBALL="node-$NODE_VERSION-linux-$ARCH.tar.xz"
    URL="https://nodejs.org/dist/$NODE_VERSION/$TARBALL"
    step "下载便携版 Node $NODE_VERSION (linux-$ARCH, 约 30MB)"
    curl -fL --connect-timeout 30 -o "$HELPER_DIR/$TARBALL" "$URL" || { fail "下载失败: $URL"; exit 1; }
    step "校验 SHA256"
    ACTUAL="$(sha256sum "$HELPER_DIR/$TARBALL" | awk '{print $1}')"
    if [ "$ACTUAL" != "$SHA" ]; then
      fail "SHA256 不匹配! 期望 $SHA 实际 $ACTUAL"
      rm -f "$HELPER_DIR/$TARBALL"
      exit 1
    fi
    ok "校验通过"
    step "解压便携版 Node"
    mkdir -p "$NODE_ROOT"
    tar -xJf "$HELPER_DIR/$TARBALL" -C "$NODE_ROOT"
    rm -f "$HELPER_DIR/$TARBALL"
    ok "解压完成"
  fi
  NPM_CLI="$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js"
  ok "便携版 Node $("$NODE" --version) ($NODE)"
else
  # system node: prefer npm command, fall back to npm-cli.js next to node
  if command -v npm >/dev/null 2>&1; then
    NPM_CLI=""
  else
    NPM_CLI="$(dirname "$NODE")/../lib/node_modules/npm/bin/npm-cli.js"
    [ -f "$NPM_CLI" ] || { fail "未找到 npm (已安装 node 但缺少 npm)"; exit 1; }
  fi
fi

run_npm() {
  if [ -n "$NPM_CLI" ]; then "$NODE" "$NPM_CLI" "$@"; else npm "$@"; fi
}

# ---------------- 2. 安装 DSH CLI ----------------
DSH_BIN="$NPM_DIR/node_modules/@deepseek-ai/dsh/lib/bin.js"
INSTALLED_VER=""
if [ -x "$NODE" ] && [ -f "$DSH_BIN" ]; then
  INSTALLED_VER="$("$NODE" "$DSH_BIN" --version 2>/dev/null || true)"
fi
if [ "$INSTALLED_VER" = "$DSH_VERSION" ]; then
  step "DSH CLI 已安装"
  ok "@deepseek-ai/dsh@$INSTALLED_VER 已就绪, 跳过 npm 安装"
else
  if [ -n "$INSTALLED_VER" ]; then step "已装版本 $INSTALLED_VER, 升级到 $DSH_VERSION"
  else step "npm 安装 @deepseek-ai/dsh@$DSH_VERSION"; fi
  mkdir -p "$NPM_DIR"
  echo '{}' > "$NPM_DIR/package.json"
  run_npm install --prefix "$NPM_DIR" --no-save --no-audit --no-fund "@deepseek-ai/dsh@$DSH_VERSION"
  [ -f "$DSH_BIN" ] || { fail "安装后未找到 $DSH_BIN"; exit 1; }
  ok "安装完成: @deepseek-ai/dsh@$DSH_VERSION"
fi

# ---------------- 3. 图标 ----------------
step "写入图标"
ICON_PNG="$HELPER_DIR/dsh.png"
ICON_OK=0
if curl -fsSL --connect-timeout 15 -o "$ICON_PNG" \
  "https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/dsh.png" 2>/dev/null; then
  ok "写入 $ICON_PNG"
  ICON_OK=1
else
  warn "图标下载失败 (离线安装无图标, 不影响使用)"
fi

# ---------------- 4. 生成启动脚本 ----------------
step "生成启动脚本"
AUTOSTART_LOG="$LOG_DIR/dsh-autostart.log"
LAUNCHER_LOG="$LOG_DIR/dsh-launcher.log"
SERVER_LOG="$LOG_DIR/dsh-server.log"
START_SH="$HELPER_DIR/start.sh"
OPEN_SH="$HELPER_DIR/open.sh"

read -r -d '' START_TMPL <<'START_EOF' || true
#!/usr/bin/env bash
# DeepSeek Harness silent autostart (generated by the dsh-oneclick installer).
set -u
PORT=__GUI_PORT__
AUTOSTART_LOG="__AUTOSTART_LOG__"
SERVER_LOG="__SERVER_LOG__"
port_up() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:${PORT}/" 2>/dev/null || true)
  [ -n "$code" ] && [ "$code" != "000" ]
}
log() { echo "[$(date "+%Y-%m-%d %H:%M:%S")] $*" >> "$AUTOSTART_LOG"; }
mkdir -p "$(dirname "$AUTOSTART_LOG")"
if port_up; then
  log "server already running on port $PORT - nothing to do"
  exit 0
fi
cd "__WORK_DIR__" || exit 1
log "starting dsh web (silent, --no-open) ..."
nohup "__NODE_EXE__" "__DSH_BIN__" web --no-open --port "$PORT" >> "$SERVER_LOG" 2>&1 &
disown 2>/dev/null || true
i=0
while [ "$i" -lt 60 ]; do
  sleep 1
  i=$((i + 1))
  if port_up; then
    log "started: server listening on port $PORT after ${i}s"
    exit 0
  fi
done
log "warning: port $PORT not listening after 60s (see dsh-server.log)"
START_EOF

read -r -d '' OPEN_TMPL <<'OPEN_EOF' || true
#!/usr/bin/env bash
# DeepSeek Harness desktop launcher (generated by the dsh-oneclick installer).
set -u
PORT=__GUI_PORT__
LAUNCHER_LOG="__LAUNCHER_LOG__"
SERVER_LOG="__SERVER_LOG__"
CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    /check) CHECK_ONLY=1; shift ;;
    /port) PORT="$2"; shift 2 ;;
    *) shift ;;
  esac
done
port_up() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:${PORT}/" 2>/dev/null || true)
  [ -n "$code" ] && [ "$code" != "000" ]
}
log() { echo "[$(date "+%Y-%m-%d %H:%M:%S")] $*" >> "$LAUNCHER_LOG"; }
mkdir -p "$(dirname "$LAUNCHER_LOG")"
started=0
if ! port_up; then
  s=0
  while [ "$s" -lt 10 ]; do
    sleep 1
    s=$((s + 1))
    port_up && break
  done
fi
if ! port_up; then
  started=1
  log "server not running on port $PORT - starting it silently"
  cd "__WORK_DIR__" || exit 1
  nohup "__NODE_EXE__" "__DSH_BIN__" web --no-open --port "$PORT" >> "$SERVER_LOG" 2>&1 &
  disown 2>/dev/null || true
  i=0
  while [ "$i" -lt 120 ]; do
    sleep 1
    i=$((i + 1))
    port_up && break
  done
  if ! port_up; then
    log "error: server did not start listening within 120s"
    echo "DeepSeek Harness could not be started within 120s. Log: $LAUNCHER_LOG" >&2
    exit 1
  fi
  log "server listening on port $PORT"
fi
wait_token() {
  local secs="$1" i url line
  i=0
  while [ "$i" -lt $((secs * 2)) ]; do
    if [ -f "$SERVER_LOG" ]; then
      line=$(grep "http://127.0.0.1:${PORT}/?token=" "$SERVER_LOG" 2>/dev/null | tail -n1 || true)
      if [ -n "$line" ]; then
        url=$(printf "%s" "$line" | sed -n 's|.*\(http://[^ ]*\).*|\1|p')
        [ -n "$url" ] && { printf '%s\n' "$url"; return 0; }
      fi
    fi
    sleep 0.5
    i=$((i + 1))
  done
  return 1
}
if [ "$started" = "1" ]; then token_url=$(wait_token 30 || true)
else token_url=$(wait_token 3 || true); fi
target=""
if [ -n "$token_url" ]; then
  code=$(curl -s -o /dev/null --max-redirs 0 -w '%{http_code}' --max-time 5 "$token_url" 2>/dev/null || true)
  if [ "$code" = "303" ]; then
    target="$token_url"
    log "using validated token URL"
  else
    log "log token URL stale - falling back to plain URL"
  fi
fi
if [ -z "$target" ]; then
  target="http://127.0.0.1:${PORT}/"
  log "opening plain URL (browser cookie path)"
fi
if [ "$CHECK_ONLY" = "1" ]; then
  log "check: would open $target"
  exit 0
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$target" >/dev/null 2>&1 || true
else
  echo "请手动打开: $target"
fi
log "opened $target"
OPEN_EOF

# token replacement (printf '%s' keeps the template literal; sed swaps the tokens)
printf '%s\n' "$START_TMPL" | sed \
  -e "s|__NODE_EXE__|$NODE|g" \
  -e "s|__DSH_BIN__|$DSH_BIN|g" \
  -e "s|__WORK_DIR__|$WORKSPACE|g" \
  -e "s|__GUI_PORT__|$PORT|g" \
  -e "s|__AUTOSTART_LOG__|$AUTOSTART_LOG|g" \
  -e "s|__LAUNCHER_LOG__|$LAUNCHER_LOG|g" \
  -e "s|__SERVER_LOG__|$SERVER_LOG|g" \
  > "$START_SH"
printf '%s\n' "$OPEN_TMPL" | sed \
  -e "s|__NODE_EXE__|$NODE|g" \
  -e "s|__DSH_BIN__|$DSH_BIN|g" \
  -e "s|__WORK_DIR__|$WORKSPACE|g" \
  -e "s|__GUI_PORT__|$PORT|g" \
  -e "s|__AUTOSTART_LOG__|$AUTOSTART_LOG|g" \
  -e "s|__LAUNCHER_LOG__|$LAUNCHER_LOG|g" \
  -e "s|__SERVER_LOG__|$SERVER_LOG|g" \
  > "$OPEN_SH"
chmod +x "$START_SH" "$OPEN_SH"
ok "写入 $START_SH"
ok "写入 $OPEN_SH"

# ---------------- 5. 自启与桌面入口 ----------------
if [ "$TEST_MODE" != "1" ]; then
  if [ "$NO_AUTOSTART" != "1" ]; then
    step "创建开机自启 (XDG autostart)"
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_DIR/dsh-harness.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=DeepSeek Harness
Comment=Start DeepSeek Harness Web GUI server silently
Exec=$START_SH
Terminal=false
Categories=Development;
X-GNOME-Autostart-enabled=true
EOF
    ok "$AUTOSTART_DIR/dsh-harness.desktop"
  fi
  if [ "$NO_DESKTOP" != "1" ]; then
    step "创建桌面启动器"
    ICON_LINE=""
    [ "$ICON_OK" = "1" ] && ICON_LINE="Icon=$ICON_PNG"
    mkdir -p "$HOME/.local/share/applications" 2>/dev/null || true
    cat > "$HOME/.local/share/applications/dsh-harness.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=DeepSeek Harness
Comment=Open the DeepSeek Harness Web GUI
Exec=$OPEN_SH
$ICON_LINE
Terminal=false
Categories=Development;
EOF
    ok "$HOME/.local/share/applications/dsh-harness.desktop"
    if [ -d "$DESKTOP_DIR" ]; then
      cp "$HOME/.local/share/applications/dsh-harness.desktop" "$DESKTOP_DIR/dsh-harness.desktop"
      chmod +x "$DESKTOP_DIR/dsh-harness.desktop" 2>/dev/null || true
      command -v gio >/dev/null 2>&1 && gio set "$DESKTOP_DIR/dsh-harness.desktop" metadata::trusted true 2>/dev/null || true
      ok "$DESKTOP_DIR/dsh-harness.desktop"
    fi
  fi
fi

# ---------------- 6. 启动服务 ----------------
if [ "$NO_START" != "1" ]; then
  step "启动 DeepSeek Harness 服务"
  if [ "$TEST_MODE" = "1" ] && [ -n "$DSH_HOME_TEST" ]; then
    case "$OS" in
      MINGW*|MSYS*|CYGWIN*) DSH_HOME_TEST="$(cygpath -w "$DSH_HOME_TEST")" ;;
    esac
    export DSH_HOME="$DSH_HOME_TEST"
  fi
  bash "$START_SH"
  up=0
  i=0
  while [ "$i" -lt 90 ]; do
    sleep 1
    i=$((i + 1))
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$PORT/" 2>/dev/null || true)
    if [ -n "$code" ] && [ "$code" != "000" ]; then up=1; break; fi
  done
  if [ "$up" = "1" ]; then
    ok "服务已启动并监听端口 $PORT"
    TOKEN_URL=""
    i=0
    while [ "$i" -lt 60 ]; do
      if [ -f "$SERVER_LOG" ]; then
        TOKEN_URL=$(grep "http://127.0.0.1:$PORT/?token=" "$SERVER_LOG" 2>/dev/null | tail -n1 | sed -n 's|.*\(http://[^ ]*\).*|\1|p' || true)
        [ -n "$TOKEN_URL" ] && break
      fi
      sleep 1
      i=$((i + 1))
    done
    if [ -n "$TOKEN_URL" ]; then
      ok "认证地址已就绪"
      if [ "$TEST_MODE" = "1" ]; then
        CODE=$(curl -s -o /dev/null --max-redirs 0 -w '%{http_code}' --max-time 10 "$TOKEN_URL" 2>/dev/null || true)
        if [ "$CODE" = "303" ]; then ok "token URL 验证通过 (HTTP 303)"; else fail "token URL 返回 $CODE"; fi
        step "验证打开脚本 (check 模式)"
        bash "$OPEN_SH" /check /port "$PORT"
        tail -n3 "$LAUNCHER_LOG" | while IFS= read -r l; do echo "    $l"; done
      fi
    else
      warn "60s 内未见 token URL 输出 (服务可能仍在初始化)"
    fi
    if [ "$TEST_MODE" != "1" ] && [ "$NO_OPEN" != "1" ]; then
      step "打开 Web GUI"
      bash "$OPEN_SH"
      if [ -n "$TOKEN_URL" ]; then echo "    如浏览器未自动打开, 请访问: $TOKEN_URL"; fi
    fi
  else
    fail "90s 内端口 $PORT 未就绪, 请查看日志: $AUTOSTART_LOG / $SERVER_LOG"
  fi
else
  warn "已跳过启动 (--no-start)。之后可通过桌面启动器打开。"
fi

# ---------------- 汇总 ----------------
echo ""
echo "安装完成。"
if [ "$TEST_MODE" != "1" ]; then
  echo "  打开 GUI:  应用菜单/桌面 DeepSeek Harness (或访问 http://127.0.0.1:$PORT/ )"
  echo "  开机自启:  已注册于 XDG autostart (删除 $AUTOSTART_DIR/dsh-harness.desktop 即取消)"
  echo "  卸载:      curl -fsSL https://cdn.jsdelivr.net/gh/squirrelmedia/dsh-oneclick@latest/install.sh | bash -s -- --uninstall"
fi
