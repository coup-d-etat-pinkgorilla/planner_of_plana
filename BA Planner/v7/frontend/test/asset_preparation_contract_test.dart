// f2-dart: 계약 fixture(`contracts/fixtures/asset_preparation_v1.json`, 합성 24 cases)와 schema enum을 Dart 엄격
// DTO로 왕복한다. 유효한 메시지는 DTO → wire가 원문과 같아야 하고(null 수는 null 그대로), 무효 메시지는 거부한다.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

/// 유효한 메시지의 payload를 DTO로 읽고 다시 wire로 쓴다.
Object? _roundTrip(Map<String, dynamic> message) {
  final method = message['method'] as String;
  final payload = message['payload'];
  switch (message['type']) {
    case 'request':
      validateAssetPrepareRequestPayload(method, payload);
      return switch (method) {
        assetPrepareGameDirSetMethod => AssetGameDirRequest.fromWire(
          payload,
        ).toWire(),
        assetPrepareCancelMethod || assetPrepareSnapshotMethod =>
          AssetPrepareJobRef.fromWire(payload).toWire(),
        _ => <String, dynamic>{},
      };
    case 'event':
      return AssetPrepareEvent.fromWire(payload).toWire();
    default:
      if (isValidAssetPrepareErrorPayload(payload)) return payload;
      final parsed = parseAssetPrepareSuccessPayload(method, payload);
      return switch (parsed) {
        AssetPrepareStatus value => value.toWire(),
        AssetPrepareJobRef value => value.toWire(),
        AssetPrepareCancelResult value => value.toWire(),
        AssetPrepareJob value => {'job': value.toWire()},
        _ => throw StateError('unexpected $parsed'),
      };
  }
}

Set<String> _enum(Map<String, dynamic> node) =>
    (node['enum'] as List).whereType<String>().toSet();

