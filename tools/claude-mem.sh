#!/usr/bin/env bash
# Claude 관련 프로세스의 메모리 사용량을 진단하고, 한도를 넘으면 정리한다 (macOS).
#
#   claude-mem.sh check   어떤 Claude 프로세스가 메모리를 얼마나 쓰는지 표로 보여 준다
#   claude-mem.sh guard   한도를 넘으면 알림 → 원인 프로세스 종료 (launchd가 30초마다 실행)
#
# 메모리 값은 활동 모니터의 "메모리" 열과 같은 기준(압축·스왑 포함)인 top 의 MEM 을 쓴다.
# 한도는 ~/.claude/mem-guard.conf 에서 바꾼다:
#   WARN_GB=14        # 넘으면 알림
#   LIMIT_GB=20       # 넘으면 원인 프로세스 종료
#   KILL_DESKTOP=0    # 1 이면 Claude 데스크톱 앱이 한도를 넘을 때 앱을 종료
# 테스트용: DRY_RUN=1 (실제로 종료하지 않음), TOP_OUT_FILE / PS_OUT_FILE / TOTAL_GB (입력 대체)
set -uo pipefail

conf="$HOME/.claude/mem-guard.conf"
[ -f "$conf" ] && . "$conf"

TOTAL_GB="${TOTAL_GB:-$(( $(sysctl -n hw.memsize) / 1073741824 ))}"
WARN_GB="${WARN_GB:-$(( TOTAL_GB * 40 / 100 ))}"
LIMIT_GB="${LIMIT_GB:-$(( TOTAL_GB * 55 / 100 ))}"
KILL_DESKTOP="${KILL_DESKTOP:-0}"
DRY_RUN="${DRY_RUN:-0}"
log="$HOME/Library/Logs/claude-mem-guard.log"
stamp="$HOME/.claude/.mem-guard-last-warn"

# 출력: group pid mem_mb role name
#   group: cli-<최상위 claude pid> | desktop | vm
#   role : root (claude 본체) | child (Claude가 띄운 명령·MCP·브라우저 등)
snapshot() {
  local top_out ps_out
  if [ -n "${TOP_OUT_FILE:-}" ]; then top_out="$(cat "$TOP_OUT_FILE")"
  else top_out="$(top -l 1 -stats pid,mem 2>/dev/null)"; fi
  if [ -n "${PS_OUT_FILE:-}" ]; then ps_out="$(cat "$PS_OUT_FILE")"
  else ps_out="$(ps -axo pid=,ppid=,comm=)"; fi

  awk '
    function mb(v,  n, u) {
      gsub(/[+-]$/, "", v); u = substr(v, length(v)); n = substr(v, 1, length(v) - 1) + 0
      if (u == "G") return n * 1024; if (u == "M") return n; if (u == "K") return n / 1024
      if (u == "B") return n / 1048576; return v / 1048576
    }
    function base(p,  a, k) { k = split(p, a, "/"); return a[k] }
    FNR == NR { if ($1 ~ /^[0-9]+$/ && NF >= 2) mem[$1] = mb($2); next }
    {
      pid = $1; ppid = $2; name = $0
      sub(/^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+/, "", name)
      parent[pid] = ppid; nm[pid] = name; order[++n] = pid
    }
    END {
      for (i = 1; i <= n; i++) {
        pid = order[i]; g = ""; cli = ""
        for (p = pid; p != "" && p > 1 && d < 64; p = parent[p]) {
          if (base(nm[p]) == "claude") cli = p
          if (nm[p] ~ /\/Claude\.app\//) g = "desktop"
          d++
        }
        d = 0
        if (cli != "") g = "cli-" cli
        else if (g == "" && nm[pid] ~ /Virtualization\.VirtualMachine/) g = "vm"
        if (g == "") continue
        role = (g ~ /^cli-/ && pid == cli) ? "root" : "child"
        printf "%s %s %d %s %s\n", g, pid, mem[pid] + 0, role, nm[pid]
      }
    }
  ' <(printf '%s\n' "$top_out") <(printf '%s\n' "$ps_out")
}

notify() {
  echo "$(date '+%F %T') $1" >> "$log"
  [ "$DRY_RUN" = 1 ] && { echo "[알림] $1"; return; }
  osascript -e "display notification \"$1\" with title \"Claude 메모리 감시\"" >/dev/null 2>&1 || true
}

stop_pid() {  # pid, 설명
  notify "$2 (PID $1) 종료"
  [ "$DRY_RUN" = 1 ] && return
  kill -TERM "$1" 2>/dev/null; sleep 5; kill -0 "$1" 2>/dev/null && kill -KILL "$1" 2>/dev/null
}

gb() { awk -v m="$1" 'BEGIN { printf "%.1f", m / 1024 }'; }

check() {
  local snap; snap="$(snapshot)"
  echo "Mac 메모리 ${TOTAL_GB}GB · 알림 ${WARN_GB}GB · 종료 ${LIMIT_GB}GB"
  echo "스왑: $(sysctl -n vm.swapusage 2>/dev/null || echo 알 수 없음)"
  echo
  if [ -z "$snap" ]; then echo "실행 중인 Claude 프로세스가 없습니다."; return; fi
  echo "== 묶음별 합계 =="
  printf '%s\n' "$snap" | awk '
    { s[$1] += $3; c[$1]++ }
    END { for (g in s) {
      label = g ~ /^cli-/ ? "Claude Code (터미널) " substr(g, 5) : (g == "desktop" ? "Claude 데스크톱 앱" : "가상 머신 (Cowork·Docker 등)")
      printf "%8.1f GB  %-36s 프로세스 %d개\n", s[g] / 1024, label, c[g] } }' | sort -rn
  echo
  echo "== 메모리를 많이 쓰는 프로세스 상위 15 =="
  printf '%s\n' "$snap" | sort -k3,3nr | head -15 | awk '{
    name = $0; for (i = 1; i <= 4; i++) sub(/^[^ ]+ /, "", name)
    printf "%8.1f GB  PID %-7s %-6s %s\n", $3 / 1024, $2, $4, name }'
  echo
  echo "role: root = claude 본체, child = Claude가 띄운 명령·MCP 서버·브라우저 등"
}

