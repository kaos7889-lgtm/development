# 추천 도구: 플러그인, 커넥터, MCP

지금 하고 있는 작업(웹사이트 제작, 영상·디자인 콘텐츠, Claude 학습)에 맞춰 골랐습니다.

## 1. claude.ai 플러그인 (claude.ai에서 켜기)

| 플러그인 | 쓰임 |
|---|---|
| frontend-design | 뻔한 AI 느낌이 아닌 완성도 있는 UI를 만들게 함. `web-effects` 스킬과 같이 쓰면 좋음 |
| skill-creator | 노션 자료 같은 노하우를 스킬로 만들고 테스트함. 이 저장소의 핵심 도구 |
| Design | 디자인 비평, 디자인 시스템, UX 문구, 접근성 점검 |
| Figma | 피그마 시안을 코드로 옮기고 셰이더와 모션을 구현 |

## 2. claude.ai 커넥터 (설정 → 커넥터에서 연결)

| 커넥터 | 쓰임 |
|---|---|
| Context7 | 라이브러리 최신 문서. 버전이 바뀌어 설치 명령이 틀리는 문제를 줄여 줌 |
| Vercel | 만든 사이트를 배포하고 배포 오류를 확인 |
| vidIQ | 유튜브·인스타·틱톡 키워드와 트렌드 리서치 |
| Figma | 디자인 시안을 가져와서 코드로 만들 때 |
| Google Calendar | **연결이 미완료 상태**. 설정에서 다시 연결해야 함 |

이미 연결된 커넥터: Notion, Gmail, Google Drive, Canva, Lovable, 힉스필드

## 3. 내 PC의 Claude Code (터미널)

```bash
~/claude-learning/setup-mcp.sh    # Context7, Playwright MCP 등록
```

Claude Code 안에서 공식 플러그인을 설치하는 방법:

```
/plugin install frontend-design@claude-plugins-official
/plugin install skill-creator@claude-plugins-official
```

설치한 뒤에는 `/plugin`과 `/mcp`로 설치된 목록을 확인합니다.
