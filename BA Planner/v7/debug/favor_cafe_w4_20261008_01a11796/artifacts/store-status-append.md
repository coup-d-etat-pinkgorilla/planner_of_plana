
## 2026-10-08 — frontend request 2026-10-08 02:45: favor-cafe-tables

- kind `favor-cafe-tables`: JP `jp-1.73.0-e2baf70e`, ExcelDB sha `a5cfbbb9c7f00ccdd82a59e100febb7ed5eb107bc8ac93c6ed0dede14418416a`. `FavorLevelExcel` 100행 sha `3d76612c4e3b7f7f685dd45bcd38cccd0af48373d5ad6aeaf6269c967edc4293`, `CafeInteractionExcel` 276행 sha `fab6c94f38a5ab0ea6ed426e1bf312adba695aa26e3469a313b69bcde1f61209`. evidence는 두 표 전체 행을 포함한다.
- ExpType 해석 미확정(후보: 랭크별 필요 경험치 / 누적 임계값); Level 1..100, long 벡터 길이1, CharacterExcel FavorLevelupType 0/1. 그룹 인덱스 변환·레벨 경계·합산은 확정하지 않았다. Cafe 보상은 모든276행 FavorExp(11)/Id0/Amount15.
- JP 클라이언트 `CafeService.get_InteractCooltime` RVA `0x1338160` → binary64 3.0 → `System.TimeSpan.FromHours`(함수1개/라운드1개). getter 기준3시간; 가능 횟수·서버 검증·재설정은 미확인. 기존 JSON20파일 pinned hash 일치, 키·원본 복사·네트워크·게임 실행 없음. L3 승격과 소비자 lock 변경 없음.
