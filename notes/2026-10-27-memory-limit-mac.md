# Mac에서 Claude 메모리 폭주 막기

증상: Mac 메모리(약 36GB)보다 많은 60GB 이상을 Claude가 쓰면서 Mac이 멈춥니다. 실제 메모리를 넘은 만큼은 스왑(디스크)으로 밀려나서 전체가 느려집니다.

## 먼저 알아 둘 것 (공식 문서, 2026-10-27 확인)

- Claude Code에는 **macOS용 메모리 상한 기능이 없습니다.** `CLAUDE_CODE_TOOL_MEMORY_LIMIT`는 Linux/WSL 전용입니다.
- Claude Code 세션 하나의 힙 메모리가 2.5GB를 넘으면 경고가 뜹니다. 이때는 Claude Code를 종료한 뒤 `claude --continue`로 다시 열면 메모리가 비워집니다.
- `/heapdump`를 실행하면 바탕화면에 메모리 분석 파일이 생깁니다. 이슈를 올릴 때는 `-diagnostics.json`만 첨부합니다. `.heapsnapshot`에는 대화 내용과 인증 정보가 들어 있어서 공유하면 안 됩니다.
- `claude --safe-mode`로 시작했을 때 메모리가 줄면 플러그인이나 MCP 서버가 원인입니다.

## 60GB가 나올 수 있는 원인 후보

| 후보 | 특징 |
|---|---|
| Claude Code가 띄운 명령 | 개발 서버, 빌드, 테스트가 끝나지 않고 계속 쌓임 |
| Playwright 브라우저 | 탭과 브라우저 창이 닫히지 않고 누적됨 |
| Claude Code 본체 | 대화가 아주 길거나 큰 파일을 반복해서 읽음. `/compact` 또는 재시작 |
| Claude 데스크톱 앱 / 가상 머신 | Cowork 같은 기능이 가상 머신을 띄움. 활동 모니터에 별도 항목으로 보임 |
| 여러 세션 동시 실행 | 창마다 각각 메모리를 씀 |

## 1단계: 원인 파악

```bash
cd ~/claude-learning && git pull
tools/claude-mem.sh check
```

Claude Code 세션별, 데스크톱 앱, 가상 머신으로 묶은 합계와, 메모리를 많이 쓰는 프로세스 상위 15개를 보여 줍니다.
**메모리가 많이 찼을 때 실행해야** 원인이 드러납니다. 결과를 붙여 주시면 원인에 맞춰 설정을 조정하겠습니다.

## 2단계: 제한 걸기 (자동 감시)

```bash
./setup-mem-guard.sh          # 설치 (30초마다 검사)
./setup-mem-guard.sh --undo   # 제거
```

| 상황 | 동작 |
|---|---|
| Claude 묶음 합계가 알림 한도(기본: 전체의 40%)를 넘음 | 알림 (10분에 한 번) |
| Claude Code 묶음이 종료 한도(기본: 전체의 55%)를 넘음 | 가장 큰 자식 프로세스(브라우저, 개발 서버 등)를 먼저 종료합니다. 본체가 가장 크면 본체를 종료하고 `claude --continue` 안내를 띄웁니다 |
| 데스크톱 앱이나 가상 머신이 종료 한도를 넘음 | 알림만 띄웁니다. `KILL_DESKTOP=1`이면 앱을 종료합니다 |

- 한도 바꾸기: `~/.claude/mem-guard.conf`의 `WARN_GB`, `LIMIT_GB`를 수정합니다. 다음 검사부터 바로 반영됩니다.
- 기록: `~/Library/Logs/claude-mem-guard.log`
- 메모리 기준: 활동 모니터의 "메모리" 열과 같은 값(top의 MEM)입니다. 압축되거나 스왑으로 나간 메모리도 포함합니다.

## 같이 쓰면 좋은 것

- `./setup-low-load.sh`: 작업을 하나씩 처리하게 해서 동시에 쌓이는 프로세스 자체를 줄입니다.
- 긴 작업 사이에는 `/compact`를 하거나 Claude Code를 재시작합니다.
- 안 쓰는 플러그인은 끕니다. playwright가 특히 무겁습니다.
