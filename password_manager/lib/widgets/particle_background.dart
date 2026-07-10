import 'package:flutter/material.dart';

class Particle {
  double x, y, r, vx, vy, opacity;
  bool isPurple;
  Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.vx,
    required this.vy,
    required this.opacity,
    required this.isPurple,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final bool unlocked;
  ParticlePainter(this.particles, this.unlocked);

  @override
  void paint(Canvas canvas, Size size) {
    final grad = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: unlocked
          ? [const Color(0xFF082412), Colors.black]
          : [const Color(0xFF0A1226), Colors.black],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = grad);
    
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.r,
        Paint()
          ..color = (p.isPurple ? const Color(0xFF6366F1) : const Color(0xFF94A3B8))
              .withValues(alpha: p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => true;
}
