#!/usr/bin/env bash
# Claude 관련 프로세스의 메모리 사용량을 진단하고, 한도를 넘으면 정리한다 (macOS).
#
#   claude-mem.sh check   어떤 Claude 프로세스가 메모리를 얼마나 쓰는지 표로 보여 준다
#   claude-mem.sh guard   한도를 넘으면 알림 → 원인 프로세스 종료 (launchd가 30초마다 실행)
#   claude-mem.sh stop-heaviest   지금 가장 무거운 Claude 작업 하나를 바로 종료 (수동)
#
# 메모리 값은 활동 모니터의 "메모리" 열과 같은 기준(압축·스왑 포함)인 top 의 MEM 을 쓴다.
# 한도는 ~/.claude/mem-guard.conf 에서 바꾼다:
#   WARN_GB=14        # 넘으면 알림
#   LIMIT_GB=20       # 넘으면 원인 프로세스 종료
#   KILL_DESKTOP=0    # 1 이면 Claude 데스크톱 앱이 한도를 넘을 때 앱을 종료
#   TOTAL_LIMIT_GB=32 # 모든 Claude 프로세스 합계가 넘으면 가장 무거운 작업부터 하나씩 종료
# 테스트용: DRY_RUN=1 (실제로 종료하지 않음), TOP_OUT_FILE / PS_OUT_FILE / TOTAL_GB (입력 대체)
set -uo pipefail

conf="$HOME/.claude/mem-guard.conf"
[ -f "$conf" ] && . "$conf"

TOTAL_GB="${TOTAL_GB:-$(( $(sysctl -n hw.memsize) / 1073741824 ))}"
WARN_GB="${WARN_GB:-$(( TOTAL_GB * 40 / 100 ))}"
LIMIT_GB="${LIMIT_GB:-$(( TOTAL_GB * 55 / 100 ))}"
KILL_DESKTOP="${KILL_DESKTOP:-0}"
TOTAL_LIMIT_GB="${TOTAL_LIMIT_GB:-32}"
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
  echo "Mac 메모리 ${TOTAL_GB}GB · 알림 ${WARN_GB}GB · 묶음별 종료 ${LIMIT_GB}GB · 전체 ${TOTAL_LIMIT_GB}GB 넘으면 가장 무거운 작업부터 종료"
  echo "Claude 전체 사용량: $(gb "$(printf '%s\n' "$snap" | awk '{ s += $3 } END { print s + 0 }')")GB"
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

# 종료해도 되는 프로세스 중 가장 무거운 것: "pid mem_mb 설명"
# Claude Code 본체와 그 자식(명령·브라우저·MCP)은 항상 대상, 데스크톱 앱·가상 머신은 KILL_DESKTOP=1 일 때만
heaviest() {  # snapshot [이미 종료한 pid 목록]
  printf '%s\n' "$1" | awk -v kd="$KILL_DESKTOP" -v skip=" ${2:-} " '
    ($1 ~ /^cli-/ || kd == 1) && index(skip, " " $2 " ") == 0 {
      n = $0; for (i = 1; i <= 4; i++) sub(/^[^ ]+ /, "", n)
      k = split(n, a, "/"); short = a[k]
      what = ($4 == "root") ? "Claude Code 본체 (claude --continue 로 이어서 작업)" : \
             ($1 ~ /^cli-/ ? "Claude Code가 띄운 " short : ($1 == "vm" ? "가상 머신" : "Claude 데스크톱 앱 " short))
      print $3, $2, what
    }' | sort -k1,1nr | head -1 | awk '{ m = $1; p = $2; $1 = ""; $2 = ""; sub(/^  /, ""); print p, m, $0 }'
}

# 모든 Claude 프로세스 합계가 TOTAL_LIMIT_GB 를 넘으면, 내려갈 때까지 가장 무거운 작업부터 하나씩 종료 (최대 5개)
total_guard() {
  local limit_mb=$(( TOTAL_LIMIT_GB * 1024 )) snap total fixed pid mem what i done=""
  for i in 1 2 3 4 5; do
    snap="$(snapshot)"; [ -z "$snap" ] && return
    total=$(printf '%s\n' "$snap" | awk '{ s += $3 } END { print s + 0 }')
    [ "$total" -lt "$limit_mb" ] && return
    # 종료 대상이 아닌 것(데스크톱 앱·가상 머신)만으로 한도를 넘으면 터미널 작업을 꺼도 소용없으니 알림만
    fixed=$(printf '%s\n' "$snap" | awk -v kd="$KILL_DESKTOP" '$1 !~ /^cli-/ && kd != 1 { s += $3 } END { print s + 0 }')
    read -r pid mem what < <(heaviest "$snap" "$done")
    if [ "$fixed" -ge "$limit_mb" ] || [ -z "${pid:-}" ]; then
      notify "Claude 전체 $(gb "$total")GB (한도 ${TOTAL_LIMIT_GB}GB). 데스크톱 앱·가상 머신이 $(gb "$fixed")GB로 원인입니다. 앱을 재시작하세요"
      return
    fi
    stop_pid "$pid" "Claude 전체 $(gb "$total")GB > ${TOTAL_LIMIT_GB}GB → 가장 무거운 작업: $what $(gb "$mem")GB"
    done="$done $pid"
    [ "$DRY_RUN" = 1 ] && return
  done
}

stop_heaviest() {
  local snap pid mem what
  snap="$(snapshot)"
  read -r pid mem what < <(heaviest "$snap")
  [ -z "${pid:-}" ] && { echo "종료할 Claude 작업이 없습니다."; return; }
  stop_pid "$pid" "수동 종료: $what $(gb "$mem")GB"
}

guard() {
  total_guard
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
  stop-heaviest) stop_heaviest ;;
  *) echo "사용법: $0 check | guard | stop-heaviest"; exit 1 ;;
esac
