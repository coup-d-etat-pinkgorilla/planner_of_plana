import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const FlickerProbeApp());
}

class FlickerProbeApp extends StatelessWidget {
  const FlickerProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BA Planner Flutter Flicker Probe',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff86c8ff),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff171b25),
        fontFamily: 'Malgun Gothic',
      ),
      home: const ProbeShell(),
    );
  }
}

enum ProbePage { home, settings }

class ProbeShell extends StatefulWidget {
  const ProbeShell({super.key});

  @override
  State<ProbeShell> createState() => _ProbeShellState();
}

class _ProbeShellState extends State<ProbeShell> {
  ProbePage _page = ProbePage.home;
  bool _isolateCards = true;
  int _fullRebuilds = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              page: _page,
              onPageChanged: (page) => setState(() => _page = page),
            ),
            Expanded(
              child: switch (_page) {
                ProbePage.home => HomeProbe(
                  key: ValueKey(_fullRebuilds),
                  isolateCards: _isolateCards,
                ),
                ProbePage.settings => SettingsProbe(
                  isolateCards: _isolateCards,
                  onIsolationChanged: (value) {
                    setState(() => _isolateCards = value);
                  },
                  fullRebuilds: _fullRebuilds,
                  onFullRebuild: () {
                    setState(() => _fullRebuilds++);
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.page, required this.onPageChanged});

  final ProbePage page;
  final ValueChanged<ProbePage> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xff222837),
        border: Border(bottom: BorderSide(color: Color(0xff465068))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flutter Adaptive-Sync Flicker Probe',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  '주기적 애니메이션 없음 · 실제 홈 PNG · hover 시 해당 카드만 갱신',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xffaeb8ca), fontSize: 12),
                ),
              ],
            ),
          ),
          _TabButton(
            label: '홈',
            selected: page == ProbePage.home,
            onPressed: () => onPageChanged(ProbePage.home),
          ),
          const SizedBox(width: 8),
          _TabButton(
            label: '설정',
            selected: page == ProbePage.settings,
            onPressed: () => onPageChanged(ProbePage.settings),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xff477aa6)
            : const Color(0xff30384a),
        minimumSize: const Size(92, 42),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class HomeProbe extends StatelessWidget {
  const HomeProbe({super.key, required this.isolateCards});

  final bool isolateCards;

  static const cards = <({String fileName, String caption, int flex})>[
    (fileName: 'shittim.png', caption: '싯딤의 상자와 연결', flex: 3),
    (fileName: 'students.png', caption: '학생부 확인', flex: 1),
    (fileName: 'plan.png', caption: '계획 설정', flex: 1),
    (fileName: 'inventory.png', caption: '인벤토리', flex: 1),
    (fileName: 'pvp.png', caption: '전술대항전', flex: 1),
    (fileName: 'statistics.png', caption: '통계', flex: 1),
    (fileName: 'scan.png', caption: '스캔', flex: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final assetRoot = findHomeAssetRoot();
    return ColoredBox(
      color: const Color(0xff171b25),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'HOME PNG HOVER TEST',
                  style: TextStyle(
                    color: Color(0xff8bd3ff),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  assetRoot == null
                      ? '이미지 경로를 찾지 못함'
                      : '카드 repaint 격리: ${isolateCards ? "ON" : "OFF"}',
                  style: TextStyle(
                    color: assetRoot == null
                        ? const Color(0xffff8c8c)
                        : const Color(0xff9ba8bb),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  final columns = wide ? 3 : 2;
                  return GridView.builder(
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: wide ? 1.9 : 1.55,
                    ),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      final child = HomeMenuCard(
                        key: ValueKey(card.fileName),
                        caption: card.caption,
                        imageFile: assetRoot == null
                            ? null
                            : File('${assetRoot.path}\\${card.fileName}'),
                      );
                      return isolateCards
                          ? RepaintBoundary(child: child)
                          : child;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeMenuCard extends StatefulWidget {
  const HomeMenuCard({
    super.key,
    required this.caption,
    required this.imageFile,
  });

  final String caption;
  final File? imageFile;

  @override
  State<HomeMenuCard> createState() => _HomeMenuCardState();
}

class _HomeMenuCardState extends State<HomeMenuCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: ClipPath(
          clipper: const DiagonalCardClipper(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.imageFile case final imageFile?)
                Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const _MissingImage(),
                )
              else
                const _MissingImage(),
              const _CaptionGradient(),
              if (_hovered)
                const ColoredBox(color: Color.fromARGB(24, 255, 255, 255)),
              if (_pressed)
                const ColoredBox(color: Color.fromARGB(34, 0, 0, 0)),
              Positioned(
                left: 18,
                right: 30,
                bottom: 14,
                child: Text(
                  widget.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: const DiagonalBorderPainter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff35425b), Color(0xff263044)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text('PNG asset unavailable')),
    );
  }
}

class _CaptionGradient extends StatelessWidget {
  const _CaptionGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.48, 0.72, 1],
          colors: [Colors.transparent, Color(0x990d1420), Color(0xee111722)],
        ),
      ),
    );
  }
}

