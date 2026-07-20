import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class SectionMotionSpec {
  const SectionMotionSpec({required this.intro, required this.outro});

  final double intro;
  final double outro;
}

Offset sectionMotionOffset(
  Size hostSize,
  double angleDegrees, {
  double gap = 40,
}) {
  final radians = (angleDegrees % 360) * math.pi / 180;
  final unitX = math.cos(radians);
  final unitY = -math.sin(radians);
  final distances = <double>[];
  if (unitX.abs() > 1e-6) {
    distances.add((hostSize.width + gap) / unitX.abs());
  }
  if (unitY.abs() > 1e-6) {
    distances.add((hostSize.height + gap) / unitY.abs());
  }
  final distance = distances.isEmpty
      ? hostSize.height + gap
      : distances.reduce(math.min);
  return Offset(unitX * distance, unitY * distance);
}

class AnimatedSectionStack extends StatefulWidget {
  const AnimatedSectionStack({
    super.key,
    required this.index,
    required this.children,
    required this.motions,
  }) : assert(children.length == motions.length);

  final int index;
  final List<Widget> children;
  final List<SectionMotionSpec> motions;

  @override
  State<AnimatedSectionStack> createState() => _AnimatedSectionStackState();
}

class _AnimatedSectionStackState extends State<AnimatedSectionStack>
    with SingleTickerProviderStateMixin {
  static const _pullDuration = Duration(milliseconds: 120);
  static const _exitDuration = Duration(milliseconds: 300);
  static const _enterDuration = Duration(milliseconds: 360);
  static const _totalDuration = Duration(milliseconds: 120 + 300 + 360 + 190);

  late final AnimationController _controller;
  late int _settledIndex;
  late int _fromIndex;
  late int _toIndex;

  @override
  void initState() {
    super.initState();
    _settledIndex = widget.index;
    _fromIndex = widget.index;
    _toIndex = widget.index;
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _settledIndex = _toIndex;
            _fromIndex = _toIndex;
          });
        }
      });
  }

  @override
  void didUpdateWidget(AnimatedSectionStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == _toIndex) {
      return;
    }
    _fromIndex = _controller.isAnimating ? _toIndex : _settledIndex;
    _toIndex = widget.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final animating = _controller.isAnimating;
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (var index = 0; index < widget.children.length; index++)
                    _buildPage(index, size, animating),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPage(int index, Size size, bool animating) {
    final participating =
        animating && (index == _fromIndex || index == _toIndex);
    final visible = participating || (!animating && index == _settledIndex);
    final offset = !animating
        ? Offset.zero
        : index == _fromIndex
        ? _outgoingOffset(size, _controller.value)
        : index == _toIndex
        ? _incomingOffset(size, _controller.value)
        : Offset.zero;
    final interactive = !animating && index == _settledIndex;

    return Positioned.fill(
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: ExcludeSemantics(
            excluding: !interactive,
            child: IgnorePointer(
              ignoring: !interactive,
              child: Transform.translate(
                key: ValueKey('animated-section-$index'),
                offset: offset,
                child: widget.children[index],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _outgoingOffset(Size size, double progress) {
    final pullEnd =
        _pullDuration.inMilliseconds / _totalDuration.inMilliseconds;
    final exitEnd =
        (_pullDuration + _exitDuration).inMilliseconds /
        _totalDuration.inMilliseconds;
    final full = sectionMotionOffset(size, widget.motions[_fromIndex].outro);
    final pull = -full * 0.055;

    if (progress <= pullEnd) {
      final t = Curves.easeOutCubic.transform(progress / pullEnd);
      return Offset.lerp(Offset.zero, pull, t)!;
    }
    final t = Curves.easeInCubic.transform(
      ((progress - pullEnd) / (exitEnd - pullEnd)).clamp(0, 1).toDouble(),
    );
    return Offset.lerp(pull, full, t)!;
  }

  Offset _incomingOffset(Size size, double progress) {
    final exitEnd =
        (_pullDuration + _exitDuration).inMilliseconds /
        _totalDuration.inMilliseconds;
    final enterEnd =
        (_pullDuration + _exitDuration + _enterDuration).inMilliseconds /
        _totalDuration.inMilliseconds;
    final full = sectionMotionOffset(size, widget.motions[_toIndex].intro);
    final start = -full;
    final cruiseEnd = start * 0.16;

    if (progress <= exitEnd) {
      return start;
    }
    if (progress <= enterEnd) {
      final t = ((progress - exitEnd) / (enterEnd - exitEnd))
          .clamp(0, 1)
          .toDouble();
      return Offset.lerp(start, cruiseEnd, t)!;
    }
    final t = Curves.easeOutCubic.transform(
      ((progress - enterEnd) / (1 - enterEnd)).clamp(0, 1).toDouble(),
    );
    return Offset.lerp(cruiseEnd, Offset.zero, t)!;
  }
}
