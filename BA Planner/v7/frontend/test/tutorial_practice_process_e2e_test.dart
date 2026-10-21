// F3c-1: 지금 백엔드는 repository.practice.*에 unknown_method로 답한다(contracts/tutorial-practice-v1 fixture
// runtimeImplemented:false). 그 답을 "튜토리얼 실행 불가(백엔드 미지원)"로 해독하고, 연결은 끊지 않는다.
// 실제 practice 수명 · 가상 재생 · 교차 적용 거부 Process E2E는 XB X4 runtime 짝 라운드 몫이다.
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'practice methods decode unknown_method as unsupported without disconnecting',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba_planner_f3c1_');
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      final service = ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 30),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      try {
        await service.reconnect();
        expect(service.practiceSupport, TutorialPracticeSupport.unknown);
        expect(
          await service.probePracticeSupport(),
          TutorialPracticeSupport.unsupported,
        );
        final profile = await service.createProfile('Practice', 'f3c1-profile');
        await expectLater(
          service.createPractice(
            PracticeCreateRequest(
              originProfileId: profile.id,
              expectedOriginRevision: profile.revision,
              idempotencyKey: 'f3c1-start',
            ),
          ),
          throwsA(
            isA<TutorialPracticeUnsupportedException>().having(
              (error) => error.method,
              'method',
              'repository.practice.create',
            ),
          ),
        );
        expect(service.practiceSupport, TutorialPracticeSupport.unsupported);
        // unknown_method는 repository 오류일 뿐 protocol 오류가 아니다 — 연결 · 일반 계정 그대로.
        expect(service.state.value.connection, BackendConnection.connected);
        expect((await service.listProfiles()).map((item) => item.id), [
          profile.id,
        ]);
      } finally {
        service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
