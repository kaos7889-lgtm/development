#!/usr/bin/env bash
# 추천 플러그인을 사용자 범위(user)로 설치해 모든 프로젝트에서 쓰게 한다.
# 이미 설치된 것은 그대로 두고, 실패한 항목은 끝에 모아 보여 준다.
# 사용법: ./setup-plugins.sh
set -uo pipefail

command -v claude >/dev/null || { echo "claude CLI가 없습니다. 먼저 Claude Code를 설치하세요."; exit 1; }

marketplaces=(
  anthropics/claude-plugins-official   # Anthropic 공식
  anthropics/knowledge-work-plugins    # 업무용 (design 등)
)

plugins=(
  frontend-design@claude-plugins-official   # 완성도 있는 UI 제작
  skill-creator@claude-plugins-official     # 스킬 만들기·테스트
  context7@claude-plugins-official          # 라이브러리 최신 문서
  playwright@claude-plugins-official        # 브라우저로 화면 확인
  figma@claude-plugins-official             # 피그마 시안 → 코드
  vercel@claude-plugins-official            # 사이트 배포
  design@knowledge-work-plugins             # 디자인 비평·UX 문구·접근성
)

failed=()

for m in "${marketplaces[@]}"; do
  claude plugin marketplace add "$m" >/dev/null 2>&1 || true   # 이미 있으면 무시
done

for p in "${plugins[@]}"; do
  if claude plugin install --scope user "$p" >/dev/null 2>&1; then
    echo "설치: $p"
  else
    echo "실패: $p"
    failed+=("$p")
  fi
done

echo
claude plugin list
if [ ${#failed[@]} -gt 0 ]; then
  echo
  echo "실패한 플러그인 (claude 실행 후 /plugin install <이름> 으로 다시 시도): ${failed[*]}"
  exit 1
fi
echo
echo "완료. Claude Code를 다시 시작하면 적용됩니다. figma, vercel은 처음 쓸 때 로그인 창이 뜹니다."
