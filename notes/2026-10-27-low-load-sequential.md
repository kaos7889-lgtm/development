# Mac 과부하 방지: Claude Code 작업을 하나씩 처리하기

Claude Code가 서브에이전트, 백그라운드 명령, 워크플로를 동시에 여러 개 띄우면 Mac이 멈출 수 있습니다.
`setup-low-load.sh`로 동시 실행을 1개로 제한합니다. 2026-10-27에 공식 문서(env-vars, sub-agents)에서 확인한 값입니다.

## 적용

```bash
cd ~/claude-learning && git pull
./setup-low-load.sh          # 적용 (기존 설정은 ~/.claude/settings.json.bak 으로 백업)
./setup-low-load.sh --undo   # 되돌리기
```

적용한 뒤에는 실행 중인 Claude Code를 **모두 종료하고** 다시 시작해야 반영됩니다.

## 무엇을 바꾸나

`~/.claude/settings.json`의 `env`:

| 변수 | 값 | 효과 |
|---|---|---|
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` | 1 | 서브에이전트를 동시에 1개만 실행 (기본 20) |
| `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` | 1 | 서브에이전트가 또 서브에이전트를 띄우지 못함 (기본 3) |
| `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` | 1 | 워크플로 에이전트가 줄을 서서 하나씩 실행 (기본 최대 16) |
| `CLAUDE_CODE_FORK_SUBAGENT` | 0 | 포크 모드를 끔. 켜져 있으면 Claude가 서브에이전트를 기다리지 못하고 백그라운드로 돌림 |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | 1 | 백그라운드 실행을 끔. 명령과 서브에이전트가 끝날 때까지 기다린 뒤 다음으로 넘어감 |

`~/.claude/CLAUDE.md`에는 "한 번에 하나씩 처리, 무거운 명령 동시 실행 금지, 개발 서버·브라우저는 확인 후 종료" 지침을 추가합니다.

## 알아 둘 점

- **동시 실행 제한의 동작 방식**: 한도에 걸리면 줄을 서는 게 아니라 생성이 거절되고, Claude는 그 일을 직접 이어서 합니다. 실제로 순서를 지키게 하는 건 CLAUDE.md 지침입니다.
- **개발 서버**: 백그라운드 실행을 끄면 Claude가 개발 서버를 띄워 둔 채 다른 일을 할 수 없습니다. `web-effects` 스킬의 화면 확인 단계에서는 서버를 직접 터미널에서 띄워 두고 주소를 알려 주세요.
- **Claude Code 창 여러 개**: 위 설정은 세션 하나 안에서만 적용됩니다. 터미널이나 앱 창을 여러 개 열어 동시에 돌리면 제한이 걸리지 않으니, 한 번에 하나만 쓰세요.
- **무거운 플러그인**: playwright는 브라우저를 통째로 띄웁니다. 필요 없을 때는 `claude plugin disable playwright@claude-plugins-official`로 꺼 둡니다.
- **"Overloaded" 오류**: 이 메시지는 Anthropic 서버가 바쁘다는 뜻이고 Mac과는 관계가 없습니다. 잠시 뒤 다시 시도하면 됩니다.
