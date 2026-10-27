#!/usr/bin/env bash
# Claude Code가 작업을 동시에 여러 개 돌리지 않고 하나씩 처리하도록 사용자 설정에 제한을 건다.
#   - ~/.claude/settings.json 의 env 에 동시 실행 제한 값을 합친다 (기존 설정은 .bak 으로 백업)
#   - ~/.claude/CLAUDE.md 에 "하나씩 처리" 지침을 추가한다 (이미 있으면 교체)
# 사용법: ./setup-low-load.sh          적용
#         ./setup-low-load.sh --undo   되돌리기
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dir="$HOME/.claude"
settings="$dir/settings.json"
claudemd="$dir/CLAUDE.md"
mkdir -p "$dir"


command -v node >/dev/null || { echo "node가 필요합니다 (https://nodejs.org 에서 LTS 설치)"; exit 1; }

mode="${1:-apply}"
[ -f "$settings" ] && cp "$settings" "$settings.bak"

node - "$settings" "$here/config/low-load-env.json" "$mode" <<'JS'
const fs = require('fs');
const [file, envFile, mode] = process.argv.slice(2);
const s = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
const add = JSON.parse(fs.readFileSync(envFile, 'utf8'));
s.env = s.env || {};
for (const [k, v] of Object.entries(add)) {
  if (mode === '--undo') delete s.env[k]; else s.env[k] = v;
}
if (Object.keys(s.env).length === 0) delete s.env;
fs.writeFileSync(file, JSON.stringify(s, null, 2) + '\n');
JS

# CLAUDE.md: 기존 low-load 블록을 지우고, 적용 모드면 새로 붙인다
touch "$claudemd"
node - "$claudemd" "$here/config/low-load-CLAUDE.md" "$mode" <<'JS'
const fs = require('fs');
const [file, blockFile, mode] = process.argv.slice(2);
let t = fs.readFileSync(file, 'utf8').replace(/\n*<!-- low-load:start -->[\s\S]*?<!-- low-load:end -->\n?/, '\n');
t = t.replace(/^\n+/, '');
if (mode !== '--undo') t = (t.trimEnd() ? t.trimEnd() + '\n\n' : '') + fs.readFileSync(blockFile, 'utf8');
fs.writeFileSync(file, t);
JS

if [ "$mode" = "--undo" ]; then
  echo "되돌렸습니다."
else
  echo "적용했습니다. 실행 중인 Claude Code를 모두 종료하고 다시 시작하면 반영됩니다."
fi
echo "설정 파일: $settings (백업: $settings.bak)"
