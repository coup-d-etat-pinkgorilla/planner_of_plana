# S3B exact 1280x720 minimum capture matrix

`12/23/34`처럼 세 장비 슬롯에 서로 다른 tier/level을 배치해 exact 1280x720 실캡처 수를
최소화한다. Family-specific tier 판독과 slot-specific/family-independent level glyph 판독을
분리해 필요한 coverage와 이론적 하한을 증명하고, 독립 calibration/validation 학생 세트를
포함한 기계 판독 matrix를 인계한다. Production flag, fallback과 S4/S5는 변경하지 않는다.

후속 제약: 호시노·시로코·아코는 이미 성장해 T1부터 촬영할 수 없다. v6 실제 계정 DB의
보유 학생과 현재 장비 상태를 읽기 전용으로 확인하고, empty 또는 T1/Lv1에서 시작할 수 있는
서로 독립적인 calibration/validation 대표 세트로 교체한다.
