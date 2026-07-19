# IPC contracts

Flutter와 Python 백엔드는 제품 버전과 별개인 protocol version을 사용합니다.
초기 protocol은 `1`이며 모든 메시지는 `protocol`, `id`, `type`, `method`,
`payload` 공통 필드를 갖습니다.

현재는 공통 envelope만 확정했습니다. scanner와 repository 이전 전에 method별
request/response/event schema, 오류 코드, cancellation, session generation을
별도 schema와 양쪽 contract test로 고정합니다.

