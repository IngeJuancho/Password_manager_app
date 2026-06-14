import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode { light, darkMaterial, darkAmoled }
final ValueNotifier<AppThemeMode> appThemeNotifier = ValueNotifier(AppThemeMode.darkAmoled);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode') ?? 2;
  appThemeNotifier.value = AppThemeMode.values[themeIndex];
  runApp(const MyApp());
}

class AppColors {
  static const Color lightBackground  = Color(0xFFF2F4F8);
  static const Color lightSurface     = Colors.white;
  static const Color lightPrimary     = Color(0xFF4F46E5);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color darkMaterialBackground = Color(0xFF121212);
  static const Color darkMaterialSurface    = Color(0xFF1E1E1E);
  static const Color darkPrimary  = Color(0xFF6366F1);
  static const Color darkAccent   = Color(0xFF00E5FF);
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface    = Color(0xFF0A0A0A);
  static const Color darkTextPrimary  = Color(0xFFF1F5F9);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _getThemeData(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeData(
          brightness: Brightness.light,
          primaryColor: AppColors.lightPrimary,
          scaffoldBackgroundColor: AppColors.lightBackground,
          cardColor: AppColors.lightSurface,
          colorScheme: const ColorScheme.light(primary: AppColors.lightPrimary, secondary: Colors.tealAccent, surface: AppColors.lightSurface),
          appBarTheme: const AppBarTheme(backgroundColor: AppColors.lightPrimary, foregroundColor: Colors.white, elevation: 0),
          textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(bodyColor: AppColors.lightTextPrimary, displayColor: AppColors.lightTextPrimary),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.lightPrimary, foregroundColor: Colors.white),
        );
      case AppThemeMode.darkMaterial:
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.darkPrimary,
          scaffoldBackgroundColor: AppColors.darkMaterialBackground,
          cardColor: AppColors.darkMaterialSurface,
          colorScheme: const ColorScheme.dark(primary: AppColors.darkPrimary, secondary: AppColors.darkAccent, surface: AppColors.darkMaterialSurface),
          appBarTheme: const AppBarTheme(backgroundColor: AppColors.darkMaterialBackground, foregroundColor: Colors.white, elevation: 0),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(bodyColor: AppColors.darkTextPrimary, displayColor: AppColors.darkTextPrimary),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.darkPrimary, foregroundColor: Colors.white),
        );
      case AppThemeMode.darkAmoled:
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.darkPrimary,
          scaffoldBackgroundColor: AppColors.amoledBackground,
          cardColor: AppColors.amoledSurface,
          colorScheme: const ColorScheme.dark(primary: AppColors.darkPrimary, secondary: AppColors.darkAccent, surface: AppColors.amoledSurface),
          appBarTheme: const AppBarTheme(backgroundColor: AppColors.amoledBackground, foregroundColor: Colors.white, elevation: 0),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(bodyColor: AppColors.darkTextPrimary, displayColor: AppColors.darkTextPrimary),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.darkPrimary, foregroundColor: Colors.white),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Password Manager',
          debugShowCheckedModeBanner: false,
          theme: _getThemeData(themeMode),
          home: const AuthScreen(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════
//  ANIMACIÓN DEL CANDADO
// ══════════════════════════════════════════════════════

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

class _LockPainter extends CustomPainter {
  final double shackleProgress;
  final double bodyScale;
  final Color lockColor;

  const _LockPainter({
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
      // Fase 1: anticipación — el arco se hunde levemente hacia abajo antes de salir
      final t = shackleProgress / anticipationEnd;
      ty = const _EaseInBackCurve().transformInternal(t) * 4;
    } else {
      // Fase 2: disparo hacia arriba con elastic overshoot
      final t = (shackleProgress - anticipationEnd) / (1 - anticipationEnd);
      final eased = const _ElasticOutCurve().transformInternal(t);
      ty  = 4 - eased * 32;   // sube 32px desde la posición de anticipación
      tx  = eased * -4;        // deriva levemente a la izquierda
      rot = eased * (-22 * pi / 180); // rota antihorario
    }

    // Geometría exacta:
    // Cuerpo: centrado en cy+8, altura 22 → tope del cuerpo en cy + 8 - 11 = cy - 3
    // Arco: radio 10, las patas (startAngle=0 y endAngle=pi) están en y = centroArco + 0
    // Para que las patas toquen el tope del cuerpo: centroArco = cy - 3
    // translate en Y = cy - 3, centro del rect en Offset(0, 0)
    canvas.save();
    canvas.translate(cx + tx, cy - 3 + ty);
    canvas.rotate(rot);
    final path = Path()
      ..addArc(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 20),
        0,    // lado derecho
        -pi,  // barre hacia arriba → U invertida cerrada
      );
    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.shackleProgress != shackleProgress || old.bodyScale != bodyScale || old.lockColor != lockColor;
}

class _AnimatedLock extends StatefulWidget {
  final bool isOpen;
  const _AnimatedLock({required this.isOpen});
  @override
  State<_AnimatedLock> createState() => _AnimatedLockState();
}

class _AnimatedLockState extends State<_AnimatedLock> with TickerProviderStateMixin {
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
  void didUpdateWidget(_AnimatedLock old) {
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
      builder: (_, __) {
        return SizedBox(
          width: 52, height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: _showCheck ? (1 - _checkAnim.value).clamp(0.0, 1.0) : 1.0,
                child: CustomPaint(
                  size: const Size(52, 56),
                  painter: _LockPainter(
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

// ══════════════════════════════════════════════════════
//  PARTÍCULAS DE FONDO
// ══════════════════════════════════════════════════════

class _Particle {
  double x, y, r, vx, vy, opacity;
  bool isPurple;
  _Particle({required this.x, required this.y, required this.r, required this.vx, required this.vy, required this.opacity, required this.isPurple});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final bool unlocked;
  _ParticlePainter(this.particles, this.unlocked);

  @override
  void paint(Canvas canvas, Size size) {
    final grad = RadialGradient(
      center: Alignment.center, radius: 1.0,
      colors: unlocked ? [const Color(0xFF082412), Colors.black] : [const Color(0xFF0A1226), Colors.black],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = grad);
    for (final p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.r,
        Paint()..color = (p.isPurple ? const Color(0xFF6366F1) : const Color(0xFF94A3B8)).withValues(alpha: p.opacity));
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ══════════════════════════════════════════════════════
//  AUTH SCREEN
// ══════════════════════════════════════════════════════

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isUnlocked       = false;
  String _authStatus     = 'Seguridad Biométrica';
  bool _statusSuccess    = false;

  late List<_Particle> _particles;
  late AnimationController _particleCtrl;
  late AnimationController _scanCtrl;
  late Animation<double>   _scanPos;
  late Animation<double>   _scanOpacity;
  late AnimationController _rippleCtrl;
  late Animation<double>   _rippleAnim;
  late AnimationController _orbitCtrl1;
  late AnimationController _orbitCtrl2;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _initParticles();

    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tickParticles)..repeat();

    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scanPos = Tween<double>(begin: 0.15, end: 0.85).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));
    _scanOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.85), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.85), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0),  weight: 10),
    ]).animate(_scanCtrl);

    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);

    _orbitCtrl1 = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _orbitCtrl2 = AnimationController(vsync: this, duration: const Duration(seconds: 11))..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 600), _authenticate);
  }

  void _initParticles() {
    _particles = List.generate(38, (_) => _Particle(
      x: _rng.nextDouble() * 400, y: _rng.nextDouble() * 800,
      r: _rng.nextDouble() * 1.1 + 0.3,
      vx: (_rng.nextDouble() - 0.5) * 0.3, vy: (_rng.nextDouble() - 0.5) * 0.3,
      opacity: _rng.nextDouble() * 0.32 + 0.07, isPurple: _rng.nextBool(),
    ));
  }

  void _tickParticles() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x += p.vx; p.y += p.vy;
        if (p.x < 0) p.x = 400; if (p.x > 400) p.x = 0;
        if (p.y < 0) p.y = 800; if (p.y > 800) p.y = 0;
      }
    });
  }

  Future<void> _authenticate() async {
    if (!mounted) return;
    setState(() { _isAuthenticating = true; _authStatus = 'Escaneando...'; });
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Verifica tu identidad para acceder',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (!mounted) return;
      if (didAuth) {
        _scanCtrl.repeat(count: 2);
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() { _isUnlocked = true; _authStatus = 'Verificando huella...'; });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        setState(() { _authStatus = 'Acceso Concedido'; _statusSuccess = true; _isAuthenticating = false; });
        _rippleCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) _navigateToHome();
      } else {
        if (!mounted) return;
        setState(() { _isAuthenticating = false; _authStatus = 'Intenta nuevamente'; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _isAuthenticating = false; _authStatus = 'Error de seguridad'; });
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => const PasswordManagerHome(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 800),
    ));
  }

  @override
  void dispose() {
    _particleCtrl.dispose(); _scanCtrl.dispose(); _rippleCtrl.dispose();
    _orbitCtrl1.dispose(); _orbitCtrl2.dispose();
    super.dispose();
  }

  Widget _buildOrbit(AnimationController ctrl, double size, bool reverse) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final angle = (reverse ? -1 : 1) * ctrl.value * 2 * pi;
        return SizedBox(width: size, height: size,
          child: Stack(alignment: Alignment.center, children: [
            Container(width: size, height: size,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1))),
            Transform.translate(
              offset: Offset((size / 2) * cos(angle), (size / 2) * sin(angle)),
              child: Container(width: 4, height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _isUnlocked ? const Color(0xFF4ADE80) : const Color(0xFF6366F1))),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildRipple(double delay) {
    return AnimatedBuilder(
      animation: _rippleAnim,
      builder: (_, __) {
        final t = (_rippleAnim.value - delay).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 + t * 1.7,
          child: Container(width: 84, height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: (1 - t) * 0.5), width: 1.5))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        CustomPaint(size: Size(size.width, size.height), painter: _ParticlePainter(_particles, _isUnlocked)),

        AnimatedBuilder(
          animation: _scanCtrl,
          builder: (_, __) {
            if (!_scanCtrl.isAnimating && _scanCtrl.value == 0) return const SizedBox.shrink();
            return Positioned(
              top: size.height * _scanPos.value, left: 0, right: 0,
              child: Opacity(opacity: _scanOpacity.value,
                child: Container(height: 1,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xFF6366F1), Colors.transparent])))),
            );
          },
        ),

        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 140, height: 140,
              child: Stack(alignment: Alignment.center, children: [
                _buildRipple(0.0), _buildRipple(0.18), _buildRipple(0.36),
                _buildOrbit(_orbitCtrl1, 108, false),
                _buildOrbit(_orbitCtrl2, 126, true),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isUnlocked ? const Color(0xFF4ADE80).withValues(alpha: 0.09) : const Color(0xFF6366F1).withValues(alpha: 0.09),
                    border: Border.all(
                      color: _isUnlocked ? const Color(0xFF4ADE80).withValues(alpha: 0.38) : const Color(0xFF6366F1).withValues(alpha: 0.28),
                      width: 1.5)),
                  child: Center(child: _AnimatedLock(isOpen: _isUnlocked)),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            Text('Password Manager', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0)),

            const SizedBox(height: 10),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 6, height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _statusSuccess ? const Color(0xFF4ADE80) : const Color(0xFF6366F1))),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: GoogleFonts.inter(fontSize: 13,
                  color: _statusSuccess ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.48)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.38))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fingerprint, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('Desbloquear', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: 0.4)),
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

