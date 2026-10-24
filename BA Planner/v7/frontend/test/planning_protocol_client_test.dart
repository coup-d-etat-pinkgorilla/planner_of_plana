import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup probe keeps the process connecting until it responds',
    () async {
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(
        () async => process,
        waitForStartupProbe: true,
      );

      final start = client.start();
      await Future<void>.delayed(Duration.zero);
      expect(client.connection.value, BackendConnection.connecting);
      final request = _decode(process.writes.single);
      expect(request['method'], 'repository.profile.list');

      process.respond(request, {
        'profiles': <Object>[],
        'selected_profile_id': null,
      });
      await start;

      expect(client.connection.value, BackendConnection.connected);
      await client.dispose();
    },
  );

  test('matches multiple reversed responses by unique request id', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();

    final first = client.send('planning.student.get', {'student_id': 'ayane'});
    final second = client.send('planning.student.get', {'student_id': 'aru'});
    final requests = process.writes.map(_decode).toList();

    process.respond(requests[1], {
      'student': {'student_id': 'aru'},
    });
    process.respond(requests[0], {
      'student': {'student_id': 'ayane'},
    });

    expect((await first)['student']['student_id'], 'ayane');
    expect((await second)['student']['student_id'], 'aru');
    expect(requests[0]['id'], isNot(requests[1]['id']));
    await client.dispose();
  });

  test(
    'student catalog response is typed and malformed entries fail closed',
    () async {
      final process = FakeBackendProcess();
      final service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      await service.reconnect();
      final result = service.listStudents();
      final request = process.writes
          .map(_decode)
          .singleWhere(
            (message) => message['method'] == 'planning.student.catalog',
          );
      process.respond(request, {
        'students': [
          {
            'student_id': 'aru',
            'display_name': 'Aru',
            'template_name': 'aru.png',
            'group': 'aru',
            'variant': null,
            'school': 'Gehenna',
            'rarity': '3',
            'attack_type': 'Explosive',
            'defense_type': 'Light',
            'combat_class': 'Striker',
            'role': 'Dealer',
            'position': 'Back',
            'equipment_slot_1': 'Hat',
            'equipment_slot_2': 'Hairpin',
            'equipment_slot_3': 'Watch',
            'jp_only': false,
            'has_favorite_item': true,
            'search_tags': ['aru'],
            'kr_search_tags': <String>[],
          },
        ],
        'sort': 'display_name_then_id',
      });
      final aru = (await result).single;
      expect(aru.studentId, 'aru');
      expect(aru.hasFavoriteItem, isTrue);
      expect(aru.metadata['has_favorite_item'], isTrue);
      await service.dispose();

      final malformedProcess = FakeBackendProcess();
      final malformedClient = PlanningProtocolClient(
        () async => malformedProcess,
      );
      await malformedClient.start();
      final malformed = malformedClient.send('planning.student.catalog', {});
      final malformedRequest = _decode(malformedProcess.writes.single);
      malformedProcess.respond(malformedRequest, {
        'students': <dynamic>[],
        'sort': 'wrong',
      });
      await expectLater(malformed, throwsA(isA<BackendProtocolException>()));
      await malformedClient.dispose();
    },
  );

  test(
    'inventory catalog, shortages, and save use typed wire boundaries',
    () async {
      final process = FakeBackendProcess();
      final service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      await service.reconnect();
      final catalogFuture = service.listInventoryItems();
      var request = _decode(process.writes.last);
      process.respond(request, {
        'items': [
          {
            'resource_key': 'item',
            'item_id': 'item',
            'display_name': 'Item',
            'category': 'material',
            'profile_id': 'materials',
            'order_index': 0,
            'zero_fill_allowed': true,
            'school': null,
            'family': 'material',
            'tier': 1,
          },
        ],
        'sort': 'profile_order',
        'catalog_revision':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      });
      final catalog = await catalogFuture;
      expect(catalog.items.single.resourceKey, 'item');
      expect(catalog.items.single.school, isNull);
      expect(catalog.items.single.family, 'material');
      expect(catalog.items.single.tier, 1);
      expect(catalog.catalogRevision, hasLength(64));

      final shortageFuture = service.calculateShortages(
        currentStudents: const [],
        plan: const {'version': 1, 'goals': []},
        inventory: const {'version': 1, 'entries': []},
      );
      request = _decode(process.writes.last);
      process.respond(request, {
        'rows': [
          {
            'resource_key': 'item',
            'item_id': 'item',
            'display_name': 'Item',
            'category': 'material',
            'required': 3,
            'owned': 0,
            'shortage': 3,
            'affected_student_ids': ['aru'],
            'resolved': true,
          },
        ],
        'warnings': <String>[],
      });
      expect((await shortageFuture).rows.single.shortage, 3);

      final saveFuture = service.saveRepositoryInventory(
        '000000000000000000000000',
        RepositoryInventoryState.fromEntries([
          {'key': 'item', 'item_id': 'item', 'quantity': '0'},
        ]),
        2,
        'save-inventory',
      );
      request = _decode(process.writes.last);
      expect(request['method'], 'repository.inventory.update');
      expect(
        request['payload']['inventory']['entries'].single['quantity'],
        '0',
      );
      process.respond(request, {'revision': 3});
      expect(await saveFuture, 3);
      await service.dispose();
    },
  );

  test('inventory snapshot preserves catalog revision and observed slot', () {
    final state = RepositoryInventoryState.fromWire({
      'version': 1,
      'catalog_revision':
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'entries': [
        {
          'key': 'item',
          'item_id': 'item',
          'quantity': '2',
          'index': 5,
          'profile_id': 'materials',
          'observed_slot': 17,
        },
      ],
    });
    expect(state.catalogRevision, hasLength(64));
    expect(state.entries.single['index'], 5);
    expect(state.entries.single['observed_slot'], 17);
    expect(state.toWire()['catalog_revision'], state.catalogRevision);
  });

  test(
    'times out and reports a late response id without reconnecting',
    () async {
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(
        () async => process,
        defaultTimeout: const Duration(milliseconds: 10),
      );
      final errors = <BackendProtocolException>[];
      final subscription = client.protocolErrors.listen(errors.add);
      await client.start();

      final result = client.send('planning.student.get', {
        'student_id': 'ayane',
      });
      final wireRequest = _decode(process.writes.single);
      await expectLater(result, throwsA(isA<TimeoutException>()));
      process.respond(wireRequest, {'student': null});
      await Future<void>.delayed(Duration.zero);

      expect(
        errors.single.message,
        contains('Unknown or duplicate response id'),
      );
      expect(client.connection.value, BackendConnection.connected);
      await subscription.cancel();
      await client.dispose();
    },
  );

  test('malformed JSON fails pending requests and disconnects', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final expectation = expectLater(
      result,
      throwsA(isA<BackendProtocolException>()),
    );

    process.stdout.add('{malformed');
    await expectation;
    expect(client.connection.value, BackendConnection.disconnected);
    await client.dispose();
  });

  test('response method mismatch is fatal to the connection', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final request = _decode(process.writes.single);

    process.respond(request, {
      'student': null,
    }, method: 'planning.plan.validate');

    await expectLater(result, throwsA(isA<BackendProtocolException>()));
    expect(client.connection.value, BackendConnection.disconnected);
    expect(process.terminated, isTrue);
    await client.dispose();
  });

  test('invalid structured error is fatal to the connection', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': ''});
    final request = _decode(process.writes.single);

    process.respond(request, {
      'error': {'code': 'calculation_failed', 'message': 'wrong method code'},
    });

    await expectLater(result, throwsA(isA<BackendProtocolException>()));
    expect(client.connection.value, BackendConnection.disconnected);
    await client.dispose();
  });

  test('valid method error stays request-scoped', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': ''});
    final request = _decode(process.writes.single);

    process.respond(request, {
      'error': {
        'code': 'invalid_payload',
        'message': 'student_id must be a non-empty string',
      },
    });

    await expectLater(
      result,
      throwsA(
        isA<BackendRemoteException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
    expect(client.connection.value, BackendConnection.connected);
    await client.dispose();
  });

  test('invalid success payload is fatal to the connection', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.plan.validate', {
      'plan': {'version': 1, 'goals': <Object>[]},
    });
    final request = _decode(process.writes.single);

    process.respond(request, {'valid': true});

    await expectLater(result, throwsA(isA<BackendProtocolException>()));
    expect(client.connection.value, BackendConnection.disconnected);
    await client.dispose();
  });

  test(
    'malformed repository success is fatal and restart remains available',
    () async {
      final first = FakeBackendProcess();
      final second = FakeBackendProcess();
      var starts = 0;
      final client = PlanningProtocolClient(
        () async => starts++ == 0 ? first : second,
      );
      await client.start();
      final result = client.send('repository.profile.list', {});
      final request = _decode(first.writes.single);
      first.respond(request, {'nonsense': true});
      await expectLater(result, throwsA(isA<BackendProtocolException>()));
      expect(client.connection.value, BackendConnection.disconnected);

      await client.restart();
      final recovered = client.send('repository.profile.list', {});
      final retried = _decode(second.writes.single);
      second.respond(retried, {
        'profiles': <Object>[],
        'selected_profile_id': null,
      });
      expect((await recovered)['profiles'], isEmpty);
      expect(client.connection.value, BackendConnection.connected);
      await client.dispose();
    },
  );

  test('stdin write failure disconnects and fails the request', () async {
    final process = FakeBackendProcess()..writeError = StateError('closed');
    final client = PlanningProtocolClient(() async => process);
    await client.start();

    await expectLater(
      client.send('planning.student.get', {'student_id': 'ayane'}),
      throwsA(isA<BackendDisconnectedException>()),
    );
    expect(client.connection.value, BackendConnection.disconnected);
    expect(process.terminated, isTrue);
    await client.dispose();
  });

  test(
    'unexpected exit fails pending requests and updates connection',
    () async {
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(() async => process);
      await client.start();
      final result = client.send('planning.student.get', {
        'student_id': 'ayane',
      });
      final expectation = expectLater(
        result,
        throwsA(isA<BackendDisconnectedException>()),
      );

      process.exit(17);
      await expectation;
      expect(client.connection.value, BackendConnection.disconnected);
      await client.dispose();
    },
  );

  test('restart creates a new process and accepts new requests', () async {
    final processes = [FakeBackendProcess(), FakeBackendProcess()];
    var starts = 0;
    final client = PlanningProtocolClient(() async => processes[starts++]);
    await client.start();
    await client.restart();

    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final request = _decode(processes[1].writes.single);
    processes[1].respond(request, {'student': null});

    expect(await result, {'student': null});
    expect(starts, 2);
    expect(processes[0].inputClosed, isTrue);
    await client.dispose();
  });

  test('dispose closes the process and fails pending requests', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final expectation = expectLater(
      result,
      throwsA(isA<BackendDisconnectedException>()),
    );

    await client.dispose();
    await expectation;
    expect(process.inputClosed, isTrue);
  });

  test('ProcessAppService reflects unexpected backend exit', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    final service = ProcessAppService(client);
    await service.reconnect();
    expect(service.state.value.connection, BackendConnection.connected);

    process.exit(3);
    await Future<void>.delayed(Duration.zero);
    expect(service.state.value.connection, BackendConnection.disconnected);
    await service.dispose();
  });

  test(
    'ProcessAppService enables scanner from readiness and consumes terminal event',
    () async {
      final process = FakeBackendProcess();
      final service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      await service.reconnect();
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[0]), {
        'ready': true,
        'manifest_version': 1,
        'missing': <String>[],
        'corrupt': <String>[],
      });
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[1]), {
        'targets': [
          {'target_id': 'w1', 'title': 'BA', 'status': 'ready'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value.scanAvailable, isTrue);

      final scan = service.startScan();
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[2]), {
        'ready': true,
        'manifest_version': 1,
        'missing': <String>[],
        'corrupt': <String>[],
      });
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[3]), {
        'targets': [
          {'target_id': 'w1', 'title': 'BA', 'status': 'ready'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[4]), {
        'session_id': 's1',
        'generation': 1,
        'scan_kind': 'student',
      });
      await scan;
      expect(service.state.value.scanPhase, ScanPhase.scanning);
      process.event({
        'session_id': 's1',
        'generation': 1,
        'sequence': 1,
        'scan_kind': 'student',
        'event_kind': 'terminal',
        'outcome': 'completed',
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value.scanPhase, ScanPhase.succeeded);
      expect(await service.didRequestAppExit(), AppExitResponse.exit);
      expect(process.inputClosed, isTrue);
    },
  );

  test('lazy launcher resolution leaves the shell disconnected', () async {
    final service = ProcessAppService.fromLaunchOptions(
      backendDirectory: 'Z:\\path-that-does-not-exist\\ba-planner-backend',
    );

    await expectLater(service.reconnect(), throwsA(isA<StateError>()));
    expect(service.state.value.connection, BackendConnection.disconnected);
    await service.dispose();
  });

  test('backend launcher prefers the bundled virtual environment', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ba_planner_v7_backend_runtime_',
    );
    try {
      final module = File(
        '${directory.path}${Platform.pathSeparator}core'
        '${Platform.pathSeparator}backend_process.py',
      );
      await module.parent.create(recursive: true);
      await module.writeAsString('# runtime marker');
      final python = File(
        '${directory.path}${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}'
        '${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
      );
      await python.parent.create(recursive: true);
      await python.writeAsBytes(const [0]);

      final config = BackendProcessConfig.resolve(
        backendDirectory: directory.path,
      );
      expect(config.executable, python.absolute.path);
      expect(config.arguments, ['-m', 'core.backend_process']);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'real Python process serves every P0 planning method through AppService',
    () async {
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final userDir = await Directory.systemTemp.createTemp(
        'ba_planner_m3r_p0_user_',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: backendDirectory.path,
        environment: {'BA_PLANNER_USER_DIR': userDir.path},
      );
      final service = ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 10),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      try {
        await service.reconnect();
        final student = await service.getStudent('ayane');
        final plan = await service.validatePlan({
          'version': 1,
          'future': true,
          'goals': [
            {'student_id': 'ayane', 'target_level': null, 'future_goal': 1},
          ],
        });
        final totals = await service.calculatePlan(
          currentStudents: [
            {'student_id': 'ayane', 'level': 1},
          ],
          plan: {
            'version': 1,
            'goals': [
              {'student_id': 'ayane', 'target_level': 2},
            ],
          },
        );

        expect(student?['student_id'], 'ayane');
        expect(plan.containsKey('future'), isFalse);
        expect(plan['goals'].single.containsKey('future_goal'), isFalse);
        expect(totals['level_exp'], greaterThan(0));
        expect(totals.containsKey('star_materials'), isTrue);
      } finally {
        await service.dispose();
        await userDir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  // ---- FB-3 획득처(planning.inventory.acquisition.get) -------------------------
  Map<String, dynamic> acquisitionFixture() =>
      jsonDecode(
            File(
              '${Directory.current.parent.path}${Platform.pathSeparator}'
              'contracts${Platform.pathSeparator}fixtures'
              '${Platform.pathSeparator}resource_acquisition_v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Map<String, dynamic> lastAcquisitionRequest(FakeBackendProcess process) =>
      process.writes
          .map(_decode)
          .lastWhere(
            (message) =>
                message['method'] == 'planning.inventory.acquisition.get',
          );

  test(
    'resource acquisition success, alias, errors and correlation go through the real client',
    () async {
      final fixture = acquisitionFixture();
      Map<String, dynamic> responsePayload(String name) => Map.of(
        (((fixture['responses'] as List).firstWhere(
                      (item) => (item as Map)['name'] == name,
                    )
                    as Map)['wire']
                as Map)['payload']
            as Map<String, dynamic>,
      );
      final process = FakeBackendProcess();
      final service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      await service.reconnect();

      // 알려진 키: 권위 있는 빈 표(methods=[]), revision은 packaged v1 빈 표 값.
      final known = service.getResourceAcquisition('Item_Icon_ExpItem_0');
      var request = lastAcquisitionRequest(process);
      expect(request['payload'], {'resource_key': 'Item_Icon_ExpItem_0'});
      process.respond(
        request,
        responsePayload('known-empty-Item_Icon_ExpItem_0'),
      );
      final knownResult = await known;
      expect(knownResult.resourceKey, 'Item_Icon_ExpItem_0');
      expect(knownResult.methods, isEmpty);
      expect(
        knownResult.acquisitionRevision,
        'd1d01c1803e0005ad126df3ba58dcda51a9f3d08582a32ef1ac7f21c938f85e6',
      );

      // legacy 키 질의는 원문 그대로 보내고, 정규 키 응답을 받는다.
      final alias = service.getResourceAcquisition(
        'Item_Icon_SkillBook_Ultimate_Piece',
      );
      request = lastAcquisitionRequest(process);
      expect(request['payload'], {
        'resource_key': 'Item_Icon_SkillBook_Ultimate_Piece',
      });
      process.respond(
        request,
        responsePayload('known-empty-Item_Icon_SkillBook_Ultimate'),
      );
      expect((await alias).resourceKey, 'Item_Icon_SkillBook_Ultimate');

      // 다른 자원의 응답(형식은 맞음)은 서비스가 받지 않는다. 연결은 유지된다.
      final mismatch = service.getResourceAcquisition('Item_Icon_ExpItem_0');
      request = lastAcquisitionRequest(process);
      process.respond(request, responsePayload('known-empty-credits'));
      await expectLater(mismatch, throwsFormatException);
      expect(service.state.value.connection, BackendConnection.connected);

      // 세 오류 코드는 요청 단위 BackendRemoteException이다.
      for (final code in const [
        'invalid_payload',
        'resource_not_found',
        'resource_acquisition_failed',
      ]) {
        final failed = service.getResourceAcquisition('Item_Icon_ExpItem_0');
        request = lastAcquisitionRequest(process);
        process.respond(request, {
          'error': {'code': code, 'message': 'fixture error'},
        });
        await expectLater(
          failed,
          throwsA(
            isA<BackendRemoteException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
        expect(service.state.value.connection, BackendConnection.connected);
      }

      // 상관: 역순 응답도 id로 맞는다. UTF-8 이모지 label은 통과한다.
      final first = service.getResourceAcquisition('Item_Icon_ExpItem_0');
      final firstRequest = lastAcquisitionRequest(process);
      final second = service.getResourceAcquisition('Item_Icon_SecretStone');
      final secondRequest = lastAcquisitionRequest(process);
      expect(firstRequest['id'], isNot(secondRequest['id']));
      process.respond(
        secondRequest,
        responsePayload('known-empty-Item_Icon_SecretStone'),
      );
      final emoji =
          ((fixture['strict_response_cases'] as List).firstWhere(
                    (item) =>
                        (item as Map)['name'] == 'TEST_ONLY-valid-emoji-label',
                  )
                  as Map)['payload']
              as Map<String, dynamic>;
      process.respond(firstRequest, emoji);
      expect((await second).resourceKey, 'Item_Icon_SecretStone');
      expect((await first).methods.single.label, 'TEST_ONLY 😀');
      await service.dispose();
    },
  );

  test(
    'malformed acquisition responses and wrong error codes fail closed',
    () async {
      final fixture = acquisitionFixture();
      final validRow =
          (((fixture['strict_response_cases'] as List).firstWhere(
                        (item) =>
                            (item as Map)['name'] == 'TEST_ONLY-valid-null',
                      )
                      as Map)['payload']
                  as Map)['methods']
              as List;
      Map<String, dynamic> withSource(Map<String, dynamic> source) => {
        'resource_key': 'Item_Icon_ExpItem_0',
        'methods': [
          {
            ...Map<String, dynamic>.from(validRow.single as Map),
            'source': source,
          },
        ],
        'acquisition_revision':
            'e53e3f5bccfaf4448bf28aa99b1ac087d9ac80f0afee86847037ba36e9bbbc23',
      };
      final cases = <(String, Map<String, dynamic>, bool)>[
        for (final raw in fixture['strict_response_cases'] as List)
          (
            (raw as Map)['name'] as String,
            Map<String, dynamic>.from(raw['payload'] as Map),
            raw['strict_dto_valid'] as bool,
          ),
        // 날짜 경계(00:11): year 0, 한 자리 월, 끝 개행, 윤년 아닌 2월 29일은 거부, 윤년은 통과.
        for (final date in const [
          '0000-01-01',
          '2026-1-01',
          '2026-01-01\n',
          '2023-02-29',
          '2026-01-01T00:00:00',
        ])
          (
            'date $date',
            withSource({
              'server': 'KR',
              'reference': 'TEST_ONLY',
              'reviewed_at': date,
            }),
            false,
          ),
        (
          'leap day',
          withSource({
            'server': 'KR',
            'reference': 'TEST_ONLY',
            'reviewed_at': '2024-02-29',
          }),
          true,
        ),
        (
          'source missing reviewed_at',
          withSource({'server': 'KR', 'reference': 'TEST_ONLY'}),
          false,
        ),
      ];
      for (final (name, payload, valid) in cases) {
        final process = FakeBackendProcess();
        final client = PlanningProtocolClient(() async => process);
        await client.start();
        final result = client.send('planning.inventory.acquisition.get', {
          'resource_key': 'Item_Icon_ExpItem_0',
        });
        process.respond(_decode(process.writes.single), payload);
        if (valid) {
          final wire = await result;
          expect(
            ResourceAcquisitionResult.fromWire(wire).resourceKey,
            payload['resource_key'],
            reason: name,
          );
          expect(client.connection.value, BackendConnection.connected);
        } else {
          await expectLater(
            result,
            throwsA(isA<BackendProtocolException>()),
            reason: name,
          );
          expect(
            client.connection.value,
            BackendConnection.disconnected,
            reason: name,
          );
        }
        await client.dispose();
      }

      // 다른 메서드의 오류 코드·unknown_method는 획득처 오류가 아니다.
      for (final raw in fixture['errors'] as List) {
        final fixtureCase = (raw as Map).cast<String, dynamic>();
        final process = FakeBackendProcess();
        final client = PlanningProtocolClient(() async => process);
        await client.start();
        final result = client.send('planning.inventory.acquisition.get', {
          'resource_key': 'Item_Icon_ExpItem_0',
        });
        process.respond(
          _decode(process.writes.single),
          Map<String, dynamic>.from(
            (fixtureCase['wire'] as Map)['payload'] as Map,
          ),
        );
        await expectLater(
          result,
          throwsA(
            fixtureCase['schema_valid'] == true
                ? isA<BackendRemoteException>()
                : isA<BackendProtocolException>(),
          ),
          reason: fixtureCase['name'] as String,
        );
        await client.dispose();
      }
    },
  );

  test('acquisition query is validated before it is sent', () async {
    final process = FakeBackendProcess();
    final service = ProcessAppService(
      PlanningProtocolClient(() async => process),
    );
    await service.reconnect();
    final before = process.writes.length;
    for (final key in ['', '\ud800', 'a' * 1025, '가' * 342]) {
      await expectLater(
        service.getResourceAcquisition(key),
        throwsFormatException,
        reason: 'length ${key.length}',
      );
    }
    expect(process.writes.length, before);
    // UTF-8 1024바이트 경계는 통과한다(가 341자 = 1023바이트 + a).
    final edge = service.getResourceAcquisition('${'가' * 341}a');
    expect(
      lastAcquisitionRequest(process)['payload']['resource_key'],
      '${'가' * 341}a',
    );
    process.respond(lastAcquisitionRequest(process), {
      'resource_key': '${'가' * 341}a',
      'methods': <Object>[],
      'acquisition_revision':
          'd1d01c1803e0005ad126df3ba58dcda51a9f3d08582a32ef1ac7f21c938f85e6',
    });
    expect((await edge).methods, isEmpty);
    await service.dispose();
  });
}

Map<String, dynamic> _decode(String line) {
  return Map<String, dynamic>.from(jsonDecode(line) as Map);
}

class FakeBackendProcess implements BackendProcessHandle {
  final StreamController<String> stdout = StreamController<String>();
  final StreamController<String> stderr = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> writes = [];
  bool inputClosed = false;
  bool terminated = false;
  Object? writeError;

  @override
  Stream<String> get stdoutLines => stdout.stream;

  @override
  Stream<String> get stderrLines => stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void writeLine(String line) {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    writes.add(line);
  }

  @override
  Future<void> closeInput() async {
    inputClosed = true;
    exit(0);
  }

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    terminated = true;
    exit(-1);
    return true;
  }

  void respond(
    Map<String, dynamic> request,
    Map<String, dynamic> payload, {
    String? method,
  }) {
    stdout.add(
      jsonEncode({
        'protocol': 1,
        'id': request['id'],
        'type': 'response',
        'method': method ?? request['method'],
        'payload': payload,
      }),
    );
  }

  void event(Map<String, dynamic> payload) {
    stdout.add(
      jsonEncode({
        'protocol': 1,
        'type': 'event',
        'method': 'scanner.session.event',
        'payload': payload,
      }),
    );
  }

  void exit(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }
}