guard() {
  local snap warn_mb=$(( WARN_GB * 1024 )) limit_mb=$(( LIMIT_GB * 1024 ))
  snap="$(snapshot)"; [ -z "$snap" ] && return
  printf '%s\n' "$snap" | awk '{ s[$1] += $3 } END { for (g in s) print g, s[g] }' |
  while read -r group total; do
    if [ "$total" -ge "$limit_mb" ]; then
      if [[ "$group" == cli-* ]]; then
        # 가장 큰 자식(명령·브라우저 등)이 본체보다 크면 자식부터 정리하고, 아니면 본체를 종료
        read -r cpid cmem cname < <(printf '%s\n' "$snap" | awk -v g="$group" '$1 == g && $4 == "child"' | sort -k3,3nr | head -1 | awk '{ n = $0; for (i = 1; i <= 4; i++) sub(/^[^ ]+ /, "", n); print $2, $3, n }')
        rmem=$(printf '%s\n' "$snap" | awk -v g="$group" '$1 == g && $4 == "root" { print $3 }')
        if [ -n "${cpid:-}" ] && [ "${cmem:-0}" -ge "${rmem:-0}" ]; then
          stop_pid "$cpid" "Claude Code가 띄운 $(basename "$cname")가 $(gb "$cmem")GB 사용 (합계 $(gb "$total")GB)"
        else
          stop_pid "${group#cli-}" "Claude Code 본체가 $(gb "${rmem:-0}")GB 사용. 'claude --continue'로 이어서 작업하세요"
        fi
      else
        if [ "$KILL_DESKTOP" = 1 ] && [ "$group" = desktop ]; then
          notify "Claude 데스크톱 앱이 $(gb "$total")GB 사용 → 앱 종료"
          [ "$DRY_RUN" = 1 ] || osascript -e 'quit app "Claude"' >/dev/null 2>&1
        else
          notify "$([ "$group" = vm ] && echo '가상 머신' || echo 'Claude 데스크톱 앱')이 $(gb "$total")GB 사용 중 (한도 ${LIMIT_GB}GB). 앱을 재시작하세요"
        fi
      fi
    elif [ "$total" -ge "$warn_mb" ]; then
      now=$(date +%s); last=$(cat "$stamp" 2>/dev/null || echo 0)
      if [ $(( now - last )) -ge 600 ]; then
        echo "$now" > "$stamp"
        notify "Claude 메모리 $(gb "$total")GB 사용 중. /compact 하거나 재시작하세요"
      fi
    fi
  done
}

case "${1:-check}" in
  check) check ;;
  guard) guard ;;
  *) echo "사용법: $0 check | guard"; exit 1 ;;
esac
