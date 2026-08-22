# Master verification prompt

S3B position-digit handoff를 검증한다. `output.md`의 각 artifact 크기/SHA-256을 실제 파일과
대조하고 다음 명령을 실행한다.

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v
py -3.11 tools/benchmark_student_equipment_s3b_position.py
cd ..
codealmanac validate
codealmanac health
git diff --check
```

다음 경계를 확인한다.

- `position_binary_production_enabled`는 19-mask level 경로에만 적용된다.
- exact 1280x720 결과는 30/30이고 전체 frozen replay는 349/349, accepted wrong 0이다.
- 원본 screenshot pixel은 runtime asset에 없다.
- Kurumi Necklace T2 tier-icon rejection은 별도 미해결이며 S4/S5는 변경되지 않았다.
