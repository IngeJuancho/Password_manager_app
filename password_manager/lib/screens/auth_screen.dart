import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'home_screen.dart';
import '../widgets/particle_background.dart';
import '../widgets/animated_lock.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isUnlocked = false;
  String _authStatus = 'Seguridad Biométrica';
  bool _statusSuccess = false;

  late List<Particle> _particles;
  late AnimationController _particleCtrl;
  late AnimationController _scanCtrl;
  late Animation<double> _scanPos;
  late Animation<double> _scanOpacity;
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;
  late AnimationController _orbitCtrl1;
  late AnimationController _orbitCtrl2;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _initParticles();

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tickParticles)
      ..repeat();

    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scanPos = Tween<double>(begin: 0.15, end: 0.85)
        .animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));
    _scanOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.85), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.85), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0), weight: 10),
    ]).animate(_scanCtrl);

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);

    _orbitCtrl1 = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _orbitCtrl2 = AnimationController(
        vsync: this, duration: const Duration(seconds: 11))
      ..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 600), _authenticate);
  }

  void _initParticles() {
    _particles = List.generate(
        38,
        (_) => Particle(
              x: _rng.nextDouble() * 400,
              y: _rng.nextDouble() * 800,
              r: _rng.nextDouble() * 1.1 + 0.3,
              vx: (_rng.nextDouble() - 0.5) * 0.3,
              vy: (_rng.nextDouble() - 0.5) * 0.3,
              opacity: _rng.nextDouble() * 0.32 + 0.07,
              isPurple: _rng.nextBool(),
            ));
  }

  void _tickParticles() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0) p.x = 400;
        if (p.x > 400) p.x = 0;
        if (p.y < 0) p.y = 800;
        if (p.y > 800) p.y = 0;
      }
    });
  }

  Future<void> _authenticate() async {
    if (!mounted) return;
    setState(() {
      _isAuthenticating = true;
      _authStatus = 'Escaneando...';
    });
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Verifica tu identidad para acceder',
        options: const AuthenticationOptions(
            biometricOnly: false, stickyAuth: true),
      );
      if (!mounted) return;
      if (didAuth) {
        _scanCtrl.repeat(count: 2);
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _isUnlocked = true;
          _authStatus = 'Verificando huella...';
        });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        setState(() {
          _authStatus = 'Acceso Concedido';
          _statusSuccess = true;
          _isAuthenticating = false;
        });
        _rippleCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) _navigateToHome();
      } else {
        if (!mounted) return;
        setState(() {
          _isAuthenticating = false;
          _authStatus = 'Intenta nuevamente';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authStatus = 'Error de seguridad';
      });
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const PasswordManagerHome(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ));
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _scanCtrl.dispose();
    _rippleCtrl.dispose();
    _orbitCtrl1.dispose();
    _orbitCtrl2.dispose();
    super.dispose();
  }

  Widget _buildOrbit(AnimationController ctrl, double size, bool reverse) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final angle = (reverse ? -1 : 1) * ctrl.value * 2 * pi;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1))),
            Transform.translate(
              offset: Offset((size / 2) * cos(angle), (size / 2) * sin(angle)),
              child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isUnlocked
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF6366F1))),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildRipple(double delay) {
    return AnimatedBuilder(
      animation: _rippleAnim,
      builder: (context, child) {
        final t = (_rippleAnim.value - delay).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 + t * 1.7,
          child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF4ADE80)
                          .withValues(alpha: (1 - t) * 0.5),
                      width: 1.5))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        CustomPaint(
            size: Size(size.width, size.height),
            painter: ParticlePainter(_particles, _isUnlocked)),
        AnimatedBuilder(
          animation: _scanCtrl,
          builder: (context, child) {
            if (!_scanCtrl.isAnimating && _scanCtrl.value == 0) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: size.height * _scanPos.value,
              left: 0,
              right: 0,
              child: Opacity(
                  opacity: _scanOpacity.value,
                  child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Color(0xFF6366F1),
                        Colors.transparent
                      ])))),
            );
          },
        ),
        Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(alignment: Alignment.center, children: [
                    _buildRipple(0.0),
                    _buildRipple(0.18),
                    _buildRipple(0.36),
                    _buildOrbit(_orbitCtrl1, 108, false),
                    _buildOrbit(_orbitCtrl2, 126, true),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isUnlocked
                              ? const Color(0xFF4ADE80)
                                  .withValues(alpha: 0.09)
                              : const Color(0xFF6366F1)
                                  .withValues(alpha: 0.09),
                          border: Border.all(
                              color: _isUnlocked
                                  ? const Color(0xFF4ADE80)
                                      .withValues(alpha: 0.38)
                                  : const Color(0xFF6366F1)
                                      .withValues(alpha: 0.28),
                              width: 1.5)),
                      child: Center(
                          child: AnimatedLock(isOpen: _isUnlocked)),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                Text('Password Manager',
                    style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusSuccess
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF6366F1))),
                  const SizedBox(width: 7),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _statusSuccess
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.48)),
                    child: Text(_authStatus),
                  ),
                ]),
                const SizedBox(height: 52),
                AnimatedOpacity(
                  opacity: (!_isAuthenticating && !_isUnlocked) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: _isAuthenticating || _isUnlocked,
                    child: GestureDetector(
                      onTap: _authenticate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 13),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.16),
                            border: Border.all(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.38))),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fingerprint,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text('Desbloquear',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      letterSpacing: 0.4)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ]),
        ),
      ]),
    );
  }
}
