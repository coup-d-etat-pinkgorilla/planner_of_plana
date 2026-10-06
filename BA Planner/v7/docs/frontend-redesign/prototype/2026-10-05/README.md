# UI 개선 시안 사본

Design 캔버스 "BA Planner v7 UI 개선 시안"(https://claude.ai/artifact/BqhYfDnvkiQCTjDv8XgYJ3)의 artboard 원문 사본이다.
2026-10-05(version `1791201546-3bff`)에 50장을 넣었고, 2026-10-06(version `1791216886-b4f5`)에 스캔 탭 6장(`Scan*.dc.html`)과
성장 계산기(`Calc-Student.dc.html`)를 더했다. 각 파일이 들어온 날짜는 `MANIFEST.json`의 `added`에 있다.
택틱 페이지(`Tactic-*`, `Boss-*`, `Tactical-Timeline.dc.html`)는 프론트 개편 범위 밖이라 넣지 않았다.

- 모든 화면 artboard는 2560×1392(최대화 작업 영역) 절대좌표다. 헤더 아래 콘텐츠 영역은 y=184부터다.
- 이미지와 폰트(`/_blob/…`)는 들어 있지 않다. 그림 비교는 캔버스에서 한다.
- 원문은 파일마다 같은 공통 CSS가 반복되고 사선 path가 길다. `py -3.11 docs/frontend-redesign/tools/dc_outline.py <파일> [--abs] [--text-only]`로 읽는다.
- `<script type="text/x-dc">`는 전부 비어 있다. 상태 전이는 변형 artboard(-One, -Many, -Filter, -Run, -Review 등)의 차이로 표현되어 있다.
- 파일 무결성은 `MANIFEST.json`의 sha256으로 확인한다. 새 artboard는 이 폴더에 더하고 MANIFEST에 기록한다.
  **이미 있는 artboard의 내용이 캔버스에서 바뀌면** 이 폴더의 파일을 덮지 말고 새 날짜 폴더에 사본을 다시 만든다(이전 구현의 근거를 보존).
- 어느 artboard가 어느 slice·코드에 대응하는지는 `docs/frontend-redesign/artboard-map.md`에 있다.