class DiagonalCardClipper extends CustomClipper<Path> {
  const DiagonalCardClipper();

  Path createPath(Size size) {
    final slant = (size.height * 0.16).clamp(12.0, 34.0);
    return Path()
      ..moveTo(slant, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - slant, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  Path getClip(Size size) => createPath(size);

  @override
  bool shouldReclip(covariant DiagonalCardClipper oldClipper) => false;
}

class DiagonalBorderPainter extends CustomPainter {
  const DiagonalBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const DiagonalCardClipper().createPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xff71809a),
    );
  }

  @override
  bool shouldRepaint(covariant DiagonalBorderPainter oldDelegate) => false;
}

class SettingsProbe extends StatelessWidget {
  const SettingsProbe({
    super.key,
    required this.isolateCards,
    required this.onIsolationChanged,
    required this.fullRebuilds,
    required this.onFullRebuild,
  });

  final bool isolateCards;
  final ValueChanged<bool> onIsolationChanged;
  final int fullRebuilds;
  final VoidCallback onFullRebuild;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          '검증 설정',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'AOC Adaptive-Sync를 켠 상태에서 창 모드와 최대화 상태를 각각 확인합니다.',
          style: TextStyle(color: Color(0xffaeb8ca)),
        ),
        const SizedBox(height: 24),
        Card(
          color: const Color(0xff252c3b),
          child: SwitchListTile(
            title: const Text('카드별 RepaintBoundary'),
            subtitle: const Text('ON/OFF 각각에서 PNG 버튼 위로 커서를 빠르게 왕복해 비교합니다.'),
            value: isolateCards,
            onChanged: onIsolationChanged,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xff252c3b),
          child: ListTile(
            title: const Text('홈 화면 전체 재생성'),
            subtitle: Text('지금까지 $fullRebuilds회 실행'),
            trailing: FilledButton(
              onPressed: onFullRebuild,
              child: const Text('다음 홈 진입 시 재생성'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _Checklist(),
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    const checks = [
      '홈 PNG 버튼 사이로 커서를 빠르게 왕복',
      '이미지 없는 헤더 탭과 PNG 버튼 hover 비교',
      '홈과 설정 탭을 반복 전환',
      '창 크기 변경 후 같은 동작 반복',
      '창 모드와 최대화 상태 비교',
      '30초 이상 입력하지 않은 뒤 첫 hover 확인',
    ];
    return Card(
      color: const Color(0xff252c3b),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '수동 확인 순서',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final check in checks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• $check'),
              ),
          ],
        ),
      ),
    );
  }
}

Directory? findHomeAssetRoot() {
  Directory cursor = Directory.current.absolute;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = Directory(
      '${cursor.path}${Platform.pathSeparator}assets${Platform.pathSeparator}'
      'ui${Platform.pathSeparator}home_menu',
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }
  return null;
}
