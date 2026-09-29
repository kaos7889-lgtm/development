---
name: web-effects
description: 웹사이트에 유리 패널, 흐르는 그러데이션 배경, 3D 도형, 녹는 로고 같은 화면 효과를 오픈소스 라이브러리(liquid-glass-js, shadergradient, react-three-fiber, liquid-logo)로 넣는다. 사용자가 "사이트에 움직이는 효과", "그러데이션 배경", "유리 효과", "글래스모피즘", "3D 넣어줘", "로고 애니메이션", "고급스러운 화면 효과"를 요청하거나 /web-effects 를 호출할 때 사용한다.
---

# 웹 화면 효과 넣기

화면 효과는 **무엇을 넣느냐보다 어디에 하나만 넣느냐**가 핵심이다. 아래 순서를 건너뛰지 않는다.

## 1. 스택 확인 (고르기 전에 반드시)

```bash
node --version                                   # v20 이상이어야 함
cat package.json 2>/dev/null | grep -E '"(react|react-dom|next|three|@react-three/fiber|@shadergradient/react)"'
```

- `react`/`next` 가 있으면 리액트 프로젝트, `package.json` 이 없으면 순수 HTML 사이트.
- 이미 설치된 패키지는 재설치하지 말고 버전만 보고한다.

## 2. 라이브러리 고르기 (하나만)

| 상황 | 라이브러리 | 라이선스 |
|---|---|---|
| 로고 PNG만 있음 | liquid-logo — https://liquid.paper.design 에서 투명 PNG 업로드 후 녹화. 코드가 필요하면 `@paper-design/shaders-react` | PolyForm Shield 1.0.0 (경쟁 제품 용도 금지) |
| 순수 HTML | liquid-glass-js — https://github.com/dashersw/liquid-glass-js | MIT |
| 리액트/Next, 배경 그러데이션 | shadergradient — https://github.com/ruucm/shadergradient | MIT |
| 리액트/Next, 3D 도형 | react-three-fiber — https://github.com/pmndrs/react-three-fiber | MIT |

사용자가 위치·색·세기를 말하지 않았으면 먼저 물어본다. 정하지 않으면 README 기본 예제가 그대로 붙어 결과가 싸 보인다.
좋은 지시 예: "히어로 배경에만 느리고 은은한 그러데이션, 크림 #FAF7F2 → 주황 #D97757, 입자감 약하게".

## 3. 설치 — 항상 해당 저장소 README를 먼저 읽고 그대로 따른다

**liquid-glass-js** (npm 배포 없음, 커밋 1개짜리 저장소 → 파일을 직접 복사)
- 필요 파일: `container.js`, `button.js`, `glass.css` + html2canvas CDN 스크립트.
- WebGL이 `file://` 을 못 읽으므로 반드시 `npx serve .` 등 로컬 서버로 연다.

**shadergradient** (react-three-fiber 위에서 동작)
```bash
npm i @shadergradient/react @react-three/fiber three three-stdlib camera-controls
npm i -D @types/three   # TypeScript일 때
```

**react-three-fiber**
```bash
npm i three @react-three/fiber @react-three/drei
```

버전 호환 (확인일 2026-09-29, npm 기준):
- `@react-three/fiber` 9.x → React `>=19 <19.4` 필요. React 18 프로젝트는 fiber 8.x.
- Next 15 App Router → React ^19 + fiber ^9. 효과 컴포넌트는 `'use client'` 로 만든다.
- `@shadergradient/react` 2.4.x → React 18/19 모두 지원.
- 설치 전 `npm view <패키지> version peerDependencies` 로 최신 조건을 다시 확인한다.

## 4. 필수 제약

- 한 페이지에 효과는 **하나만**. 기존 파일은 덮어쓰거나 지우지 않는다.
- `prefers-reduced-motion: reduce` 이면 애니메이션을 멈춘다.
- 탭이 안 보일 때(`document.hidden`) 애니메이션을 멈춘다 (R3F는 `frameloop="demand"` 또는 visibilitychange 처리).
- 글자가 얹히는 자리는 효과 세기를 크게 낮추거나 비워 둔다.
- 수정 요청은 한 번에 한 가지만 반영한다 (더 느리게 / 입자감 줄이기 / 대비 낮추기 등).

## 5. 검증 — 통과 전에는 완료라고 보고하지 않는다

1. 개발 서버를 띄우고 지정한 위치에 효과가 보이는지 확인한다 (가능하면 Playwright로 스크린샷).
2. 브라우저 콘솔에 WebGL 오류가 없는지 확인한다.
3. 모바일 뷰포트(예: 390×844)에서도 확인하고, 사용자에게 실제 휴대폰 확인을 권한다.

## 6. 보고 형식

- 실행한 명령 목록
- Node.js / 설치된 패키지 버전
- 변경한 파일 목록
- 남은 오류 (실패 시: 실패한 명령, 원인, 다음 조치)
- 이 라이브러리가 무엇이고 앞으로 어떻게 쓰는지, 초보자용 5줄 이내 설명
