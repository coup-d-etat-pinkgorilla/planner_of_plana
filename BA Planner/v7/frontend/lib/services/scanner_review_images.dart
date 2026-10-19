// FB-10c: 학생 폴백 후보의 검토용 이미지(crop) 수명과 진단 제외 규칙.
// 기준: XB debug/xb_fb10c_crop_lifecycle_20261013/artifacts/CF-CONNECTION.md(backend 로그 2026-10-13 18:02).
// 백엔드는 weapon_level_fallback·weapon_star_fallback 행 `evidence.details`에 optional
// `crop_png_base64`·`crop_source`·`crop_width`·`crop_height`를 싣고, 승인·폐기·commit 성공·close 때 자기 사본에서
// `crop_png_base64`만 지운다. 이미 받은 후보·이벤트 사본은 프론트가 지운다. 크기·출처 같은 이미지가 아닌 값은 남긴다.
import 'dart:typed_data';

import 'scanner_service.dart';

/// 검토용 이미지 바이트를 담는 키인가. `crop_png_base64`와 같은 성격의 base64·이미지 키를 모두 포함한다.
/// `crop_source`·`crop_width`·`crop_height`처럼 이미지가 아닌 메타 키는 해당하지 않는다.
bool isScannerReviewImageKey(String key) {
  final name = key.toLowerCase();
  const exact = {'image', 'images', 'screenshot', 'png', 'jpeg', 'jpg'};
  const suffixes = [
    '_base64',
    '_b64',
    '_png',
    '_jpg',
    '_jpeg',
    '_webp',
    '_image',
    '_images',
    '_screenshot',
  ];
  return exact.contains(name) || suffixes.any(name.endsWith);
}

/// 이름과 관계없이 값 자체가 이미지인가(바이트 배열, data URI, PNG·JPEG·GIF·WEBP base64).
bool isScannerReviewImageValue(Object? value) {
  if (value is TypedData) return true;
  if (value is! String) return false;
  final text = value.trimLeft();
  return text.startsWith('data:image/') ||
      text.startsWith('iVBORw0KGgo') ||
      text.startsWith('/9j/') ||
      text.startsWith('R0lGOD') ||
      text.startsWith('UklGR');
}

/// [value] 안 어디에든 검토용 이미지가 남아 있는가.
bool scannerValueHasReviewImage(Object? value) {
  if (isScannerReviewImageValue(value)) return true;
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is String && isScannerReviewImageKey(entry.key as String)) {
        return true;
      }
      if (scannerValueHasReviewImage(entry.value)) return true;
    }
    return false;
  }
  if (value is List) return value.any(scannerValueHasReviewImage);
  return false;
}

/// [value]를 이미지 없이 새로 복사한다. 원래 Map·List는 바꾸지 않는다. 이미지 키와 이미지 값은 빠지고,
/// 나머지(숫자·문자열·크기·출처)는 그대로다. 최상위 값 자체가 이미지면 null.
Object? scannerValueWithoutReviewImages(Object? value) {
  if (isScannerReviewImageValue(value)) return null;
  if (value is Map) return scannerMapWithoutReviewImages(value);
  if (value is List) {
    return [
      for (final item in value)
        if (!isScannerReviewImageValue(item))
          scannerValueWithoutReviewImages(item),
    ];
  }
  return value;
}

Map<String, dynamic> scannerMapWithoutReviewImages(
  Map<dynamic, dynamic> value,
) => {
  for (final entry in value.entries)
    if (!(entry.key is String &&
            isScannerReviewImageKey(entry.key as String)) &&
        !isScannerReviewImageValue(entry.value))
      entry.key.toString(): scannerValueWithoutReviewImages(entry.value),
};

/// 이미지를 지운 후보 사본. 이미지가 없으면 같은 객체를 돌려준다.
ScannerCandidate scannerCandidateWithoutReviewImages(
  ScannerCandidate candidate,
) {
  final hasImage =
      scannerValueHasReviewImage(candidate.payload) ||
      scannerValueHasReviewImage(candidate.audit) ||
      candidate.evidence.any(
        (item) => scannerValueHasReviewImage(item.details),
      );
  if (!hasImage) return candidate;
  return ScannerCandidate(
    id: candidate.id,
    sessionId: candidate.sessionId,
    generation: candidate.generation,
    revision: candidate.revision,
    kind: candidate.kind,
    payload: scannerMapWithoutReviewImages(candidate.payload),
    evidence: [
      for (final item in candidate.evidence) _evidenceWithoutReviewImages(item),
    ],
    reviewRequired: candidate.reviewRequired,
    approved: candidate.approved,
    audit: [
      for (final item in candidate.audit) scannerMapWithoutReviewImages(item),
    ],
  );
}

ScannerFieldEvidence _evidenceWithoutReviewImages(ScannerFieldEvidence item) {
  final details = item.details;
  if (details == null || !scannerValueHasReviewImage(details)) return item;
  return ScannerFieldEvidence(
    field: item.field,
    status: item.status,
    source: item.source,
    confidence: item.confidence,
    note: item.note,
    details: Map<String, dynamic>.unmodifiable(
      scannerMapWithoutReviewImages(details),
    ),
  );
}

/// `candidate` 이벤트가 [candidateId] 후보를 실었으면 그 후보 사본에서만 이미지를 지운다. 다른 이벤트와 다른
/// 후보는 같은 객체 그대로다.
ScannerEvent scannerEventWithoutCandidateImages(
  ScannerEvent event,
  String candidateId,
) {
  final candidate = event.payload['candidate'];
  if (candidate is! Map ||
      candidate['candidate_id'] != candidateId ||
      !scannerValueHasReviewImage(candidate)) {
    return event;
  }
  return ScannerEvent(
    sessionId: event.sessionId,
    generation: event.generation,
    sequence: event.sequence,
    kind: event.kind,
    eventKind: event.eventKind,
    payload: {
      ...event.payload,
      'candidate': scannerMapWithoutReviewImages(candidate),
    },
  );
}

/// 최근 스캔 요약 안의 [candidateId] 후보 사본에서만 이미지를 지운다. 바뀐 것이 없으면 같은 객체다.
ScannerRecentSummary scannerRecentWithoutCandidateImages(
  ScannerRecentSummary summary,
  String candidateId,
) {
  final candidates = [
    for (final candidate in summary.candidates)
      candidate.id == candidateId
          ? scannerCandidateWithoutReviewImages(candidate)
          : candidate,
  ];
  var changed = false;
  for (var index = 0; index < candidates.length; index += 1) {
    if (!identical(candidates[index], summary.candidates[index])) {
      changed = true;
    }
  }
  if (!changed) return summary;
  return ScannerRecentSummary(
    session: summary.session,
    targetId: summary.targetId,
    targetTitle: summary.targetTitle,
    outcome: summary.outcome,
    phase: summary.phase,
    diagnostic: summary.diagnostic,
    candidateCount: summary.candidateCount,
    reviewRequired: summary.reviewRequired,
    progressCurrent: summary.progressCurrent,
    progressTotal: summary.progressTotal,
    messageKey: summary.messageKey,
    terminalError: summary.terminalError,
    candidates: candidates,
  );
}
