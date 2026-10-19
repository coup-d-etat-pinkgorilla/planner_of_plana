// FB-10b 인벤토리 "확인 필요" 영속 표시(backend 로그 2026-10-12 08:11·09:10,
// `contracts/repository-inventory-review-v1.schema.json`, 결정 대장 FD-146).
//
// - 읽기 `repository.inventory.review.get`: 요청 exact `{profile_id}`, 응답 exact
//   `{version:1, profile_id, revision, needs_review_keys}`. 목록은 code point 순으로 정렬된 unique 정규 key이고,
//   목록에 없는 key는 표시가 없다(false). 수량 DTO(`RepositoryInventoryState`)·state·이력·스캐너 응답에는 끼우지 않는다.
// - 표시는 그 revision의 값이다. 수량 스냅숏과 revision이 다르면 둘 다 다시 읽는다(호출처 몫).
// - 저장된 표시 버전을 모르면 `migration_required`, 모양이 깨졌으면 `corrupt_data`가 그대로 온다(빈 목록으로 바꾸지 않는다).
// - 수동 저장 scope(`repository.inventory.update`의 optional `applied_resource_keys`)도 같은 key 규칙을 쓴다:
//   배열(null 금지)·빈 배열 허용·최대 4096·각 1..1024 UTF-8 바이트·별칭을 현재 key로 바꾼 뒤 중복 거부.
import 'dart:convert';

import 'repository_history_service.dart' show historyCanonicalResourceKey;

/// 확인 필요 key 목록·수동 scope의 최대 개수(schema `$defs/keys.maxItems`).
const repositoryInventoryReviewMaxKeys = 4096;

final _profileIdPattern = RegExp(r'^[0-9a-f]{24}$');

bool _exactKeys(Map<String, dynamic> value, Set<String> keys) =>
    value.length == keys.length && value.keys.toSet().containsAll(keys);

/// Python `sorted(str)`와 같은 code point 비교.
int _codePointCompare(String a, String b) {
  final left = a.runes.iterator;
  final right = b.runes.iterator;
  while (true) {
    final hasLeft = left.moveNext();
    final hasRight = right.moveNext();
    if (!hasLeft || !hasRight) return hasLeft ? 1 : (hasRight ? -1 : 0);
    if (left.current != right.current) return left.current - right.current;
  }
}

/// key 하나: 문자열, 짝 없는 surrogate 없음(UTF-8로 쓸 수 있음), 1..1024 UTF-8 바이트.
String _reviewKey(Object? value) {
  if (value is! String ||
      value.runes.any((rune) => rune >= 0xD800 && rune <= 0xDFFF)) {
    throw const FormatException('Review identity must be UTF-8 text');
  }
  final size = utf8.encode(value).length;
  if (size < 1 || size > 1024) {
    throw const FormatException('Review identity must be 1..1024 UTF-8 bytes');
  }
  return value;
}

/// 응답 `needs_review_keys` 검사: 정규 key만, code point 순 정렬, 중복 없음.
List<String> _responseKeys(Object? value) {
  if (value is! List || value.length > repositoryInventoryReviewMaxKeys) {
    throw const FormatException('Review keys must be a bounded array');
  }
  final keys = <String>[];
  for (final raw in value) {
    final key = _reviewKey(raw);
    if (historyCanonicalResourceKey(key) != key) {
      throw const FormatException('Review keys must be canonical identities');
    }
    if (keys.isNotEmpty && _codePointCompare(keys.last, key) >= 0) {
      throw const FormatException('Review keys must be sorted and unique');
    }
    keys.add(key);
  }
  return List.unmodifiable(keys);
}

/// 수동 저장 scope(`applied_resource_keys`)를 보낼 모양으로 바꾼다: 별칭 → 현재 key, 중복(별칭 포함)은
/// [FormatException], code point 순 정렬. [value]는 배열이어야 한다(null 금지).
List<String> repositoryInventoryAppliedKeys(Object? value) {
  if (value is! List || value.length > repositoryInventoryReviewMaxKeys) {
    throw const FormatException('applied_resource_keys must be a bounded array');
  }
  final keys = <String>{};
  for (final raw in value) {
    if (!keys.add(historyCanonicalResourceKey(_reviewKey(raw)))) {
      throw const FormatException('Duplicate canonical review identity');
    }
  }
  return List.unmodifiable(keys.toList()..sort(_codePointCompare));
}

/// `repository.inventory.review.get` 요청(exact `profile_id`).
class RepositoryInventoryReviewRequest {
  RepositoryInventoryReviewRequest(this.profileId) {
    if (!_profileIdPattern.hasMatch(profileId)) {
      throw const FormatException('Invalid inventory review profile_id');
    }
  }

  factory RepositoryInventoryReviewRequest.fromWire(Map<String, dynamic> value) {
    if (!_exactKeys(value, {'profile_id'}) || value['profile_id'] is! String) {
      throw const FormatException('Invalid inventory review request');
    }
    return RepositoryInventoryReviewRequest(value['profile_id'] as String);
  }

  final String profileId;

  Map<String, dynamic> toWire() => {'profile_id': profileId};
}

/// `repository.inventory.review.get` 응답. [revision]의 확인 필요 key 목록(sparse).
class RepositoryInventoryReview {
  RepositoryInventoryReview._(this.profileId, this.revision, this.needsReviewKeys)
    : _flagged = needsReviewKeys.toSet();

  factory RepositoryInventoryReview.fromWire(Map<String, dynamic> value) {
    final version = value['version'];
    final revision = value['revision'];
    final profileId = value['profile_id'];
    if (!_exactKeys(value, {
          'version',
          'profile_id',
          'revision',
          'needs_review_keys',
        }) ||
        version is! int ||
        version != 1 ||
        profileId is! String ||
        !_profileIdPattern.hasMatch(profileId) ||
        revision is! int ||
        revision < 0) {
      throw const FormatException('Invalid inventory review');
    }
    return RepositoryInventoryReview._(
      profileId,
      revision,
      _responseKeys(value['needs_review_keys']),
    );
  }

  /// 요청한 계정의 응답인지까지 본다.
  factory RepositoryInventoryReview.fromWireFor(
    String profileId,
    Map<String, dynamic> value,
  ) {
    final review = RepositoryInventoryReview.fromWire(value);
    if (review.profileId != profileId) {
      throw const FormatException('Inventory review belongs to another profile');
    }
    return review;
  }

  static const version = 1;

  final String profileId;
  final int revision;

  /// code point 순으로 정렬된 정규 key(수정 불가).
  final List<String> needsReviewKeys;
  final Set<String> _flagged;

  /// [key](별칭 포함)에 확인 필요 표시가 있는가. 목록에 없으면 false.
  bool needsReview(String key) =>
      _flagged.contains(historyCanonicalResourceKey(key));

  Map<String, dynamic> toWire() => {
    'version': version,
    'profile_id': profileId,
    'revision': revision,
    'needs_review_keys': needsReviewKeys,
  };
}

/// 확인 필요 표시 읽기. [RepositoryService]와 따로 두어 기존 대역의 소스 호환을 지킨다.
abstract interface class RepositoryInventoryReviewService {
  /// 그 계정의 확인 필요 표시. `profile_not_found`·`migration_required`·`corrupt_data`는 오류로 그대로 던진다.
  Future<RepositoryInventoryReview> loadRepositoryInventoryReview(
    String profileId,
  );
}
