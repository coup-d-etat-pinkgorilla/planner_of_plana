// 다중 폼 초상 교대 (FE3-e, FD-064, W-Card-States "폼 2개(3초)", CSS `stuform2/3/4`).
//
// 폼이 2개 이상인 학생(FB-5 catalog `forms`)의 초상은 폼 하나당 3초씩 보이고, 한 바퀴는 폼 수 × 3초다.
// 전환은 페이드 없이 계단식(step)이다. 시계는 앱 전체에 하나([StudentFormClock.instance])이며 카드마다
// Timer를 만들지 않는다. 학생 카드·선택 카드·최근 본 학생처럼 초상을 그리는 곳은 [StudentFormCycleBuilder]로
// 같은 단계 값을 읽는다.
// - 시계는 듣는 곳이 있을 때만 3초 간격 Timer 하나를 돌린다. 듣는 곳이 모두 빠지면 멈춘다.
// - [StudentFormCycleBuilder]는 다중 폼 학생을 그릴 때(`active`)와 TickerMode가 켜져 있을 때만 듣는다.
//   다른 탭으로 가면(AnimatedSectionStack이 TickerMode를 끈다) 그 자리는 멈춘다. 화면 밖 카드는 그리드가
//   만들지 않는다.
// - 테스트·golden은 [StudentFormClockScope]로 시계를 바꾸거나 [StudentFormClock.freeze]로 단계를 고정한다.
//   Timer라서 testWidgets의 가짜 시간으로 3초를 밀 수 있고, 프레임을 계속 예약하지 않는다.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../services/app_service.dart';

/// 폼 하나를 보여 주는 시간(FD-064).
const studentFormStepDuration = Duration(seconds: 3);

/// 학생 초상 asset 경로 접두.
const studentPortraitDirectory = 'assets/student_portraits';

/// 다중 폼 초상 교대 시계. 단계 값은 3초마다 1씩 늘고, 학생마다 `단계 % 폼 수`번째 폼을 보인다.
class StudentFormClock extends ChangeNotifier {
  StudentFormClock({this.period = studentFormStepDuration});

  /// 앱 전체가 함께 쓰는 시계.
  static final StudentFormClock instance = StudentFormClock();

  final Duration period;

  int _step = 0;
  int? _frozen;
  Timer? _timer;

  /// 지금 단계(0부터).
  int get step => _frozen ?? _step;

  /// 단계를 [value]로 고정한다(테스트·golden). null이면 고정을 풀고 다시 흐른다.
  void freeze(int? value) {
    if (value == _frozen) return;
    _frozen = value;
    _sync();
    notifyListeners();
  }

  /// 흐르는 단계 값을 0으로 되돌린다(테스트 사이 초기화).
  @visibleForTesting
  void reset() {
    _step = 0;
    notifyListeners();
  }

  /// Timer가 도는가(테스트용).
  @visibleForTesting
  bool get isRunning => _timer != null;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  // 알리는 도중 듣는 곳이 빠지면 ChangeNotifier가 개수를 나중에 줄이므로, 알린 뒤 다시 맞춘다.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _sync();
  }

  void _sync() {
    final run = hasListeners && _frozen == null;
    if (run && _timer == null) {
      _timer = Timer.periodic(period, (_) {
        _step += 1;
        notifyListeners();
      });
    } else if (!run) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// 아래 위젯들이 읽을 시계를 바꾼다(테스트에서 주입). 없으면 [StudentFormClock.instance].
class StudentFormClockScope extends InheritedWidget {
  const StudentFormClockScope({
    super.key,
    required this.clock,
    required super.child,
  });

  final StudentFormClock clock;

  static StudentFormClock of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StudentFormClockScope>()
          ?.clock ??
      StudentFormClock.instance;

  @override
  bool updateShouldNotify(StudentFormClockScope oldWidget) =>
      !identical(oldWidget.clock, clock);
}

/// [step]에서 보일 폼 번호(0부터). 폼이 1개 이하면 늘 0이다.
int studentFormIndexAt(StudentCatalogEntry student, int step) {
  final count = student.forms.length;
  if (count < 2) return 0;
  return step % count;
}

/// [step]에서 보일 초상 asset. 폼 1개 이하 학생은 기존 `<id>.png`, 다중 폼 학생은 그 단계의 폼 초상이다.
/// 폼이 초상 이름을 선언하지 않으면 기존 `<id>.png`(그것도 없으면 그리드의 기존 빈 자리)로 그린다.
String studentPortraitAssetAt(StudentCatalogEntry student, int step) {
  final fallback = '$studentPortraitDirectory/${student.studentId}.png';
  if (!student.isMultiForm) return fallback;
  final template = student.forms[studentFormIndexAt(student, step)].templateName;
  return template == null ? fallback : '$studentPortraitDirectory/$template';
}

/// 학생의 모든 폼 초상 asset(warmup용, 순서대로, 중복 없음).
List<String> studentPortraitAssetsOf(StudentCatalogEntry student) => <String>{
  '$studentPortraitDirectory/${student.studentId}.png',
  for (final form in student.forms)
    if (form.templateName case final template?)
      '$studentPortraitDirectory/$template',
}.toList(growable: false);

/// 공용 시계의 단계 값으로 [builder]를 그린다. [active]가 false(다중 폼 학생 없음)거나 TickerMode가
/// 꺼져 있으면 시계를 듣지 않는다(마지막 단계 값으로 멈춘다).
class StudentFormCycleBuilder extends StatefulWidget {
  const StudentFormCycleBuilder({
    super.key,
    required this.active,
    required this.builder,
  });

  /// 그리는 학생 중 다중 폼 학생이 있는가.
  final bool active;
  final Widget Function(BuildContext context, int step) builder;

  @override
  State<StudentFormCycleBuilder> createState() =>
      _StudentFormCycleBuilderState();
}

class _StudentFormCycleBuilderState extends State<StudentFormCycleBuilder> {
  StudentFormClock? _listening;
  int _step = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resubscribe();
  }

  @override
  void didUpdateWidget(StudentFormCycleBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _resubscribe();
  }

  void _resubscribe() {
    final clock = StudentFormClockScope.of(context);
    final listen = widget.active && TickerMode.valuesOf(context).enabled;
    final next = listen ? clock : null;
    if (!identical(next, _listening)) {
      _listening?.removeListener(_tick);
      _listening = next;
      next?.addListener(_tick);
    }
    // 들을 때는 지금 단계를 따른다. 멈출 때는 마지막 값을 그대로 둔다.
    if (next != null) _step = next.step;
  }

  void _tick() {
    final clock = _listening;
    if (clock == null || !mounted || clock.step == _step) return;
    setState(() => _step = clock.step);
  }

  @override
  void dispose() {
    _listening?.removeListener(_tick);
    _listening = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _step);
}
