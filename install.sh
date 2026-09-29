#!/usr/bin/env bash
# 이 저장소의 스킬을 ~/.claude/skills 로 설치해 모든 프로젝트에서 쓸 수 있게 한다.
# 사용법: ./install.sh          (심볼릭 링크 — git pull 하면 자동 반영)
#         ./install.sh --copy   (복사)
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)/.claude/skills"
dest="$HOME/.claude/skills"
mkdir -p "$dest"

for skill in "$src"/*/; do
  name="$(basename "$skill")"
  target="$dest/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "건너뜀: $target 가 이미 있습니다 (직접 확인 후 삭제하세요)"
    continue
  fi
  rm -f "$target"
  if [ "${1:-}" = "--copy" ]; then
    cp -R "$skill" "$target"
  else
    ln -s "${skill%/}" "$target"
  fi
  echo "설치: $name -> $target"
done
