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

## 데스크톱 앱

Qt 앱의 `설정` 탭에서 `문제 신고`를 열 수 있습니다. 사용자는 제목과 설명을 입력하고,
앱 버전·운영체제·Python 버전·활성 프로필·최근 오류 요약으로 구성된 진단정보를 전송
전에 수정하거나 삭제할 수 있습니다. 활성 프로필명, Windows 사용자 경로, 이메일,
인증 헤더와 알려진 토큰 형식은 `core/bug_report.py`에서 마스킹한 뒤 전송합니다.

HTTP 전송은 UI 스레드 밖에서 실행합니다. 클라이언트는
`User-Agent: BA-Planner/<version>`을 보내며, `429`의 `Retry-After`와 Worker의
request ID를 사용자 오류 메시지에 반영합니다. 성공하면 Issue 번호를 표시하고 생성된
URL을 브라우저에서 열 수 있습니다.

기본 endpoint는 production Worker입니다. 개발자가 staging Worker를 시험할 때는 앱을
시작하기 전에 다음 환경 변수를 설정합니다.

```powershell
$env:BA_PLANNER_BUG_REPORT_URL = "https://bug-report-worker-staging.pyrosoda.workers.dev/report"
```

## Staging

`wrangler.jsonc`의 `staging` 환경은 `bug-report-worker-staging`이라는 별도 Worker와
별도 Durable Object binding을 사용합니다. staging GitHub 대상이 확정되기 전에는 실제
Issue가 생성되지 않도록 `REPORTING_ENABLED=false`가 기본값입니다.

- URL: `https://bug-report-worker-staging.pyrosoda.workers.dev`
- 초기 배포 검증: `POST /report` → `503 REPORTING_DISABLED`

```powershell
cd bug-report-worker
npx wrangler deploy --env staging --dry-run
```

staging을 실제 Issue 생성에 사용하려면 대상 저장소를 먼저 확정하고 staging 전용
Secret을 별도로 등록한 뒤 `REPORTING_ENABLED`를 `true`로 변경합니다.

```powershell
npx wrangler secret put GITHUB_TOKEN --env staging
```

## 검증

```powershell
cd bug-report-worker
npm run cf-typegen
npm test -- --run
npx tsc --noEmit
npx wrangler deploy --dry-run
```
