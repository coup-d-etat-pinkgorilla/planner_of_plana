# recognition asset pack (KR/Steam client, 2026-09-27)

런타임 템플릿 생성기(`recognition_synth.py`, 워크플로 D19)의 입력. **스캔 대상 클라이언트(KR/Steam)에서 추출**했다(D17).
JP 클라이언트 asset은 아이콘·스프라이트 크기와 프리팹 기하가 같지만 아틀라스 패킹과 폰트가 다르므로 섞어 쓰지 않는다.

| 내용 | 위치 | 수 | 출처 |
|---|---|---|---|
| 아이템 아이콘 304×240 PNG (일부 512×404·684×540) | `icons-NN.zip` → `icons/items/<Item_Icon_*>.png` | 1068 | `catalog_Windows.bytes`(CCDB)로 `item-rarity-v1.json`의 `icon_path`를 해석 → 31개 번들, Texture2D DXT5 |
| 장비 아이콘 | `icons-NN.zip` → `icons/equipment/<Equipment_Icon_*>.png` | 200 | 위와 같음 |
| 카드 스프라이트 (`Card_Item_Bg_{N,R,SR,SSR}`, `Card_Bg`, `Card_Select_Line`, …) | `sprites/*.png` | 12 | KR `NGUIAtlas Common` (4096×2048, path_id −3795347814732361230) — rect는 `manifest.json.sprites[*].rect` |
| 설계도 배경 `Card_Item_Bg_C` (UITexture `Card_Bg_Gear`) | `sprites/Card_Item_Bg_C.png` | 1 | `prologdepengroup-assets-_mx-addressableasset-uis-_mxprolog-2024-11-18_*` Texture2D −3108102852350029007 |
| UI 폰트 GyeonggiTitle Bold/Medium (`MainFont_Bold`/`MainFont`) | `fonts/*.ttf` | 2 | `prologdepengroup-assets-_mx-uis-_mxcommon-_mxprolog-2024-11-18_*` Font.m_FontData (E5) |
| manifest | `manifest.json` | — | 항목별 sha256, 번들·path_id, KR/JP 프리팹 parity 결과 |

- 등급·카테고리·티어는 `../spec/item-rarity-v1.json`(Steam ExcelDB), 기하는 `../spec/ba-ui-template-spec-v1.json`.
- `icons-01.zip`~`icons-03.zip`은 `icons/` 디렉터리를 20 MB 이하로 나눈 것(멤버 경로 동일). 저장소에는 zip만 넣는다. 로더는 `icons/`가 있으면 그것을, 없으면 모든 `icons-*.zip`을 읽는다.
- 재추출: `backend/tools/asset_spec/README.md` (카탈로그 해석 → 스테이징 → `extract_pack.py`).
- 라이선스: 아이콘·스프라이트는 게임 자산(사용자 판단: 샬레DB 등 공개 배포 선례). 경기천년제목 폰트는 경기도 무료 배포(임베딩 허용) — 배포 전 확인.
- 검증(E4 재실행, tech notes 100타일): KR 팩 M4 top-1 100 %, 정답 점수 med .977, margin min .018 — JP 팩과 동일.
  이전 실패 사례 `SkillBook_Ultimate_Piece`(.48)는 아트 차이가 아니라 **C5b 상세 경로의 오라벨**이었다: 실물 타일은 `Item_Icon_SkillBook_Ultimate`(.909). D18 참조.

> **배포 정책(D24, 2026-09-27)**: 이 폴더의 바이너리(icons-*.zip, fonts/, sprites/)는 **개발·테스트용**이며 git-ignore 대상이다. 런타임은 최초 실행 시 사용자 PC의 Steam 설치 폴더에서 같은 내용을 추출해 캐시로 쓴다(`recognition_asset_extract.py`). `manifest.json`의 sha 목록은 그 추출기의 정답지다.
