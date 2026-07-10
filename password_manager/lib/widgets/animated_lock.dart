import 'dart:math';
import 'package:flutter/material.dart';

class _ElasticOutCurve extends Curve {
  const _ElasticOutCurve();
  @override
  double transformInternal(double t) {
    const c4 = (2 * pi) / 3;
    if (t == 0) return 0;
    if (t == 1) return 1;
    return pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1;
  }
}

class _EaseInBackCurve extends Curve {
  const _EaseInBackCurve();
  @override
  double transformInternal(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return c3 * t * t * t - c1 * t * t;
  }
}

class LockPainter extends CustomPainter {
  final double shackleProgress;
  final double bodyScale;
  final Color lockColor;

  const LockPainter({
    required this.shackleProgress,
    required this.bodyScale,
    required this.lockColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final strokePaint = Paint()
      ..color = lockColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8;

    final fillPaint = Paint()..color = lockColor..style = PaintingStyle.fill;
    final holePaint = Paint()..color = Colors.black..style = PaintingStyle.fill;

    // Cuerpo con bounce
    canvas.save();
    canvas.translate(cx, cy + 8);
    canvas.scale(bodyScale, bodyScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 30, height: 22), const Radius.circular(5)),
      fillPaint,
    );
    canvas.drawCircle(const Offset(0, -2), 3.5, holePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-1.5, 1.5, 3, 5), const Radius.circular(1.5)), holePaint);
    canvas.restore();

    // Arco con anticipacion + elastic overshoot
    double tx = 0, ty = 0, rot = 0;
    const anticipationEnd = 0.25;

    if (shackleProgress < anticipationEnd) {
      final t = shackleProgress / anticipationEnd;
      ty = const _EaseInBackCurve().transformInternal(t) * 4;
    } else {
      final t = (shackleProgress - anticipationEnd) / (1 - anticipationEnd);
      final eased = const _ElasticOutCurve().transformInternal(t);
      ty  = 4 - eased * 32;
      tx  = eased * -4;
      rot = eased * (-22 * pi / 180);
    }

    canvas.save();
    canvas.translate(cx + tx, cy - 3 + ty);
    canvas.rotate(rot);
    final path = Path()
      ..addArc(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 20),
        0,
        -pi,
      );
    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LockPainter old) =>
      old.shackleProgress != shackleProgress || old.bodyScale != bodyScale || old.lockColor != lockColor;
}

class AnimatedLock extends StatefulWidget {
  final bool isOpen;
  const AnimatedLock({super.key, required this.isOpen});
  @override
  State<AnimatedLock> createState() => _AnimatedLockState();
}

class _AnimatedLockState extends State<AnimatedLock> with TickerProviderStateMixin {
  late AnimationController _shackleCtrl;
  late AnimationController _bodyCtrl;
  late AnimationController _checkCtrl;
  late AnimationController _colorCtrl;
  late Animation<double>   _shackleAnim;
  late Animation<double>   _bodyAnim;
  late Animation<double>   _checkAnim;
  late Animation<Color?>   _colorAnim;
  bool _showCheck = false;

  @override
  void initState() {
    super.initState();
    _shackleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _shackleAnim = Tween<double>(begin: 0, end: 1).animate(_shackleCtrl);

    _bodyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _bodyAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bodyCtrl, curve: Curves.easeInOut));

    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);

    _colorCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _colorAnim = ColorTween(begin: Colors.white, end: const Color(0xFF4ADE80))
        .animate(CurvedAnimation(parent: _colorCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedLock old) {
    super.didUpdateWidget(old);
    if (widget.isOpen && !old.isOpen) _playOpenSequence();
    if (!widget.isOpen && old.isOpen) _reset();
  }

  void _playOpenSequence() async {
    _shackleCtrl.forward();
    _colorCtrl.forward();
    await _shackleCtrl.forward();
    _bodyCtrl.forward();
    await _bodyCtrl.forward();
    if (mounted) { setState(() => _showCheck = true); _checkCtrl.forward(); }
  }

  void _reset() {
    _shackleCtrl.reset(); _bodyCtrl.reset(); _checkCtrl.reset(); _colorCtrl.reset();
    if (mounted) setState(() => _showCheck = false);
  }

  @override
  void dispose() {
    _shackleCtrl.dispose(); _bodyCtrl.dispose(); _checkCtrl.dispose(); _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shackleAnim, _bodyAnim, _colorAnim, _checkAnim]),
      builder: (context, child) {
        return SizedBox(
          width: 52, height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: _showCheck ? (1 - _checkAnim.value).clamp(0.0, 1.0) : 1.0,
                child: CustomPaint(
                  size: const Size(52, 56),
                  painter: LockPainter(
                    shackleProgress: _shackleAnim.value,
                    bodyScale: _bodyAnim.value,
                    lockColor: _colorAnim.value ?? Colors.white,
                  ),
                ),
              ),
              if (_showCheck)
                Opacity(
                  opacity: _checkAnim.value,
                  child: const Icon(Icons.check_rounded, color: Color(0xFF4ADE80), size: 30),
                ),
            ],
          ),
        );
      },
    );
  }
}