void main() {
  final fixture = _json('../contracts/fixtures/asset_preparation_v1.json');
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();
  final schema = _json('../contracts/asset-preparation-v1.schema.json');
  final defs = schema[r'$defs'] as Map<String, dynamic>;

  test(
    'shared fixture has 24 synthetic cases and the strict validator agrees',
    () {
      expect(cases, hasLength(24));
      expect(cases.map((item) => item['id']).toSet(), hasLength(24));
      for (final item in cases) {
        expect(
          isValidAssetPreparationProtocolMessage(item['message']),
          item['valid'],
          reason: item['id'] as String,
        );
      }
      expect(cases.where((item) => item['valid'] == false), hasLength(5));
    },
  );

  test('valid fixture payloads round-trip through the DTOs unchanged', () {
    for (final item in cases.where((item) => item['valid'] == true)) {
      final message = _copy(item['message']);
      expect(
        _roundTrip(message),
        message['payload'],
        reason: item['id'] as String,
      );
    }
  });

  test('nullable counts stay null and unit stays bundles', () {
    final status = AssetPrepareStatus.fromWire(
      cases.firstWhere(
        (item) => item['id'] == 'assets.prepare.status-response',
      )['message']['payload'],
    );
    expect(status.cache.state, AssetCacheState.missing);
    expect(status.cache.failed, isNull);
    expect(status.cache.icons, 0);
    expect(status.job, isNull);
    expect(status.lastResult, isNull);
    expect(status.metadata.steamMatchesSnapshot, isNull);
    expect(status.gameDir.source, AssetGameDirSource.auto);
    expect(status.gameDir.reason, isNull);

    final first = AssetPrepareEvent.fromWire(
      cases.firstWhere((item) => item['id'] == 'event-0')['message']['payload'],
    );
    expect(first.kind, AssetPrepareEventKind.progress);
    expect(first.job.stage, AssetPrepareStage.validating);
    expect(first.job.total, isNull);
    expect(first.job.created, isNull);
    expect(first.job.reused, isNull);
    expect(first.job.failed, isNull);
    expect(first.job.available, 0);
    expect(first.toWire()['total'], isNull);
    expect(first.toWire()['unit'], 'bundles');

    final sprites = AssetPrepareEvent.fromWire(
      cases.firstWhere((item) => item['id'] == 'event-3')['message']['payload'],
    );
    expect(sprites.job.stage, AssetPrepareStage.sprites);
    expect(sprites.job.done, 1);
    expect(sprites.job.total, isNull);

    final terminal = AssetPrepareEvent.fromWire(
      cases.firstWhere((item) => item['id'] == 'event-5')['message']['payload'],
    );
    expect(terminal.isTerminal, isTrue);
    expect(terminal.job.state, AssetPrepareJobState.succeeded);
    expect(terminal.job.created, 16);
    expect(terminal.job.reused, 0);
    expect(terminal.job.failed, 0);

    final cancel = AssetPrepareCancelResult.fromWire(
      cases.firstWhere(
        (item) => item['id'] == 'cancel-response',
      )['message']['payload'],
    );
    expect(cancel.cancelRequested, isFalse);
  });

  test('Dart enums match the schema enums exactly', () {
    final error = defs['error']['properties']['error']['properties'] as Map;
    expect(
      AssetPrepareErrorCode.values.map((item) => item.wireName).toSet(),
      _enum(error['code'] as Map<String, dynamic>),
    );
    expect(
      assetPrepareErrorWireCodes,
      _enum(error['code'] as Map<String, dynamic>),
    );
    expect(
      AssetGameDirReason.values.map((item) => item.wireName).toSet(),
      _enum(defs['game']['properties']['reason'] as Map<String, dynamic>),
    );
    expect(
      AssetGameDirSource.values.map((item) => item.wireName).toSet(),
      _enum(defs['game']['properties']['source'] as Map<String, dynamic>),
    );
    expect(
      AssetCacheState.values.map((item) => item.wireName).toSet(),
      _enum(defs['cache']['properties']['state'] as Map<String, dynamic>),
    );
    final job = defs['job']['properties'] as Map<String, dynamic>;
    expect(
      AssetPrepareJobState.values.map((item) => item.wireName).toSet(),
      _enum(job['state'] as Map<String, dynamic>),
    );
    expect(
      AssetPrepareStage.values.map((item) => item.wireName).toSet(),
      _enum(job['stage'] as Map<String, dynamic>),
    );
    expect(
      AssetPrepareReasonCode.values.map((item) => item.wireName).toSet(),
      _enum(job['reason_codes']['items'] as Map<String, dynamic>),
    );
    expect(
      AssetPrepareJobState.values
          .where((item) => item.isTerminal)
          .map((item) => item.wireName),
      ['succeeded', 'partial', 'failed', 'cancelled'],
    );
  });

  group('strict rejection beyond the fixture', () {
    Map<String, dynamic> message(String id) =>
        _copy(cases.firstWhere((item) => item['id'] == id)['message']);

    void rejects(String label, Map<String, dynamic> value) => expect(
      isValidAssetPreparationProtocolMessage(value),
      isFalse,
      reason: label,
    );

    test(
      'requests reject unknown keys, boolean or zero generation and bad paths',
      () {
        rejects(
          'status extra',
          message('assets.prepare.status-request')..['payload'] = {'x': 1},
        );
        rejects(
          'snapshot bool',
          message('snapshot-request')..['payload']['generation'] = true,
        );
        rejects(
          'snapshot zero',
          message('snapshot-request')..['payload']['generation'] = 0,
        );
        rejects(
          'snapshot empty id',
          message('snapshot-request')..['payload']['job_id'] = '',
        );
        rejects(
          'cancel extra',
          message('cancel-request')..['payload']['extra'] = 1,
        );
        rejects(
          'set missing path',
          message('assets.prepare.game_dir.set-request')
            ..['payload'] = <String, dynamic>{},
        );
        rejects(
          'set empty path',
          message('assets.prepare.game_dir.set-request')
            ..['payload']['path'] = '',
        );
        rejects(
          'unknown method',
          message('assets.prepare.start-request')
            ..['method'] = 'assets.prepare.restart',
        );
        rejects(
          'envelope extra',
          message('assets.prepare.start-request')..['extra'] = 1,
        );
        rejects(
          'protocol 2',
          message('assets.prepare.start-request')..['protocol'] = 2,
        );

        expect(() => AssetGameDirRequest(''), throwsFormatException);
        expect(() => AssetGameDirRequest('   '), throwsFormatException);
        expect(() => AssetGameDirRequest('C:/a\u0000b'), throwsFormatException);
        expect(AssetGameDirRequest(null).toWire(), {'path': null});
        expect(
          () => AssetPrepareJobRef(jobId: 'a', generation: 0),
          throwsFormatException,
        );
        expect(
          () => AssetPrepareJobRef(jobId: '', generation: 1),
          throwsFormatException,
        );
        expect(
          () => validateAssetPrepareRequestPayload(assetPrepareCancelMethod, {
            'job_id': 'a',
            'generation': true,
          }),
          throwsFormatException,
        );
      },
    );

    test(
      'responses reject unknown keys, bad enums and non-null JP freshness',
      () {
        rejects(
          'status extra',
          message('assets.prepare.status-response')..['payload']['extra'] = 1,
        );
        rejects(
          'jp required',
          message('assets.prepare.status-response')
            ..['payload']['metadata']['jp_update_required'] = false,
        );
        rejects(
          'cache failed negative',
          message('assets.prepare.status-response')
            ..['payload']['cache']['failed'] = -1,
        );
        rejects(
          'cache state',
          message('assets.prepare.status-response')
            ..['payload']['cache']['state'] = 'done',
        );
        rejects(
          'game reason',
          message('assets.prepare.status-response')
            ..['payload']['game_dir']['reason'] = 'steam_build_mismatch',
        );
        rejects(
          'catalog sha',
          message('assets.prepare.status-response')
            ..['payload']['game_dir']['catalog_sha256'] = 'ABC',
        );
        rejects(
          'data version',
          message('assets.prepare.status-response')
            ..['payload']['metadata']['data_version_id'] = 'kr-1',
        );
        rejects(
          'start extra',
          message('assets.prepare.start-response')
            ..['payload']['state'] = 'running',
        );
        rejects(
          'start bool generation',
          message('assets.prepare.start-response')
            ..['payload']['generation'] = true,
        );
        rejects(
          'cancel missing flag',
          message('cancel-response')..['payload'].remove('cancel_requested'),
        );
        rejects(
          'snapshot unit',
          message('snapshot-response')..['payload']['job']['unit'] = 'icons',
        );
        rejects(
          'snapshot duplicate reasons',
          message('snapshot-response')
            ..['payload']['job']['reason_codes'] = ['cancelled', 'cancelled'],
        );
        rejects(
          'error code',
          message('start-error-response')
            ..['payload']['error']['code'] = 'asset_prepare_cancelled',
        );
        rejects(
          'error details key',
          message('start-error-response')
            ..['payload']['error']['details'] = {'path': 'C:/x'},
        );
        rejects(
          'error details reason',
          message('start-error-response')
            ..['payload']['error']['details'] = {'reason': 'nope'},
        );
        rejects(
          'error without details',
          message('start-error-response')
            ..['payload']['error'].remove('details'),
        );
        expect(
          isValidAssetPreparationProtocolMessage(
            message('start-error-response')
              ..['payload']['error'] = {
                'code': 'invalid_game_dir',
                'message': 'game folder is invalid',
                'details': {'reason': 'bundle_revision_mismatch'},
              },
          ),
          isTrue,
        );
      },
    );

    test('events enforce progress and terminal pairs and sequence >= 1', () {
      rejects(
        'progress complete',
        message('event-1')..['payload']['stage'] = 'complete',
      );
      rejects(
        'progress terminal state',
        message('event-1')..['payload']['state'] = 'succeeded',
      );
      rejects(
        'progress sequence 0',
        message('event-0')..['payload']['sequence'] = 0,
      );
      rejects(
        'terminal stage',
        message('event-5')..['payload']['stage'] = 'fonts',
      );
      rejects('event extra', message('event-5')..['payload']['extra'] = 1);
      rejects(
        'event kind',
        message('event-5')..['payload']['event_kind'] = 'snapshot',
      );
      rejects('event id key', message('event-5')..['id'] = 'r');
      rejects(
        'event method',
        message('event-5')..['method'] = 'scanner.session.event',
      );
      expect(
        isValidAssetPreparationProtocolMessage(
          message('event-2')..['payload']['state'] = 'cancelling',
        ),
        isTrue,
      );
    });
  });
}
