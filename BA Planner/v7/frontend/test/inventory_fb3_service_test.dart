// fb3-dart: FB-3 카탈로그 메타·획득처 strict DTO·Mock 획득처·Mock 재화 수동 저장 guard.
//
// 기준: CF 로그 10-11 00:02 정확 Dart 목록, 00:11 날짜 경계, 02:09 `currency_read_only`.
// 공유 fixture 판정은 planning_protocol_contract_test.dart가, 실제 client 왕복은
// planning_protocol_client_test.dart가 본다. 여기서는 합성 경계값과 Mock 동작을 본다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';
const _emptyRevision =
    'd1d01c1803e0005ad126df3ba58dcda51a9f3d08582a32ef1ac7f21c938f85e6';

Map<String, dynamic> _method([Map<String, dynamic> changes = const {}]) => {
  'method_id': 'test-only-shop',
  'kind': 'shop',
  'label': 'TEST_ONLY synthetic method; no actual KR fact',
  'weekly_quantity': null,
  'selector_resource_keys': null,
  'source': {
    'server': 'KR',
    'reference': 'TEST_ONLY fixture, no observed acquisition source',
    'reviewed_at': '2026-10-10',
  },
  ...changes,
};

Map<String, dynamic> _result(List<Object?> methods) => {
  'resource_key': 'Item_Icon_ExpItem_0',
  'methods': methods,
  'acquisition_revision': _emptyRevision,
};

Map<String, dynamic> _source(String reviewedAt, {String server = 'KR'}) => {
  'server': server,
  'reference': 'TEST_ONLY',
  'reviewed_at': reviewedAt,
};

Map<String, dynamic> _catalogRow([Map<String, dynamic> changes = const {}]) => {
  'resource_key': 'Item_Icon_SkillBook_Gehenna_0',
  'item_id': 'Item_Icon_SkillBook_Gehenna_0',
  'display_name': 'Gehenna Note T1',
  'category': 'tech_notes',
  'profile_id': 'tech_notes',
  'order_index': 0,
  'zero_fill_allowed': true,
  'school': 'Gehenna',
  'family': 'tech_notes',
  'tier': 1,
  ...changes,
};

Matcher _remoteError(String code, {String? reason}) => isA<BackendRemoteException>()
    .having((error) => error.code, 'code', code)
    .having(
      (error) => error.details?['reason'],
      'details.reason',
      reason,
    );

class _NoAcquisitionService implements AppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 실제 카탈로그처럼 비의서(정규 `Item_Icon_SkillBook_Ultimate`)가 있는 Mock(legacy 별칭 질의 확인용).
class _UltimateCatalogMock extends MockAppService {
  @override
  Future<InventoryCatalogResult> listInventoryItems() async {
    final base = await super.listInventoryItems();
    return InventoryCatalogResult(
      catalogRevision: base.catalogRevision,
      items: [
        ...base.items,
        const InventoryCatalogEntry(
          resourceKey: 'Item_Icon_SkillBook_Ultimate',
          itemId: 'Item_Icon_SkillBook_Ultimate',
          displayName: '비의서',
          category: 'tech_notes',
          profileId: 'tech_notes',
          orderIndex: 44,
          zeroFillAllowed: true,
          school: null,
          family: null,
          tier: null,
        ),
      ],
    );
  }
}

/// 재화가 저장된 계정(스캔·이전 저장으로 생긴 상태를 그대로 seed한다).
MockAppService _seededMock({
  required List<Map<String, dynamic>> entries,
  required DateTime Function() clock,
}) => MockAppService(
  historyClock: clock,
  repositoryStates: {
    _profileId: {
      'profile_id': _profileId,
      'revision': 0,
      'students': <dynamic>[],
      'inventory': {'version': 1, 'entries': entries},
      'goals': {'version': 1, 'goals': <dynamic>[]},
    },
  },
);

const _seedEntries = [
  {'key': 'credits', 'item_id': null, 'quantity': '1000', 'name': '크레딧'},
  {
    'key': 'Item_Icon_SecretStone',
    'item_id': 'Item_Icon_SecretStone',
    'quantity': null,
  },
  {
    'key': 'Item_Icon_ExpItem_0',
    'item_id': 'Item_Icon_ExpItem_0',
    'quantity': '3',
  },
];

List<Map<String, dynamic>> _seedCopy() => [
  for (final entry in _seedEntries) Map<String, dynamic>.from(entry),
];

