# development

Claude와 Claude Code를 더 잘 활용하기 위해 **학습하고, 기록하고, 연결하는** 공간입니다.

## 구조

| 경로 | 용도 |
|------|------|
| `CLAUDE.md` | Claude Code가 이 저장소에서 작업할 때 항상 읽는 지침 |
| `notes/` | 학습 노트 (기능, 팁, 시행착오, 알게 된 점) |
| `prompts/` | 잘 동작한 프롬프트와 재사용 가능한 템플릿 |
| `.claude/skills/` | 직접 만든 Claude Code 스킬 (`<이름>/SKILL.md`) |

## 사용 방법

- 새로 배운 것은 `notes/YYYY-MM-DD-주제.md` 형식으로 남깁니다.
- 반복해서 쓰는 요청은 `prompts/`에 템플릿으로 저장합니다.
- 템플릿이 절차로 굳어지면 `.claude/skills/`의 스킬로 승격합니다.

## 다른 프로젝트에서 쓰기

```bash
git clone https://github.com/kaos7889-lgtm/development.git ~/claude-learning
~/claude-learning/install.sh      # ~/.claude/skills 에 심볼릭 링크로 설치
```

설치 후 어느 프로젝트 폴더에서든 Claude Code에서 `/web-effects`로 호출하거나, 자연어로 요청하면 자동으로 적용됩니다.
`git pull`만 하면 최신 스킬이 반영됩니다.

## 스킬 목록

| 스킬 | 설명 |
|------|------|
| `web-effects` | 유리 패널·그러데이션·3D·녹는 로고 효과를 스택에 맞게 골라 설치하고 검증 |
