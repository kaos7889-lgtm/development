# 클로드 코드로 붙이는 웹 화면 효과 오픈소스 4개

출처: 노션 자료 (2026-09-15 기준). 스킬: `.claude/skills/web-effects/`

## 무엇을

| 도구 | 효과 | 들어가는 곳 | 라이선스 |
|---|---|---|---|
| react-three-fiber | 3D 도형 | 리액트 | MIT |
| shadergradient | 천천히 흐르는 그러데이션 | 리액트 (R3F 위에서 동작) | MIT |
| liquid-logo | 수은처럼 녹는 로고 | liquid.paper.design 에서 업로드만 | PolyForm Shield 1.0.0 |
| liquid-glass-js | 유리 패널 | 순수 HTML | MIT |

라이브러리는 모두 무료이고, 비용은 호스팅 쪽에서만 생깁니다.

## 어떻게

1. **스택 확인**: `cat package.json | grep -E '"(react|next)"'`를 실행해서 결과가 나오면 리액트, 없으면 순수 HTML입니다.
2. **고르기**: 로고 → liquid-logo (5분) / HTML → liquid-glass-js (10분) / 리액트 배경 → shadergradient (15분) / 리액트 3D → R3F (30분 이상)
3. **Claude에게 요청**: 저장소 주소와 함께 **위치 · 색 · 세기**를 말합니다.
   - 나쁜 예: "이 레포로 사이트 멋있게 만들어 줘"
   - 좋은 예: "히어로 배경에만 느리고 은은한 그러데이션, 크림 #FAF7F2 → 주황 #D97757, 입자감 약하게"
4. **다듬기**: 수정은 한 번에 하나만 요청합니다. 두 개를 같이 바꾸면 무엇 때문에 좋아졌는지 알 수 없습니다.
5. **되돌리기**: `git checkout .`을 실행합니다. 커밋하지 않은 변경은 사라지니 남길 것은 먼저 커밋합니다.

## 주의점

- 모두 방문자 기기의 GPU로 돌아갑니다. 효과는 한 페이지에 하나만 넣고, 실제 휴대폰에서 꼭 확인합니다.
- liquid-glass-js는 npm 패키지가 없고 커밋도 1개뿐이라, 파일을 직접 복사해서 씁니다. `file://`로 열면 효과가 보이지 않으니 `npx serve .`로 서버를 띄웁니다.
- liquid-logo는 MIT가 아닙니다. 경쟁 제품을 만드는 용도로는 쓸 수 없습니다.
- `prefers-reduced-motion` 설정을 켠 사람에게는 애니메이션을 멈춥니다. 글자가 얹히는 자리는 효과 세기를 낮춥니다.
- **버전 변경 (2026-09-29 npm 확인)**: `@react-three/fiber` 9.8.1은 React `>=19 <19.4`가 필요합니다. React 18 프로젝트는 fiber 8.x를 씁니다. 그 밖에 `@shadergradient/react` 2.4.20, `@paper-design/shaders-react` 0.0.81, `three` 0.186.1입니다.