// ══════════════════════════════════════════════════════
//  MODELOS
// ══════════════════════════════════════════════════════

class PasswordEntry {
  String app; String? username; String password; String? packageId;
  DateTime createdAt; DateTime? lastModified; bool isFavorite;

  PasswordEntry({required this.app, this.username, required this.password, this.packageId, required this.createdAt, this.lastModified, this.isFavorite = false});

  Map<String, dynamic> toJson() => {
    'app': app, 'username': username, 'password': password, 'packageId': packageId,
    'createdAt': createdAt.toIso8601String(), 'lastModified': lastModified?.toIso8601String(), 'isFavorite': isFavorite,
  };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
    app: json['app'], username: json['username'], password: json['password'], packageId: json['packageId'],
    createdAt: DateTime.parse(json['createdAt']),
    lastModified: json['lastModified'] != null ? DateTime.parse(json['lastModified']) : null,
    isFavorite: json['isFavorite'] ?? false,
  );
}

enum PasswordStrength { muyDebil, debil, media, fuerte, muyFuerte }

class PasswordStrengthAnalyzer {
  static PasswordStrength analyzePassword(String password) {
    if (password.isEmpty) return PasswordStrength.muyDebil;
    int score = 0;
    if (password.length >= 8)  score++;
    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score++;
    if (score <= 1) return PasswordStrength.muyDebil;
    if (score <= 2) return PasswordStrength.debil;
    if (score <= 4) return PasswordStrength.media;
    if (score <= 5) return PasswordStrength.fuerte;
    return PasswordStrength.muyFuerte;
  }