void main() {
  group('FB-3 catalog metadata DTO', () {
    test('school family tier are required nullable exact metadata', () {
      final entry = InventoryCatalogEntry.fromWire(_catalogRow());
      expect(entry.school, 'Gehenna');
      expect(entry.family, 'tech_notes');
      expect(entry.tier, 1);
      expect(entry.isReadOnlyCurrency, isFalse);
      for (final accepted in <Map<String, dynamic>>[
        {'school': null, 'family': null, 'tier': null},
        {'school': '', 'family': '  raw  ', 'tier': 11},
        {'school': 'Future 🧪', 'family': 'oopart:Nebra', 'tier': 4},
      ]) {
        expect(
          () => InventoryCatalogEntry.fromWire(_catalogRow(accepted)),
          returnsNormally,
          reason: '$accepted',
        );
      }
      for (final rejected in <Map<String, dynamic>>[
        {'tier': true},
        {'tier': 1.0},
        {'tier': '1'},
        {'tier': 0},
        {'tier': -1},
        {'school': 1},
        {'family': false},
        {'school': '\ud800'},
        {'family': 'a\udc00'},
        {'school': 'end\ud83e'},
        {'future_metadata': null},
      ]) {
        expect(
          () => InventoryCatalogEntry.fromWire(_catalogRow(rejected)),
          throwsFormatException,
          reason: '$rejected',
        );
      }
      for (final missing in const ['school', 'family', 'tier']) {
        expect(
          () => InventoryCatalogEntry.fromWire(_catalogRow()..remove(missing)),
          throwsFormatException,
          reason: 'missing $missing',
        );
      }
    });

    test('scalar Unicode check accepts pairs and rejects isolated halves', () {
      expect(isUnicodeScalarString(''), isTrue);
      expect(isUnicodeScalarString('가 😀'), isTrue);
      expect(isUnicodeScalarString('😀'), isTrue);
      expect(isUnicodeScalarString('\ud800'), isFalse);
      expect(isUnicodeScalarString('\ude00x'), isFalse);
      expect(isUnicodeScalarString('x\ud83d'), isFalse);
    });
  });

  group('FB-3 resource acquisition strict DTO', () {
    test('quantity is a canonical integer string or null, never coerced', () {
      String? quantity(Object? value) => ResourceAcquisitionResult.fromWire(
        _result([
          _method({'weekly_quantity': value}),
        ]),
      ).methods.single.weeklyQuantity;
      expect(quantity(null), isNull);
      expect(quantity('0'), '0');
      expect(quantity('12'), '12');
      expect(quantity('9007199254740993'), '9007199254740993');
      expect(quantity('1' * 1024), '1' * 1024);
      for (final invalid in <Object>[
        0,
        12,
        1.0,
        true,
        '',
        '01',
        '-1',
        '+1',
        '1.0',
        '1e3',
        ' 1',
        '1 ',
        '1\n',
        '1' * 1025,
      ]) {
        expect(
          () => quantity(invalid),
          throwsFormatException,
          reason: 'weekly_quantity ${invalid.runtimeType} $invalid',
        );
      }
    });

    test('selector keys distinguish null from empty and keep order', () {
      List<String>? selectors(Object? value) =>
          ResourceAcquisitionResult.fromWire(
            _result([
              _method({'selector_resource_keys': value}),
            ]),
          ).methods.single.selectorResourceKeys;
      expect(selectors(null), isNull);
      expect(selectors(<Object>[]), isEmpty);
      expect(selectors(<Object>[]), isNotNull);
      expect(selectors(['b', 'a', '가']), ['b', 'a', '가']);
      for (final invalid in <Object>[
        false,
        'a',
        [1],
        ['a', 'a'],
        [''],
        ['\ud800'],
        ['가' * 342],
      ]) {
        expect(
          () => selectors(invalid),
          throwsFormatException,
          reason: 'selector $invalid',
        );
      }
      final keys = selectors(['a'])!;
      expect(() => keys.add('b'), throwsUnsupportedError);
    });

    test('method token, kind, label and duplicates use whole-string checks', () {
      ResourceAcquisitionResult parse(List<Object?> methods) =>
          ResourceAcquisitionResult.fromWire(_result(methods));
      for (final id in ['a', '0.x_y-z', 'a' * 128]) {
        expect(
          parse([
            _method({'method_id': id}),
          ]).methods.single.methodId,
          id,
        );
      }
      for (final id in <Object>[
        '',
        'Shop',
        '-shop',
        '.shop',
        'shop\n',
        'shop ',
        ' shop',
        'sh op',
        'a' * 129,
        1,
      ]) {
        expect(
          () => parse([
            _method({'method_id': id}),
          ]),
          throwsFormatException,
          reason: 'method_id $id',
        );
      }
      for (final kind in ResourceAcquisitionKind.values) {
        expect(
          parse([
            _method({'kind': kind.wireName}),
          ]).methods.single.kind,
          kind,
        );
      }
      for (final kind in <Object?>['Stage', 'stage ', 'drop', null]) {
        expect(
          () => parse([
            _method({'kind': kind}),
          ]),
          throwsFormatException,
          reason: 'kind $kind',
        );
      }
      expect(
        parse([
          _method({'label': '${'가' * 341}a'}),
        ]).methods.single.label,
        hasLength(342),
      );
      for (final label in <Object>['', '\ud800', '가' * 342, 3]) {
        expect(
          () => parse([
            _method({'label': label}),
          ]),
          throwsFormatException,
          reason: 'label ${label.runtimeType}',
        );
      }
      expect(
        () => parse([
          _method(),
          _method({'kind': 'stage'}),
        ]),
        throwsFormatException,
        reason: 'duplicate method_id',
      );
      final two = parse([
        _method(),
        _method({'method_id': 'test-only-stage', 'kind': 'stage'}),
      ]);
      expect(two.methods.map((method) => method.methodId), [
        'test-only-shop',
        'test-only-stage',
      ]);
      expect(() => two.methods.clear(), throwsUnsupportedError);
      expect(
        () => parse([
          {..._method(), 'weekly': null},
        ]),
        throwsFormatException,
      );
    });

    test('source is KR with a real YYYY-MM-DD date in year 1..9999', () {
      String reviewed(String date) => ResourceAcquisitionResult.fromWire(
        _result([
          _method({'source': _source(date)}),
        ]),
      ).methods.single.source.reviewedAt;
      for (final date in ['0001-01-01', '2024-02-29', '9999-12-31']) {
        expect(reviewed(date), date);
      }
      for (final date in [
        '0000-01-01',
        '2026-02-30',
        '2023-02-29',
        '2026-13-01',
        '2026-00-10',
        '2026-01-00',
        '2026-1-01',
        '10000-01-01',
        ' 2026-01-01',
        '2026-01-01 ',
        '2026-01-01\n',
        '+2026-01-01',
        '2026-01-01T00:00:00',
        '2026-01-01Z',
        '20260101',
      ]) {
        expect(
          () => reviewed(date),
          throwsFormatException,
          reason: 'reviewed_at $date',
        );
        expect(isStrictCalendarDate(date), isFalse, reason: date);
      }
      for (final source in <Object?>[
        _source('2026-10-10', server: 'JP'),
        _source('2026-10-10', server: 'kr'),
        {..._source('2026-10-10'), 'review_status': 'unverified'},
        {'server': 'KR', 'reviewed_at': '2026-10-10'},
        null,
      ]) {
        expect(
          () => ResourceAcquisitionResult.fromWire(
            _result([
              _method({'source': source}),
            ]),
          ),
          throwsFormatException,
          reason: '$source',
        );
      }
    });

    test('result and query are exact objects with a lowercase revision', () {
      for (final revision in [
        _emptyRevision.toUpperCase(),
        _emptyRevision.substring(1),
        '${_emptyRevision}0',
        '${_emptyRevision.substring(1)}\n',
      ]) {
        expect(
          () => ResourceAcquisitionResult.fromWire({
            ..._result(const []),
            'acquisition_revision': revision,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => ResourceAcquisitionResult.fromWire({
          ..._result(const []),
          'weekly': null,
        }),
        throwsFormatException,
      );
      expect(
        () => ResourceAcquisitionResult.fromWire({
          ..._result(const []),
          'methods': null,
        }),
        throwsFormatException,
      );
      expect(
        ResourceAcquisitionQuery('Item_Icon_ExpItem_0').toWire(),
        {'resource_key': 'Item_Icon_ExpItem_0'},
      );
      for (final payload in <Object?>[
        null,
        <Object>[],
        <String, Object>{},
        {'resource_key': null},
        {'resource_key': 0},
        {'resource_key': ''},
        {'resource_key': 'credits', 'server': 'KR'},
        {'resource_key': '\ud800'},
        {'resource_key': '가' * 342},
      ]) {
        expect(
          () => ResourceAcquisitionQuery.fromWire(payload),
          throwsFormatException,
          reason: '$payload',
        );
      }
    });

    test('services without acquisition support throw instead of returning []', () {
      final service = _NoAcquisitionService();
      expect(
        () => service.getResourceAcquisition('Item_Icon_ExpItem_0'),
        throwsUnsupportedError,
      );
    });
  });

  group('Mock FB-3 catalog and acquisition', () {
    test('catalog keeps reviewed rows and appends read-only currencies', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final items = (await service.listInventoryItems()).items;
      expect(items.map((item) => item.resourceKey), [
        'Item_Icon_ExpItem_0',
        'Item_Icon_SkillBook_Gehenna_0',
        'Item_Icon_Material_Nebra_0',
        'credits',
        'Item_Icon_SecretStone',
      ]);
      expect(
        items.take(3).map((item) => (item.school, item.family, item.tier)),
        [
          (null, 'activity_report', 1),
          ('Gehenna', 'tech_notes', 1),
          (null, 'oopart:Nebra', 1),
        ],
      );
      final currencies = items.skip(3).toList();
      // 읽기 전용 재화 키 집합은 카탈로그의 currencies 행과 같다.
      expect(
        items.where((item) => item.isReadOnlyCurrency).toList(),
        items.where((item) => item.profileId == 'currencies').toList(),
      );
      expect(currencies.map((item) => item.itemId), [
        null,
        'Item_Icon_SecretStone',
      ]);
      expect(currencies.map((item) => item.profileId), [
        'currencies',
        'currencies',
      ]);
      expect(currencies.map((item) => item.orderIndex), [0, 1]);
      for (final currency in currencies) {
        expect(currency.zeroFillAllowed, isFalse);
        expect(currency.school, isNull);
        expect(currency.family, isNull);
        expect(currency.tier, isNull);
        expect(currency.isReadOnlyCurrency, isTrue);
      }
    });

    test('known keys return the authoritative empty table', () async {
      var clock = 0;
      final service = MockAppService(
        historyClock: () {
          clock++;
          return DateTime.utc(2026, 10, 11);
        },
      );
      addTearDown(service.dispose);
      final before = await service.loadRepositoryState(_profileId);
      for (final key in const [
        'Item_Icon_ExpItem_0',
        'credits',
        'Item_Icon_SecretStone',
      ]) {
        final result = await service.getResourceAcquisition(key);
        expect(result.resourceKey, key);
        expect(result.methods, isEmpty);
        expect(result.acquisitionRevision, _emptyRevision);
      }
      expect(mockEmptyResourceAcquisitionRevision, _emptyRevision);
      // 조회는 저장소·history·시각을 건드리지 않는다.
      final after = await service.loadRepositoryState(_profileId);
      expect(after.revision, before.revision);
      expect(clock, 0);
    });

    test('legacy alias query returns the canonical key', () async {
      final service = _UltimateCatalogMock();
      addTearDown(service.dispose);
      final result = await service.getResourceAcquisition(
        'Item_Icon_SkillBook_Ultimate_Piece',
      );
      expect(result.resourceKey, 'Item_Icon_SkillBook_Ultimate');
      expect(result.methods, isEmpty);
    });

    test('unknown, malformed and failed lookups stay distinct', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await expectLater(
        service.getResourceAcquisition('Item_Icon_SkillBook_Ultimate'),
        throwsA(_remoteError('resource_not_found')),
      );
      // 잘못된 질의는 Process와 같이 보내기 전 FormatException이다.
      for (final key in ['', '\ud800', '가' * 342]) {
        await expectLater(
          service.getResourceAcquisition(key),
          throwsFormatException,
          reason: 'length ${key.length}',
        );
      }
      // 표 실패보다 카탈로그 확인이 먼저다(백엔드 순서).
      service.failNextResourceAcquisition = true;
      await expectLater(
        service.getResourceAcquisition('Item_Icon_SkillBook_Ultimate'),
        throwsA(_remoteError('resource_not_found')),
      );
      await expectLater(
        service.getResourceAcquisition('Item_Icon_ExpItem_0'),
        throwsA(_remoteError('resource_acquisition_failed')),
      );
      expect(
        (await service.getResourceAcquisition('Item_Icon_ExpItem_0')).methods,
        isEmpty,
      );
    });
  });

  group('Mock manual inventory currency guard', () {
    late MockAppService service;
    var clock = 0;

    setUp(() {
      clock = 0;
      service = _seededMock(
        entries: _seedCopy(),
        clock: () {
          clock++;
          return DateTime.utc(2026, 10, 11, clock);
        },
      );
    });
    tearDown(() => service.dispose());

    Future<int> save(
      List<Map<String, dynamic>> entries,
      int revision,
      String key,
    ) => service.saveRepositoryInventory(
      _profileId,
      RepositoryInventoryState.fromEntries(entries),
      revision,
      key,
    );

    List<Map<String, dynamic>> changed(
      Map<String, dynamic>? Function(Map<String, dynamic> entry) change,
    ) => [
      for (final entry in _seedCopy())
        ?change(entry),
    ];

    test('presence and quantity changes are rejected before any write', () async {
      final before = await service.loadRepositoryState(_profileId);
      final cases = <String, List<Map<String, dynamic>>>{
        'credits quantity': changed(
          (entry) => entry['key'] == 'credits'
              ? {...entry, 'quantity': '999'}
              : entry,
        ),
        'credits removed': changed(
          (entry) => entry['key'] == 'credits' ? null : entry,
        ),
        'eligma null to zero': changed(
          (entry) => entry['key'] == 'Item_Icon_SecretStone'
              ? {...entry, 'quantity': '0'}
              : entry,
        ),
        'eligma removed': changed(
          (entry) => entry['key'] == 'Item_Icon_SecretStone' ? null : entry,
        ),
        'credits to unknown': changed(
          (entry) => entry['key'] == 'credits'
              ? {...entry, 'quantity': null}
              : entry,
        ),
      };
      for (final MapEntry(key: name, value: entries) in cases.entries) {
        await expectLater(
          save(entries, before.revision, 'currency-$name'),
          throwsA(
            _remoteError('invalid_payload', reason: 'currency_read_only'),
          ),
          reason: name,
        );
      }
      final after = await service.loadRepositoryState(_profileId);
      expect(after.revision, before.revision);
      expect(after.inventory.entries, before.inventory.entries);
      expect(clock, 0, reason: 'history clock is after the guard');
      // 거부는 캐시에 남지 않는다: 같은 key로 다시 보내도 같은 거부다.
      await expectLater(
        save(cases['credits quantity']!, before.revision, 'currency-credits quantity'),
        throwsA(_remoteError('invalid_payload', reason: 'currency_read_only')),
      );
    });

    test('adding an absent currency is rejected', () async {
      final empty = _seededMock(
        entries: [
          {'key': 'Item_Icon_ExpItem_0', 'quantity': '3'},
        ],
        clock: () => DateTime.utc(2026, 10, 11),
      );
      addTearDown(empty.dispose);
      final state = await empty.loadRepositoryState(_profileId);
      await expectLater(
        empty.saveRepositoryInventory(
          _profileId,
          RepositoryInventoryState.fromEntries([
            {'key': 'Item_Icon_ExpItem_0', 'quantity': '3'},
            {'key': 'credits', 'quantity': '0'},
          ]),
          state.revision,
          'add-credits',
        ),
        throwsA(_remoteError('invalid_payload', reason: 'currency_read_only')),
      );
    });

    test('materials save when whole currency entries are kept', () async {
      final before = await service.loadRepositoryState(_profileId);
      final next = changed(
        (entry) => entry['key'] == 'Item_Icon_ExpItem_0'
            ? {...entry, 'quantity': '4'}
            : entry,
      );
      final revision = await save(next, before.revision, 'material');
      expect(revision, before.revision + 1);
      expect(clock, 1);
      final after = await service.loadRepositoryState(_profileId);
      Map<String, dynamic> entry(String key) =>
          after.inventory.entries.singleWhere((item) => item['key'] == key);
      expect(entry('credits'), _seedEntries[0]);
      expect(entry('Item_Icon_SecretStone')['quantity'], isNull);
      expect(entry('Item_Icon_ExpItem_0')['quantity'], '4');

      // 캐시 재생이 guard보다 먼저다: 같은 key·같은 요청은 저장된 결과, 같은 key·다른 요청은 idempotency_conflict.
      expect(await save(next, before.revision, 'material'), revision);
      await expectLater(
        save(
          changed(
            (item) => item['key'] == 'credits'
                ? {...item, 'quantity': '1'}
                : item,
          ),
          before.revision,
          'material',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'idempotency_conflict',
          ),
        ),
      );
      // revision 확인도 guard보다 먼저다.
      await expectLater(
        save(
          changed(
            (item) => item['key'] == 'credits'
                ? {...item, 'quantity': '1'}
                : item,
          ),
          before.revision,
          'stale',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'revision_conflict',
          ),
        ),
      );
    });
  });
}
