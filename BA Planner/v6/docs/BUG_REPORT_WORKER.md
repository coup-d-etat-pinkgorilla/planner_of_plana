# Bug Report Worker

`bug-report-worker/`는 데스크톱 앱에서 받은 오류 보고를 GitHub Issue로 생성하는
Cloudflare Worker입니다.

## API

`POST /report`에 `Content-Type: application/json`으로 다음 JSON을 보냅니다.

```json
{
  "title": "오류 요약",
  "body": "오류 설명"
}
```

입력 제한은 다음과 같습니다.

- 요청 전체: 최대 32 KiB
- `title`: 공백이 아닌 문자열, 최대 200자
- `body`: 공백이 아닌 문자열, 최대 20,000자
- `title`, `body` 외 필드: 허용하지 않음

성공하면 `201`과 생성된 Issue 정보 및 request ID를 반환합니다.

```json
{
  "issueUrl": "https://github.com/owner/repository/issues/123",
  "issueNumber": 123,
  "requestId": "00000000-0000-0000-0000-000000000000"
}
```

오류 응답은 안정적인 코드와 request ID를 사용합니다.

```json
{
  "error": {
    "code": "INVALID_PAYLOAD",
    "message": "title and body must be the only fields and must meet length limits"
  },
  "requestId": "00000000-0000-0000-0000-000000000000"
}
```

웹 클라이언트를 지원하지 않으므로 CORS 헤더는 제공하지 않습니다. 지원하지 않는
메서드는 `405`, 잘못된 Content-Type은 `415`, 과도한 요청은 `429`를 반환합니다.

## Rate limit

`CF-Connecting-IP`를 SHA-256으로 변환한 식별자마다 별도의 SQLite-backed Durable
Object를 사용합니다. IP 원문은 저장하거나 로그에 기록하지 않습니다. 각 Object에는
최근 요청 시각만 저장합니다.

- 이동하는 10분 구간에 최대 3건
- 이동하는 24시간 구간에 최대 10건
- 초과 응답: `429 RATE_LIMITED`와 `Retry-After` 헤더

GitHub API를 호출하기 직전에 제한을 확인하고 성공적으로 허용된 시도를 기록합니다.

## 설정

공개 설정은 `bug-report-worker/wrangler.jsonc`의 `vars`에서 관리합니다.

- `GITHUB_OWNER`: Issue 대상 소유자
- `GITHUB_REPO`: Issue 대상 저장소
- `REPORTING_ENABLED`: `true`일 때만 신고 허용; 긴급 중단 시 `false`

GitHub 토큰은 설정 파일이나 소스 코드에 기록하지 않고 Cloudflare Secret으로
등록합니다.

```powershell
cd bug-report-worker
npx wrangler secret put GITHUB_TOKEN
```

로컬 개발용 Secret은 Git에 커밋하지 않는 `.dev.vars`에서 관리합니다. 토큰에는 대상
저장소의 Issues 쓰기에 필요한 최소 권한만 부여합니다.

## 로그 정책

Worker 로그에는 request ID, HTTP 상태 코드, 처리 시간만 기록합니다. 제목, 본문,
GitHub 토큰, IP 주소는 기록하지 않습니다. GitHub의 상세 오류도 클라이언트에 전달하지
않습니다.

## 검증

```powershell
cd bug-report-worker
npm run cf-typegen
npm test -- --run
npx tsc --noEmit
npx wrangler deploy --dry-run
```
