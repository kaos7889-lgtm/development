#!/usr/bin/env bash
# Claude 메모리 감시를 macOS 로그인 항목(launchd)으로 설치해 30초마다 실행한다.
# 사용법: ./setup-mem-guard.sh          설치 (한도 변경: ~/.claude/mem-guard.conf)
#         ./setup-mem-guard.sh --undo   제거
set -euo pipefail

[ "$(uname)" = Darwin ] || { echo "macOS 전용입니다."; exit 1; }

label="com.claude-learning.mem-guard"
plist="$HOME/Library/LaunchAgents/$label.plist"
bin="$HOME/.claude/bin/claude-mem.sh"
conf="$HOME/.claude/mem-guard.conf"
domain="gui/$(id -u)"

launchctl bootout "$domain/$label" 2>/dev/null || true

if [ "${1:-}" = "--undo" ]; then
  rm -f "$plist" "$bin"
  echo "메모리 감시를 제거했습니다. (설정 파일 $conf 은 남겨 두었습니다)"
  exit 0
fi

mkdir -p "$(dirname "$bin")" "$(dirname "$plist")" "$HOME/Library/Logs"
cp "$(cd "$(dirname "$0")" && pwd)/tools/claude-mem.sh" "$bin"
chmod +x "$bin"

if [ ! -f "$conf" ]; then
  total=$(( $(sysctl -n hw.memsize) / 1073741824 ))
  cat > "$conf" <<CONF
# Claude 메모리 감시 한도 (GB). Mac 전체 메모리: ${total}GB
WARN_GB=$(( total * 40 / 100 ))    # 넘으면 알림
LIMIT_GB=$(( total * 55 / 100 ))   # 넘으면 원인 프로세스 종료
KILL_DESKTOP=0                     # 1 이면 데스크톱 앱이 한도를 넘을 때 앱을 종료
TOTAL_LIMIT_GB=32                  # Claude 전체 합계가 넘으면 가장 무거운 작업부터 종료
CONF
elif ! grep -q '^TOTAL_LIMIT_GB=' "$conf"; then
  echo 'TOTAL_LIMIT_GB=32                  # Claude 전체 합계가 넘으면 가장 무거운 작업부터 종료' >> "$conf"
fi

cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$bin</string><string>guard</string></array>
  <key>StartInterval</key><integer>30</integer>
  <key>RunAtLoad</key><true/>
  <key>LowPriorityIO</key><true/>
  <key>Nice</key><integer>10</integer>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/claude-mem-guard.err</string>
</dict>
</plist>
PLIST

launchctl bootstrap "$domain" "$plist"
echo "메모리 감시를 설치했습니다 (30초마다 실행)."
echo "한도: $(grep -E '^(WARN|LIMIT|TOTAL_LIMIT)_GB' "$conf" | sed 's/ *#.*//' | tr '\n' ' ')→ 바꾸려면 $conf 수정"
echo "기록: ~/Library/Logs/claude-mem-guard.log"
echo
"$bin" check
