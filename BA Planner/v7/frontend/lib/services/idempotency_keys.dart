// 앱 공용 idempotency key 생성기(tidy2, FE9-b1 발견 4).
//
// key 모양은 tidy1 · fb10b · FE9-b1과 같은 `<prefix>-<µs>-<순번>`이다(백엔드는 key를 불투명 문자열로 본다). 전에는 순번이
// 화면 State · 컨트롤러 인스턴스마다 따로였고(tidy1), 전술 컨트롤러만 프로세스 전체 static이었다(FE9-b1). 같은 µs 시계
// (고정 시계 · 빠른 재생성)를 쓰는 두 인스턴스가 같은 key를 만들 수 있어(FE9-b1 테스트로 재현) 순번을 여기 하나로 모았다.
// 같은 프로세스 안에서는 시각이 같아도 key가 다르다.
//
// 같은 요청을 다시 보낼 때(답을 못 받은 재시도) 같은 key를 쓰는 일은 호출하는 쪽이 key를 들고 있다가 다시 쓴다.

int _sequence = 0;

/// 다음 순번(프로세스 전체에서 1부터 하나씩 오른다).
int nextIdempotencySequence() => ++_sequence;

/// 새 key `<prefix>-<now의 µs>-<순번>`. [now]가 없으면 기기 시계다(화면 · 컨트롤러가 주입한 시계를 넘긴다).
String newIdempotencyKey(String prefix, {DateTime? now}) =>
    '$prefix-${(now ?? DateTime.now()).microsecondsSinceEpoch}-'
    '${nextIdempotencySequence()}';
