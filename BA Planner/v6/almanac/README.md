---
title: "BA Planner Almanac"
summary: "BA Planner의 설계 의도, 불변식, 교차 파일 흐름을 안내하는 저장소 로컬 위키입니다."
topics: [architecture]
sources: []
---

# BA Planner Almanac

이 위키는 코드만으로 알기 어려운 이유와 제약을 보존합니다. 함수 목록이나 파일
내용을 다시 적는 대신, 리팩토링 전에 알아야 할 경계와 실패하기 쉬운 가정을
기록합니다.

## 작업별 시작점

- 전체 구조와 프로세스 경계: [Runtime Boundaries](architecture/runtime-boundaries)
- 학생·플래너 데이터 의미: [Data Bucket Separation](decisions/data-bucket-separation)
- 학생 메타데이터 변경: [Generated Student Metadata](decisions/generated-student-metadata)
- 학생 메타데이터 배포·다운로드: [Student Metadata Delivery](flows/student-metadata-delivery)
- 학생 스캔 변경: [Student Scan Flow](flows/student-scan)
- 아이템·장비 스캔 변경: [Inventory Scan Flow](flows/inventory-scan)
- 대형 파일 리팩토링: [Large Module Change Safety](gotchas/large-module-change-safety)

## 유지 원칙

새 페이지는 설계 결정, 교차 파일 흐름, 불변식, 재발 가능한 장애 교훈을 남길 때만
추가합니다. 현재 코드에서 바로 읽을 수 있는 함수 목록, 일회성 작업 메모, TODO는
Almanac에 넣지 않습니다. 동작 명세와 운영 절차는 `docs/`에 유지합니다.
