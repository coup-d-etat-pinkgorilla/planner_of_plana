불일치: [표] SkillExcel에 애니메이션/상태 필드가 없어 허용된 연결 근거가 없다. [?] 과제의 anim_event estimated=false는 불변 계약/fixture의 의미 추론 표시와 충돌한다.

# A1 애니메이션 스펙트럼 표본 검수 — 2026-10-10

[표] NOT_VERIFIED — 출력 스키마·산술·원자료 대조는 통과했으나 미카 EX 로직 마커의 클립 배치는 미확정이다. 슬롯 순서·이름 유사도로 연결하지 않았다.

| 항목 | 결과 | 근거 |
|---|---|---|
| 전체 출력 | PASS | [표] 1468개 schema/SHA/bytes/파일명/프레임 산술 일치 |
| Binah_Original_Normal_Attack | PASS | [관측] 길이 140f; 이벤트 [5, 50]; bundle/fps/초/이름/종류/estimated/evidence 동일 |
| Binah_Original_Vital_Groggy | PASS | [관측] 길이 340f; 이벤트 [0, 13, 265]; bundle/fps/초/이름/종류/estimated/evidence 동일 |
| 미카 EX anim_event | PASS | [관측] SetMouthTile 4건, 모두 other |
| 미카 EX 원 release | PASS | [표] [30, 32, 34, 38, 42, 53, 57, 62, 66, 71, 75]; 원 rowSha와 skill-timing-jp 일치, index에 logic_effect 마커로 보존 |
| 미카 EX 클립 안의 release | NOT_VERIFIED | [?] 명시 SkillExcel 연결 필드가 없어서 클립에는 붙이지 않음 |
| callback estimated=false 요청 | NOT_VERIFIED | [?] sfx/vfx는 callback 이름으로 의미를 추론하므로 계약대로 true; other는 false(반 프레임 이상 반올림 예외) |

[표] fixture는 변경하지 않았다. 값 비교는 설명문 note만 제외하며 나머지 두 clip 객체의 모든 값이 동일하다. sourceFps와 30 fps 로직 축을 별도로 유지했다.

[표] 계약 밖 kind 4390개는 index.invalid에 schema 오류를 남기고 출력에서 제외했다. enemy를 boss로 바꾸지 않았다.

[표] T3 대조: Normal_Attack 140f는 클립 길이이며 전체 행동 Duration으로 대체하지 않았다. Vital_Groggy 340f도 별도 300f 로직 clock으로 바꾸지 않았다.

[?] CM 후속 선택: 명시된 클립↔스킬 연결 자료를 제공하거나, 학생의 SkillList ex 슬롯↔Exs 상태를 연결하는 규칙을 별도 근거로 승인한 후 새 블록에서 병합. 현재 규칙만으로 보스 EX 연결도 미확정이다.

CF A2 표본 입력:

C:\Users\brigh\planner_of_plana\BA Planner\v7\data\extracted\animation-spectrum\jp-1.73.0-e2baf70e\7300700.json
C:\Users\brigh\planner_of_plana\BA Planner\v7\data\extracted\animation-spectrum\jp-1.73.0-e2baf70e\10059.json
C:\Users\brigh\planner_of_plana\BA Planner\v7\data\extracted\animation-spectrum\jp-1.73.0-e2baf70e\index.json

[?] CF는 현재 anim_event를 표시할 수 있다. 로직 층의 클립 배치를 완료로 처리하면 안 된다.