  static Color getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.muyDebil:  return Colors.redAccent;
      case PasswordStrength.debil:     return Colors.orangeAccent;
      case PasswordStrength.media:     return Colors.yellowAccent;
      case PasswordStrength.fuerte:    return Colors.lightGreenAccent;
      case PasswordStrength.muyFuerte: return Colors.greenAccent;
    }
  }
}

enum FilterType { all, recent, favorites }

// ══════════════════════════════════════════════════════
//  HOME SCREEN
// ══════════════════════════════════════════════════════

class PasswordManagerHome extends StatefulWidget {
  const PasswordManagerHome({super.key});
  @override
  State<PasswordManagerHome> createState() => _PasswordManagerHomeState();
}

class _PasswordManagerHomeState extends State<PasswordManagerHome> {
  static const platform    = MethodChannel('com.example.password_manager/storage');
  static const platformNav = MethodChannel('com.example.password_manager/autofill_nav');

  Map<String, PasswordEntry> _passwords = {};
  final Set<String> _visiblePasswords   = {};
  List<String> _filteredApps            = [];
  final TextEditingController _searchController = TextEditingController();
  FilterType _currentFilter = FilterType.all;
  static const String _storageKey = 'encrypted_passwords';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  @override
  void initState() {
    super.initState();
    _loadPasswords();
    _searchController.addListener(_filterPasswords);
    WidgetsBinding.instance.addPostFrameCallback((_) { _checkForPendingEntry(); });
  }

