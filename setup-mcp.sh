#!/usr/bin/env bash
# 모든 프로젝트에서 쓸 MCP 서버를 사용자 범위(--scope user)로 Claude Code에 등록한다.
# 이미 등록된 것은 건너뛴다. 사용법: ./setup-mcp.sh
set -euo pipefail

command -v claude >/dev/null || { echo "claude CLI가 없습니다. 먼저 Claude Code를 설치하세요."; exit 1; }

add() {
  local name="$1"; shift
  if claude mcp get "$name" >/dev/null 2>&1; then
    echo "건너뜀: $name (이미 등록됨)"
  else
    claude mcp add --scope user "$name" "$@" && echo "등록: $name"
  fi
}

# Context7: 라이브러리 최신 문서를 가져온다 (three, R3F 같은 버전 변화가 잦은 패키지에 유용)
add context7 --transport http https://mcp.context7.com/mcp

# Playwright: 브라우저를 띄워 화면에 효과가 보이는지, 콘솔 오류가 없는지 직접 확인한다
add playwright -- npx -y @playwright/mcp@latest

claude mcp list
