# 필요 재화 섹션 연결

```mermaid
flowchart TD
    SCOPE[resourceScopeSection]
    SEARCH[resourceSearchSection]
    FILTER[filterDialog]

    SCOPE -->|검색| SEARCH
    SEARCH -->|범위| SCOPE
    SEARCH -->|필터| FILTER
    FILTER -->|적용 또는 닫기| SEARCH
    SEARCH -->|선택한 학생 추가| SCOPE
```