  Future<void> _checkForPendingEntry() async {
    try {
      final Map<dynamic, dynamic>? data = await platformNav.invokeMethod('checkPendingEntry');
      if (data != null && mounted) {
        _showSaveBottomSheet(initialApp: data['app'], initialUser: data['username'], initialPass: data['password'], initialPkg: data['packageId']);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚡ Datos capturados de ${data['app']}'),
          backgroundColor: Theme.of(context).primaryColor, duration: const Duration(seconds: 4)));
      }
    } catch (e) { debugPrint("Error checkeando intent de autofill: $e"); }
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<encrypt.Key> _getInternalKey() async {
    try {
      String? keyString = await _secureStorage.read(key: 'master_encryption_key');
      if (keyString == null || keyString.isEmpty) {
        final key = encrypt.Key.fromSecureRandom(32);
        await _secureStorage.write(key: 'master_encryption_key', value: key.base64);
        return key;
      }
      return encrypt.Key.fromBase64(keyString);
    } catch (e) {
      debugPrint("⚠️ Error llave maestra: $e");
      final key = encrypt.Key.fromSecureRandom(32);
      await _secureStorage.write(key: 'master_encryption_key', value: key.base64);
      return key;
    }
  }

  Future<String> _encryptInternal(String plainText) async {
    try {
      final key = await _getInternalKey();
      final iv  = encrypt.IV.fromSecureRandom(16);
      final enc = encrypt.Encrypter(encrypt.AES(key));
      return '${iv.base64}:${enc.encrypt(plainText, iv: iv).base64}';
    } catch (e) { debugPrint("⚠️ Error encriptando: $e"); return ''; }
  }

  Future<String> _decryptInternal(String encryptedFullString) async {
    try {
      final parts = encryptedFullString.split(':');
      if (parts.length != 2) return '';
      final iv  = encrypt.IV.fromBase64(parts[0]);
      final enc = encrypt.Encrypted.fromBase64(parts[1]);
      final key = await _getInternalKey();
      return encrypt.Encrypter(encrypt.AES(key)).decrypt(enc, iv: iv);
    } catch (e) { debugPrint("⚠️ Error desencriptando: $e"); return ''; }
  }

  encrypt.Key _deriveKeyFromPassword(String password) {
    return encrypt.Key.fromBase16(sha256.convert(utf8.encode(password)).toString());
  }

  String _encryptBackupData(String plainText, String password) {
    final key = _deriveKeyFromPassword(password);
    final iv  = encrypt.IV.fromSecureRandom(16);
    final enc = encrypt.Encrypter(encrypt.AES(key));
    return '${iv.base64}:${enc.encrypt(plainText, iv: iv).base64}';
  }

  String _decryptBackupData(String encryptedFullString, String password) {
    final parts = encryptedFullString.split(':');
    if (parts.length != 2) throw Exception('Formato inválido');
    final iv  = encrypt.IV.fromBase64(parts[0]);
    final enc = encrypt.Encrypted.fromBase64(parts[1]);
    return encrypt.Encrypter(encrypt.AES(_deriveKeyFromPassword(password))).decrypt(enc, iv: iv);
  }

  Future<void> _updateNativeVault() async {
    try {
      await platform.invokeMethod('saveVault', {'data': json.encode(_passwords.map((k, v) => MapEntry(k, v.toJson())))});
    } on PlatformException catch (e) { debugPrint("Error bóveda nativa: '${e.message}'."); }
  }

  Future<void> _loadPasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_storageKey);
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = await _decryptInternal(encryptedData);
        if (decryptedJson.isNotEmpty) {
          final Map<String, dynamic> decodedMap = json.decode(decryptedJson);
          final Map<String, PasswordEntry> loaded = {};
          decodedMap.forEach((key, value) {
            try { loaded[key] = PasswordEntry.fromJson(Map<String, dynamic>.from(value)); }
            catch (e) { debugPrint("Error parseando $key: $e"); }
          });
          if (mounted) { setState(() { _passwords = loaded; _filterPasswords(); }); _updateNativeVault(); }
        }
      }
    } catch (e, st) { debugPrint("⚠️ Error cargando contraseñas: $e\n$st"); }
  }

  Future<void> _savePasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = await _encryptInternal(json.encode(_passwords.map((k, v) => MapEntry(k, v.toJson()))));
      if (encryptedData.isNotEmpty) { await prefs.setString(_storageKey, encryptedData); await _updateNativeVault(); }
    } catch (e) { debugPrint("⚠️ Error guardando: $e"); }
  }

  void _filterPasswords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<String> tempKeys = _passwords.keys.where((appKey) {
        final entry = _passwords[appKey]!;
        final matchesText = query.isEmpty || entry.app.toLowerCase().contains(query) || (entry.username?.toLowerCase().contains(query) ?? false);
        if (_currentFilter == FilterType.favorites && !entry.isFavorite) return false;
        return matchesText;
      }).toList();
      if (_currentFilter == FilterType.recent) {
        tempKeys.sort((a, b) {
          final dateA = _passwords[a]!.lastModified ?? _passwords[a]!.createdAt;
          final dateB = _passwords[b]!.lastModified ?? _passwords[b]!.createdAt;
          return dateB.compareTo(dateA);
        });
      } else { tempKeys.sort((a, b) => a.compareTo(b)); }
      _filteredApps = tempKeys;
    });
  }

  void _toggleFavorite(String appKey) {
    setState(() { if (_passwords.containsKey(appKey)) { _passwords[appKey]!.isFavorite = !_passwords[appKey]!.isFavorite; _filterPasswords(); } });
    _savePasswords();
  }

  void _showThemeDialog() {
    HapticFeedback.lightImpact();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Apariencia"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _ThemeOption(title: "Claro", mode: AppThemeMode.light),
        _ThemeOption(title: "Gris Oscuro (Material)", mode: AppThemeMode.darkMaterial),
        _ThemeOption(title: "Negro Absoluto (AMOLED)", mode: AppThemeMode.darkAmoled),
      ]),
    ));
  }

  Future<void> _importPasswords() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.single.path != null) {
        final content = await File(result.files.single.path!).readAsString();
        if (!mounted) return;
        Map<String, dynamic> passwordsMap;
        if (content.trim().startsWith('{')) {
          try { passwordsMap = json.decode(content); } catch (e) { return; }
        } else {
          String? password = await _showBackupPasswordDialog(false);
          if (password == null) return;
          try { passwordsMap = json.decode(_decryptBackupData(content, password)); } catch (e) { return; }
        }
        Map<String, PasswordEntry> newPasswords = {};
        passwordsMap.forEach((key, value) {
          try { newPasswords[key] = PasswordEntry.fromJson(Map<String, dynamic>.from(value)); }
          catch (e) { debugPrint("Error importando $key: $e"); }
        });
        setState(() { _passwords = newPasswords; _filterPasswords(); });
        await _savePasswords();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos importados con éxito'), backgroundColor: Colors.green));
      }
    } catch (e) { debugPrint("Fallo al importar: $e"); }
  }

  Future<String?> _showBackupPasswordDialog(bool isExport) {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: Text(isExport ? 'Encriptar Backup' : 'Desencriptar Backup'),
      content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña maestra')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () { if (ctrl.text.isNotEmpty) Navigator.pop(context, ctrl.text); }, child: const Text('Aceptar')),
      ],
    ));
  }

  Future<void> _exportPasswords() async {
    if (_passwords.isEmpty) return;
    String? password = await _showBackupPasswordDialog(true);
    if (password == null) return;
    try {
      final encryptedBackup = _encryptBackupData(json.encode(_passwords.map((k, v) => MapEntry(k, v.toJson()))), password);
      final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
      await FilePicker.platform.saveFile(dialogTitle: 'Guardar backup', fileName: fileName, bytes: utf8.encode(encryptedBackup));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup guardado'), backgroundColor: Colors.green));
    } catch (e) { debugPrint("Fallo al exportar: $e"); }
  }

  void _showSaveBottomSheet({String? initialApp, String? initialUser, String? initialPass, String? initialPkg, PasswordEntry? existingEntry, String? oldKey}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PasswordEditorSheet(
          entry: existingEntry, initialApp: initialApp, initialUser: initialUser, initialPass: initialPass, initialPkg: initialPkg,
          onSave: (app, user, pass, pkg) { _savePasswordLogic(app, user, pass, pkg, oldKey: oldKey, createdAt: existingEntry?.createdAt); },
        ),
      ),
    );
  }

  void _savePasswordLogic(String app, String username, String password, String packageId, {String? oldKey, DateTime? createdAt}) async {
    if (app.isEmpty || password.isEmpty) return;
    final now = DateTime.now();
    final appKey = app.toLowerCase();
    setState(() {
      bool isFav = false;
      if (oldKey != null && oldKey != appKey) { isFav = _passwords[oldKey]?.isFavorite ?? false; _passwords.remove(oldKey); }
      else if (oldKey != null) { isFav = _passwords[oldKey]?.isFavorite ?? false; }
      _passwords[appKey] = PasswordEntry(
        app: app, username: username.isEmpty ? null : username, password: password,
        packageId: packageId.isEmpty ? null : packageId,
        createdAt: createdAt ?? now, lastModified: oldKey != null ? now : null, isFavorite: isFav);
      _filterPasswords();
    });
    await _savePasswords();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado Seguro'), backgroundColor: Colors.green));
  }

  void _deletePassword(String appKey) {
    setState(() { _passwords.remove(appKey); _visiblePasswords.remove(appKey); _filterPasswords(); });
    _savePasswords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bóveda Segura", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: _showThemeDialog, tooltip: "Apariencia"),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) { if (v == 'export') _exportPasswords(); if (v == 'import') _importPasswords(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.upload_file, size: 20), SizedBox(width: 8), Text('Exportar Backup')])),
              PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.download_rounded, size: 20), SizedBox(width: 8), Text('Importar Backup')])),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Buscar contraseñas...", prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(children: [
            ActionChip(label: Text("Todas", style: TextStyle(color: _currentFilter == FilterType.all ? Colors.white : null)),
              onPressed: () => setState(() { _currentFilter = FilterType.all; _filterPasswords(); }),
              backgroundColor: _currentFilter == FilterType.all ? Theme.of(context).primaryColor : null, side: BorderSide.none),
            const SizedBox(width: 8),
            ActionChip(label: Text("Recientes", style: TextStyle(color: _currentFilter == FilterType.recent ? Colors.white : null)),
              onPressed: () => setState(() { _currentFilter = FilterType.recent; _filterPasswords(); }),
              backgroundColor: _currentFilter == FilterType.recent ? Theme.of(context).primaryColor : null, side: BorderSide.none),
            const SizedBox(width: 8),
            ActionChip(label: Text("Favoritas", style: TextStyle(color: _currentFilter == FilterType.favorites ? Colors.white : null)),
              onPressed: () => setState(() { _currentFilter = FilterType.favorites; _filterPasswords(); }),
              backgroundColor: _currentFilter == FilterType.favorites ? Theme.of(context).primaryColor : null, side: BorderSide.none),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _filteredApps.isEmpty
              ? Center(child: Text("No se encontraron resultados", style: TextStyle(color: Colors.grey.withValues(alpha: 0.8))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredApps.length,
                  itemBuilder: (_, index) {
                    final appKey = _filteredApps[index];
                    final entry  = _passwords[appKey]!;
                    return _PasswordCard(
                      entry: entry, isVisible: _visiblePasswords.contains(appKey),
                      onToggleVisibility: () => setState(() {
                        if (_visiblePasswords.contains(appKey)) _visiblePasswords.remove(appKey);
                        else _visiblePasswords.add(appKey);
                      }),
                      onToggleFavorite: () => _toggleFavorite(appKey),
                      onEdit: () => _showSaveBottomSheet(existingEntry: entry, oldKey: appKey),
                      onDelete: () => _deletePassword(appKey),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSaveBottomSheet(),
        icon: const Icon(Icons.add),
        label: const Text("Nueva", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  PASSWORD CARD
// ══════════════════════════════════════════════════════

class _PasswordCard extends StatelessWidget {
  final PasswordEntry entry; final bool isVisible;
  final VoidCallback onToggleVisibility, onToggleFavorite, onEdit, onDelete;

  const _PasswordCard({required this.entry, required this.isVisible, required this.onToggleVisibility, required this.onToggleFavorite, required this.onEdit, required this.onDelete});

  Color _getAvatarColor(String appName) {
    final colors = [Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent, Colors.tealAccent, Colors.indigoAccent];
    return colors[appName.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(entry.app);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: avatarColor.withValues(alpha: 0.15), foregroundColor: avatarColor, radius: 24,
          child: Text(entry.app.isNotEmpty ? entry.app[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20))),
        title: Row(children: [
          Flexible(child: Text(entry.app, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          if (entry.isFavorite) ...[const SizedBox(width: 6), const Icon(Icons.star_rounded, color: Colors.amber, size: 16)],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (entry.username != null && entry.username!.isNotEmpty) Text(entry.username!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(isVisible ? entry.password : '••••••••', style: GoogleFonts.sourceCodePro(color: isVisible ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: onToggleVisibility),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'favorite') { onToggleFavorite(); HapticFeedback.selectionClick(); }
              if (val == 'edit') onEdit();
              if (val == 'copy_pass') { Clipboard.setData(ClipboardData(text: entry.password)); HapticFeedback.mediumImpact(); }
              if (val == 'copy_user' && entry.username != null) { Clipboard.setData(ClipboardData(text: entry.username!)); HapticFeedback.mediumImpact(); }
              if (val == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'favorite', child: Row(children: [Icon(entry.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded, color: Colors.amber, size: 18), const SizedBox(width: 8), Text(entry.isFavorite ? 'Quitar de Favoritos' : 'Hacer Favorito')])),
              const PopupMenuDivider(),
              if (entry.username != null && entry.username!.isNotEmpty)
                const PopupMenuItem(value: 'copy_user', child: Row(children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 8), Text('Copiar Usuario')])),
              const PopupMenuItem(value: 'copy_pass', child: Row(children: [Icon(Icons.lock_outline, size: 18), SizedBox(width: 8), Text('Copiar Password')])),
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  THEME OPTION
// ══════════════════════════════════════════════════════

class _ThemeOption extends StatelessWidget {
  final String title; final AppThemeMode mode;
  const _ThemeOption({required this.title, required this.mode});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<AppThemeMode>(
      title: Text(title), value: mode, groupValue: appThemeNotifier.value,
      activeColor: Theme.of(context).primaryColor,
      onChanged: (val) async {
        if (val != null) {
          final navigator = Navigator.of(context);
          appThemeNotifier.value = val;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('theme_mode', AppThemeMode.values.indexOf(val));
          navigator.pop();
        }
      },
    );
  }
}

// ══════════════════════════════════════════════════════
//  PASSWORD EDITOR SHEET
// ══════════════════════════════════════════════════════

class PasswordEditorSheet extends StatefulWidget {
  final PasswordEntry? entry;
  final String? initialApp, initialUser, initialPass, initialPkg;
  final Function(String, String, String, String) onSave;

  const PasswordEditorSheet({super.key, this.entry, this.initialApp, this.initialUser, this.initialPass, this.initialPkg, required this.onSave});

  @override
  State<PasswordEditorSheet> createState() => _PasswordEditorSheetState();
}

class _PasswordEditorSheetState extends State<PasswordEditorSheet> {
  bool _obscurePassword = true, _showAdvanced = false;
  late TextEditingController _appController, _userController, _passController, _pkgController;

  @override
  void initState() {
    super.initState();
    _appController  = TextEditingController(text: widget.initialApp  ?? widget.entry?.app      ?? "");
    _userController = TextEditingController(text: widget.initialUser ?? widget.entry?.username  ?? "");
    _passController = TextEditingController(text: widget.initialPass ?? widget.entry?.password  ?? "");
    _pkgController  = TextEditingController(text: widget.initialPkg  ?? widget.entry?.packageId ?? "");
    if (_pkgController.text.isNotEmpty) _showAdvanced = true;
  }

  void _generatePassword() {
    HapticFeedback.lightImpact();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final rnd = Random.secure();
    setState(() {
      _passController.text = String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
      _obscurePassword = false;
    });
  }

  @override
  void dispose() { _appController.dispose(); _userController.dispose(); _passController.dispose(); _pkgController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final strength      = PasswordStrengthAnalyzer.analyzePassword(_passController.text);
    final strengthColor = PasswordStrengthAnalyzer.getStrengthColor(strength);
    final strengthValue = _passController.text.isEmpty ? 0.0 : strength.index / 4;

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24.0),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.entry == null ? "Nueva Contraseña" : "Editar Contraseña", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 20),
        TextField(controller: _appController, decoration: InputDecoration(labelText: "Sitio Web / Aplicación", filled: true, fillColor: Theme.of(context).cardColor, prefixIcon: const Icon(Icons.apps), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        TextField(controller: _userController, decoration: InputDecoration(labelText: "Usuario o Correo", filled: true, fillColor: Theme.of(context).cardColor, prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        TextField(
          controller: _passController, obscureText: _obscurePassword, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: "Contraseña", filled: true, fillColor: Theme.of(context).cardColor, prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.autorenew), onPressed: _generatePassword, tooltip: "Generar Segura"),
              IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
            ]),
          ),
        ),
        if (_passController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LinearProgressIndicator(value: strengthValue, backgroundColor: Colors.grey.withValues(alpha: 0.2), valueColor: AlwaysStoppedAnimation<Color>(strengthColor), borderRadius: BorderRadius.circular(10), minHeight: 6)),
            const SizedBox(width: 12),
            Text(strength.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: strengthColor)),
          ]),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(children: [
            Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
            const SizedBox(width: 4),
            const Text('Avanzado (Package ID)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
        if (_showAdvanced) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextField(controller: _pkgController, style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(labelText: 'com.ejemplo.app', filled: true, fillColor: Theme.of(context).cardColor, prefixIcon: const Icon(Icons.android, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            onPressed: () { HapticFeedback.mediumImpact(); widget.onSave(_appController.text, _userController.text, _passController.text, _pkgController.text); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text("Guardar en Bóveda", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}