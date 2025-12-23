import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt; // Encriptación AES
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Keystore
import 'package:crypto/crypto.dart'; // Para hashear la contraseña
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bloquear orientación vertical
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class AppColors {
  static const Color lightBackground = Color(0xFFF2F4F8);
  static const Color lightSurface = Colors.white;
  static const Color lightPrimary = Color(0xFF4F46E5);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkPrimary = Color(0xFF6366F1);
  static const Color darkAccent = Color(0xFF00E5FF);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    return MaterialApp(
      title: 'Password Manager',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBackground,
        primaryColor: AppColors.lightPrimary,
        colorScheme: const ColorScheme.light(
          primary: AppColors.lightPrimary,
          secondary: Colors.tealAccent,
          surface: AppColors.lightSurface,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: AppColors.lightSurface,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
          bodyColor: AppColors.lightTextPrimary,
          displayColor: AppColors.lightTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        primaryColor: AppColors.darkPrimary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.darkPrimary,
          secondary: AppColors.darkAccent,
          surface: AppColors.darkSurface,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
          ),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: AppColors.darkTextPrimary,
          displayColor: AppColors.darkTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// --- AUTH SCREEN ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _authStatus = 'Seguridad Biométrica';
  bool _isUnlocked = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 500), _authenticateWithBiometrics);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _authStatus = 'Escaneando...';
    });

    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Verifica tu identidad para acceder',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        setState(() {
          _isUnlocked = true;
          _authStatus = 'Acceso Concedido';
          _isAuthenticating = false;
        });
        _iconController.forward();
        await Future.delayed(const Duration(milliseconds: 800));
        _navigateToHome();
      } else {
        setState(() {
          _isAuthenticating = false;
          _authStatus = 'Intenta nuevamente';
        });
      }
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _authStatus = 'Error de seguridad';
      });
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PasswordManagerHome(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          var curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
          var offsetAnimation = Tween(begin: begin, end: end).animate(curvedAnimation);
          return FadeTransition(opacity: animation, child: SlideTransition(position: offsetAnimation, child: child));
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _isUnlocked ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.blueAccent.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      return Icon(
                        _isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 60,
                        color: _isUnlocked ? Colors.greenAccent : Colors.white,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Password Manager', 
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _authStatus,
                  key: ValueKey<String>(_authStatus),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              if (!_isUnlocked && !_isAuthenticating)
                ElevatedButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
               if (_isAuthenticating)
                 const SizedBox(
                   width: 24, 
                   height: 24, 
                   child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                 ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MODELOS ---
class PasswordEntry {
  String app;
  String? username;
  String password;
  DateTime createdAt;
  DateTime? lastModified;

  PasswordEntry({
    required this.app,
    this.username,
    required this.password,
    required this.createdAt,
    this.lastModified,
  });
  
  Map<String, dynamic> toJson() => {
    'app': app,
    'username': username,
    'password': password,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
  };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
    app: json['app'],
    username: json['username'],
    password: json['password'],
    createdAt: DateTime.parse(json['createdAt']),
    lastModified: json['lastModified'] != null ? DateTime.parse(json['lastModified']) : null,
  );
}

enum PasswordStrength { muyDebil, debil, media, fuerte, muyFuerte }

class PasswordStrengthAnalyzer {
  static PasswordStrength analyzePassword(String password) {
    if (password.isEmpty) return PasswordStrength.muyDebil;
    int score = 0;
    if (password.length >= 8) score++;
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
      case PasswordStrength.muyDebil: return Colors.redAccent;
      case PasswordStrength.debil: return Colors.orangeAccent;
      case PasswordStrength.media: return Colors.yellowAccent;
      case PasswordStrength.fuerte: return Colors.lightGreenAccent;
      case PasswordStrength.muyFuerte: return Colors.greenAccent;
    }
  }
}

// --- HOME SCREEN ---
class PasswordManagerHome extends StatefulWidget {
  const PasswordManagerHome({super.key});

  @override
  State<PasswordManagerHome> createState() => _PasswordManagerHomeState();
}

class _PasswordManagerHomeState extends State<PasswordManagerHome> {
  Map<String, PasswordEntry> _passwords = {};
  final Set<String> _visiblePasswords = {};
  List<String> _filteredApps = [];
  
  final TextEditingController _appController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _editingApp;
  bool _isPasswordObscured = true;
  bool _isDarkMode = false;

  static const String _storageKey = 'encrypted_passwords';
  static const String _themeKey = 'is_dark_mode';
  final _secureStorage = const FlutterSecureStorage();
  
  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadPasswords();
    _searchController.addListener(_filterPasswords);
  }

  @override
  void dispose() {
    _appController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE SEGURIDAD INTERNA (AES-256) ---
  Future<encrypt.Key> _getInternalKey() async {
    String? keyString = await _secureStorage.read(key: 'master_encryption_key');
    if (keyString == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      await _secureStorage.write(key: 'master_encryption_key', value: key.base64);
      return key;
    }
    return encrypt.Key.fromBase64(keyString);
  }

  Future<String> _encryptInternal(String plainText) async {
    final key = await _getInternalKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> _decryptInternal(String encryptedFullString) async {
    try {
      final parts = encryptedFullString.split(':');
      if (parts.length != 2) return '';
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      final key = await _getInternalKey();
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) { return ''; }
  }

  // --- LÓGICA DE SEGURIDAD BACKUP (Contraseña Usuario) ---
  encrypt.Key _deriveKeyFromPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return encrypt.Key.fromBase16(digest.toString());
  }

  String _encryptBackupData(String plainText, String password) {
    final key = _deriveKeyFromPassword(password);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String _decryptBackupData(String encryptedFullString, String password) {
    final parts = encryptedFullString.split(':');
    if (parts.length != 2) throw Exception('Formato inválido');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = _deriveKeyFromPassword(password);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  // --- CARGA Y GUARDADO ---
  Future<void> _loadPasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_storageKey);
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = await _decryptInternal(encryptedData);
        if (decryptedJson.isNotEmpty) {
          final Map<String, dynamic> passwordsMap = json.decode(decryptedJson);
          if (mounted) {
            setState(() {
              _passwords = Map.from(passwordsMap.map((key, value) => MapEntry(key, PasswordEntry.fromJson(value))));
              _filterPasswords();
            });
          }
        }
      }
    } catch (e) { /* Fallo silencioso */ }
  }

  Future<void> _savePasswords() async {
    final prefs = await SharedPreferences.getInstance();
    final passwordsMap = _passwords.map((key, value) => MapEntry(key, value.toJson()));
    final jsonString = json.encode(passwordsMap);
    final encryptedData = await _encryptInternal(jsonString);
    await prefs.setString(_storageKey, encryptedData);
  }

  void _filterPasswords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _passwords.keys.toList();
      } else {
        _filteredApps = _passwords.keys.where((app) {
           final entry = _passwords[app]!;
           final matchesApp = entry.app.toLowerCase().contains(query);
           final matchesUser = entry.username?.toLowerCase().contains(query) ?? false;
           return matchesApp || matchesUser;
        }).toList();
      }
      _filteredApps.sort((a, b) => a.compareTo(b));
    });
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
    });
  }

  void _toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  // --- IMPORTAR (INTELIGENTE: SOPORTA LEGACY Y NUEVO) ---
  Future<void> _importPasswords() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        if (!mounted) return;

        Map<String, dynamic> passwordsMap;

        // DETECCIÓN INTELIGENTE:
        // Si el archivo empieza con '{', es el formato antiguo (TU ARCHIVO ACTUAL)
        if (content.trim().startsWith('{')) {
          try {
            passwordsMap = json.decode(content);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato antiguo detectado: Asegurando datos...'), backgroundColor: Colors.blue));
          } catch(e) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: El archivo está dañado'), backgroundColor: Colors.red));
             return;
          }
        } else {
          // Si NO empieza con '{', asumimos que es el nuevo formato encriptado
          String? password = await _showBackupPasswordDialog(false);
          if (password == null) return;

          try {
            String jsonString = _decryptBackupData(content, password);
            passwordsMap = json.decode(jsonString);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña incorrecta o archivo dañado'), backgroundColor: Colors.red));
            return;
          }
        }
        
        // Procesar los datos (igual para ambos casos)
        Map<String, PasswordEntry> newPasswords = {};
        passwordsMap.forEach((key, value) {
          newPasswords[key] = PasswordEntry.fromJson(value);
        });

        setState(() {
          _passwords = newPasswords;
          _filterPasswords();
        });
        await _savePasswords(); // Se guarda AUTOMÁTICAMENTE encriptado en el teléfono
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos importados y asegurados con éxito'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al leer el archivo'), backgroundColor: Colors.red));
    }
  }

  // --- RESTO DE FUNCIONES (Exportar, Dialogos, Generador...) ---
  
  Future<String?> _showBackupPasswordDialog(bool isExport) {
    TextEditingController passCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? AppColors.darkSurface : Colors.white,
        title: Text(isExport ? 'Encriptar Backup' : 'Desencriptar Backup', 
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isExport 
              ? 'Crea una contraseña para proteger este archivo.' 
              : 'Ingresa la contraseña del backup.',
              style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: _isDarkMode ? Colors.grey : Colors.grey[600]),
                filled: true,
                fillColor: _isDarkMode ? Colors.black26 : Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (passCtrl.text.isNotEmpty) Navigator.pop(context, passCtrl.text);
            },
            child: Text(isExport ? 'Exportar' : 'Restaurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPasswords() async {
    if (_passwords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay contraseñas para exportar')));
      return;
    }
    String? password = await _showBackupPasswordDialog(true);
    if (password == null) return;

    try {
      final passwordsMap = _passwords.map((key, value) => MapEntry(key, value.toJson()));
      final jsonString = json.encode(passwordsMap);
      final encryptedBackup = _encryptBackupData(jsonString, password);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'secure_backup_$timestamp.json';
      final bytes = utf8.encode(encryptedBackup);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar backup encriptado',
        fileName: fileName,
        bytes: bytes,
      );
      if (mounted && outputFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup encriptado guardado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  String _generatePassword({int length = 16, bool includeUppercase = true, bool includeLowercase = true, bool includeNumbers = true, bool includeSymbols = true}) {
    String charset = '';
    if (includeUppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (includeLowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
    if (includeNumbers) charset += '0123456789';
    if (includeSymbols) charset += r'!@#$%^&*()_+-=[]{}|;:,.<>?';
    if (charset.isEmpty) return ''; 
    Random random = Random.secure();
    return List.generate(length, (index) => charset[random.nextInt(charset.length)]).join();
  }

  void _showPasswordGeneratorDialog() {
    int length = 16;
    bool includeUppercase = true;
    bool includeLowercase = true;
    bool includeNumbers = true;
    bool includeSymbols = true;
    String generatedPassword = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = _isDarkMode;
          final Color textColor = isDark ? Colors.white : Colors.black87;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            title: Text('Generar Contraseña', style: TextStyle(color: textColor)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Center(
                      child: Text(
                        generatedPassword.isEmpty ? 'Haga clic en Generar' : generatedPassword,
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Longitud: $length', style: TextStyle(color: textColor)),
                  Slider(
                    value: length.toDouble(), min: 6, max: 32, divisions: 26, label: length.toString(),
                    onChanged: (value) => setDialogState(() => length = value.toInt()),
                  ),
                  _buildCheckbox(isDark, 'Mayúsculas (A-Z)', includeUppercase, (v) => setDialogState(() => includeUppercase = v!)),
                  _buildCheckbox(isDark, 'Minúsculas (a-z)', includeLowercase, (v) => setDialogState(() => includeLowercase = v!)),
                  _buildCheckbox(isDark, 'Números (0-9)', includeNumbers, (v) => setDialogState(() => includeNumbers = v!)),
                  _buildCheckbox(isDark, 'Símbolos (!@#)', includeSymbols, (v) => setDialogState(() => includeSymbols = v!)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  if (!includeUppercase && !includeLowercase && !includeNumbers && !includeSymbols) return;
                  setDialogState(() {
                    generatedPassword = _generatePassword(length: length, includeUppercase: includeUppercase, includeLowercase: includeLowercase, includeNumbers: includeNumbers, includeSymbols: includeSymbols);
                  });
                },
                child: const Text('Generar'),
              ),
              if (generatedPassword.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _passwordController.text = generatedPassword;
                    Navigator.pop(context);
                  },
                  child: const Text('Usar'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCheckbox(bool isDark, String title, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
      value: value, onChanged: onChanged, contentPadding: EdgeInsets.zero, activeColor: Theme.of(context).primaryColor, controlAffinity: ListTileControlAffinity.leading, dense: true,
    );
  }

  void _savePassword() async {
    String app = _appController.text.trim();
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();
    if (app.isEmpty || password.isEmpty) return;
    
    DateTime now = DateTime.now();
    String appKey = app.toLowerCase();
    setState(() {
      if (_editingApp != null) {
        String oldKey = _editingApp!.toLowerCase();
        if (oldKey != appKey) _passwords.remove(oldKey);
        _passwords[appKey] = PasswordEntry(app: app, username: username.isEmpty ? null : username, password: password, createdAt: _passwords[oldKey]?.createdAt ?? now, lastModified: now);
      } else {
        _passwords[appKey] = PasswordEntry(app: app, username: username.isEmpty ? null : username, password: password, createdAt: now);
      }
      _editingApp = null;
      _filterPasswords();
    });
    _appController.clear();
    _usernameController.clear();
    _passwordController.clear();
    FocusScope.of(context).unfocus();
    await _savePasswords();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado Seguro'), backgroundColor: Colors.green));
  }

  void _deletePassword(String appKey) {
     setState(() {
       _passwords.remove(appKey);
       _visiblePasswords.remove(appKey);
       _filterPasswords();
     });
     _savePasswords();
  }

  // --- WIDGETS UI ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: _isDarkMode ? AppColors.darkSurface : AppColors.lightPrimary,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mis Contraseñas', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('${_passwords.length} protegidas', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                ],
              ),
              Row(
                children: [
                  IconButton(icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white), onPressed: _toggleTheme),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'export') _exportPasswords();
                      if (value == 'import') _importPasswords();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'export', child: Text('Exportar Backup')),
                      const PopupMenuItem(value: 'import', child: Text('Importar Backup')),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15)),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar servicio...', hintStyle: TextStyle(color: Colors.white60), border: InputBorder.none, icon: Icon(Icons.search, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    final bool isDark = _isDarkMode;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_editingApp == null ? 'Nueva Contraseña' : 'Editar Contraseña', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppColors.lightTextPrimary)),
          const SizedBox(height: 15),
          TextField(
            controller: _appController, style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Servicio', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]), filled: true, fillColor: isDark ? Colors.black26 : Colors.grey[50],
              prefixIcon: const Icon(Icons.apps_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController, style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Usuario / Correo (Opcional)', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]), filled: true, fillColor: isDark ? Colors.black26 : Colors.grey[50],
              prefixIcon: const Icon(Icons.person_outline_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _passwordController, obscureText: _isPasswordObscured, style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  onChanged: (val) => setState((){}),
                  decoration: InputDecoration(
                    labelText: 'Contraseña', labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]), filled: true, fillColor: isDark ? Colors.black26 : Colors.grey[50],
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: IconButton(icon: Icon(Icons.tune, color: Theme.of(context).primaryColor), onPressed: _showPasswordGeneratorDialog),
              ),
            ],
          ),
          if (_passwordController.text.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 10.0),
               child: Row(
                 children: [
                   Container(
                     height: 4, width: 40,
                     decoration: BoxDecoration(color: PasswordStrengthAnalyzer.getStrengthColor(PasswordStrengthAnalyzer.analyzePassword(_passwordController.text)), borderRadius: BorderRadius.circular(2)),
                   ),
                   const SizedBox(width: 10),
                   Text('Seguridad', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey[600])),
                 ],
               ),
             ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
              ),
              child: Text(_editingApp == null ? 'Guardar en la Bóveda' : 'Actualizar Entrada'),
            ),
          ),
           if (_editingApp != null)
             TextButton(
               onPressed: () => setState(() {
                 _editingApp = null; _appController.clear(); _usernameController.clear(); _passwordController.clear();
               }),
               child: const Text('Cancelar edición', style: TextStyle(color: Colors.redAccent)),
             )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkMode ? ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.darkBackground, primaryColor: AppColors.darkPrimary, colorScheme: const ColorScheme.dark(primary: AppColors.darkPrimary, secondary: AppColors.darkAccent),
      ) : ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.lightBackground, primaryColor: AppColors.lightPrimary,
      ),
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                controller: _scrollController, padding: EdgeInsets.zero,
                children: [
                  _buildInputCard(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('Tus Credenciales', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.lightTextPrimary)),
                  ),
                  _filteredApps.isEmpty 
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.shield_outlined, size: 60, color: _isDarkMode ? Colors.white12 : Colors.black12),
                            const SizedBox(height: 10),
                            Text("Todo seguro", style: TextStyle(color: _isDarkMode ? Colors.white38 : Colors.black38)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          curve: Curves.easeOutQuad,
                          builder: (context, double val, child) {
                            return Opacity(
                              opacity: val,
                              child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
                            );
                          },
                          child: _PasswordCard(
                            entry: _passwords[_filteredApps[index]]!, appKey: _filteredApps[index], isVisible: _visiblePasswords.contains(_filteredApps[index]), isDarkMode: _isDarkMode,
                            onToggleVisibility: () => setState(() {
                              final key = _filteredApps[index]; if (_visiblePasswords.contains(key)) _visiblePasswords.remove(key); else _visiblePasswords.add(key);
                            }),
                            onEdit: () {
                              setState(() {
                                _editingApp = _filteredApps[index]; final entry = _passwords[_editingApp]!;
                                _appController.text = entry.app; _usernameController.text = entry.username ?? ''; _passwordController.text = entry.password;
                              });
                              _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                            },
                            onDelete: () => _deletePassword(_filteredApps[index]),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  final PasswordEntry entry;
  final String appKey;
  final bool isVisible;
  final bool isDarkMode;
  final VoidCallback onToggleVisibility;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PasswordCard({
    required this.entry, required this.appKey, required this.isVisible, required this.isDarkMode, required this.onToggleVisibility, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
        boxShadow: [if (!isDarkMode) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode ? [Colors.blueGrey.shade800, Colors.black] : [Colors.blue.shade50, Colors.white],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              entry.app.isNotEmpty ? entry.app[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppColors.lightPrimary),
            ),
          ),
        ),
        title: Text(entry.app, style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : AppColors.lightTextPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.username != null && entry.username!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 12, color: isDarkMode ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.username!,
                          style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                isVisible ? entry.password : '••••••••••••',
                style: GoogleFonts.sourceCodePro(
                  color: isVisible ? (isDarkMode ? Colors.greenAccent : Colors.green[700]) : (isDarkMode ? Colors.white38 : Colors.grey),
                  fontWeight: isVisible ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
              color: isDarkMode ? Colors.white54 : Colors.grey[400],
              onPressed: onToggleVisibility,
            ),
            PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded, color: isDarkMode ? Colors.white54 : Colors.grey[400]),
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'copy_pass') Clipboard.setData(ClipboardData(text: entry.password));
                if (val == 'copy_user' && entry.username != null) Clipboard.setData(ClipboardData(text: entry.username!));
                if (val == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                if (entry.username != null && entry.username!.isNotEmpty)
                   const PopupMenuItem(value: 'copy_user', child: Row(children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 8), Text('Copiar Usuario')])),
                const PopupMenuItem(value: 'copy_pass', child: Row(children: [Icon(Icons.lock_outline, size: 18), SizedBox(width: 8), Text('Copiar Password')])),
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}