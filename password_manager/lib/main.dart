import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Importante para debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

// --- GESTIÓN GLOBAL DE TEMA ---
enum AppThemeMode { light, darkMaterial, darkAmoled }
final ValueNotifier<AppThemeMode> appThemeNotifier = ValueNotifier(AppThemeMode.darkAmoled);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode') ?? 2; // AMOLED por defecto
  appThemeNotifier.value = AppThemeMode.values[themeIndex];

  runApp(const MyApp());
}

class AppColors {
  static const Color lightBackground = Color(0xFFF2F4F8);
  static const Color lightSurface = Colors.white;
  static const Color lightPrimary = Color(0xFF4F46E5);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  
  static const Color darkMaterialBackground = Color(0xFF121212);
  static const Color darkMaterialSurface = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF6366F1);
  static const Color darkAccent = Color(0xFF00E5FF);
  
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
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
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _iconController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    Future.delayed(const Duration(milliseconds: 500), _authenticateWithBiometrics);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() { _isAuthenticating = true; _authStatus = 'Escaneando...'; });
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Verifica tu identidad para acceder',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (didAuthenticate) {
        setState(() { _isUnlocked = true; _authStatus = 'Acceso Concedido'; _isAuthenticating = false; });
        _iconController.forward();
        await Future.delayed(const Duration(milliseconds: 800));
        _navigateToHome();
      } else {
        setState(() { _isAuthenticating = false; _authStatus = 'Intenta nuevamente'; });
      }
    } catch (e) {
      setState(() { _isAuthenticating = false; _authStatus = 'Error de seguridad'; });
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const PasswordManagerHome(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 800),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)]),
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
                    boxShadow: [BoxShadow(color: _isUnlocked ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) => Icon(_isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 60, color: _isUnlocked ? Colors.greenAccent : Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text('Password Manager', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text(_authStatus, style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 60),
              if (!_isUnlocked && !_isAuthenticating)
                ElevatedButton.icon(onPressed: _authenticateWithBiometrics, icon: const Icon(Icons.fingerprint), label: const Text('Desbloquear')),
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
  String? packageId;
  DateTime createdAt;
  DateTime? lastModified;
  bool isFavorite;

  PasswordEntry({
    required this.app, 
    this.username, 
    required this.password, 
    this.packageId, 
    required this.createdAt, 
    this.lastModified,
    this.isFavorite = false
  });
  
  Map<String, dynamic> toJson() => {
    'app': app, 'username': username, 'password': password, 'packageId': packageId, 
    'createdAt': createdAt.toIso8601String(), 'lastModified': lastModified?.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
    app: json['app'], username: json['username'], password: json['password'], packageId: json['packageId'],
    createdAt: DateTime.parse(json['createdAt']), lastModified: json['lastModified'] != null ? DateTime.parse(json['lastModified']) : null,
    isFavorite: json['isFavorite'] ?? false, 
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

enum FilterType { all, recent, favorites }

// --- HOME SCREEN ---
class PasswordManagerHome extends StatefulWidget {
  const PasswordManagerHome({super.key});

  @override
  State<PasswordManagerHome> createState() => _PasswordManagerHomeState();
}

class _PasswordManagerHomeState extends State<PasswordManagerHome> {
  static const platform = MethodChannel('com.example.password_manager/storage');
  static const platformNav = MethodChannel('com.example.password_manager/autofill_nav');

  Map<String, PasswordEntry> _passwords = {};
  final Set<String> _visiblePasswords = {};
  List<String> _filteredApps = [];
  
  final TextEditingController _searchController = TextEditingController();
  FilterType _currentFilter = FilterType.all; 
  
  static const String _storageKey = 'encrypted_passwords';
  
  // FIX CRÍTICO 1: AndroidOptions fuerza a que el KeyStore guarde la llave permanentemente en Android.
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
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
        _showSaveBottomSheet(
          initialApp: data['app'],
          initialUser: data['username'],
          initialPass: data['password'],
          initialPkg: data['packageId'],
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚡ Datos capturados de ${data['app']}'), backgroundColor: Theme.of(context).primaryColor, duration: const Duration(seconds: 4)));
      }
    } catch (e) { 
      debugPrint("Error checkeando intent de autofill: $e"); 
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE SEGURIDAD ---
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
      debugPrint("⚠️ Error al obtener la llave maestra del SecureStorage: $e");
      // Recreamos la llave si el SecureStorage sufrió corrupción (ej. reseteo del SO)
      final key = encrypt.Key.fromSecureRandom(32);
      await _secureStorage.write(key: 'master_encryption_key', value: key.base64);
      return key;
    }
  }

  Future<String> _encryptInternal(String plainText) async {
    try {
      final key = await _getInternalKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint("⚠️ Error enciprtando datos: $e");
      return '';
    }
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
    } catch (e) { 
      // El error típico pasa aquí si la llave se borró
      debugPrint("⚠️ Error desencriptando datos (Posible pérdida de KeyStore): $e"); 
      return ''; 
    }
  }

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

  Future<void> _updateNativeVault() async {
    try {
      final passwordsMap = _passwords.map((key, value) => MapEntry(key, value.toJson()));
      final String jsonString = json.encode(passwordsMap);
      await platform.invokeMethod('saveVault', {'data': jsonString});
    } on PlatformException catch (e) { 
      debugPrint("Error al guardar en bóveda nativa: '${e.message}'."); 
    }
  }

  // FIX CRÍTICO 2: Análisis seguro del JSON para evitar que la app tire un error de tipo 'Dynamic' silenciosamente
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
            try {
              // Obligamos a que el value sea interpretado como un Map<String, dynamic> seguro
              loaded[key] = PasswordEntry.fromJson(Map<String, dynamic>.from(value));
            } catch (e) {
              debugPrint("Error parseando la contraseña $key: $e");
            }
          });

          if (mounted) {
            setState(() {
              _passwords = loaded;
              _filterPasswords();
            });
            _updateNativeVault();
          }
        } else {
          debugPrint("No se pudieron desencriptar los datos (Vacío o Llave errónea).");
        }
      }
    } catch (e, stacktrace) { 
      debugPrint("⚠️ Fallo Crítico cargando contraseñas: $e\n$stacktrace"); 
    }
  }

  Future<void> _savePasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsMap = _passwords.map((key, value) => MapEntry(key, value.toJson()));
      final jsonString = json.encode(passwordsMap);
      final encryptedData = await _encryptInternal(jsonString);
      
      if (encryptedData.isNotEmpty) {
        await prefs.setString(_storageKey, encryptedData);
        await _updateNativeVault();
        debugPrint("Contraseñas guardadas con éxito.");
      }
    } catch (e) {
      debugPrint("⚠️ Error intentando guardar: $e");
    }
  }

  void _filterPasswords() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      List<String> tempKeys = _passwords.keys.where((appKey) {
         final entry = _passwords[appKey]!;
         final matchesText = query.isEmpty || entry.app.toLowerCase().contains(query) || (entry.username?.toLowerCase().contains(query) ?? false);
         
         if (_currentFilter == FilterType.favorites && !entry.isFavorite) {
           return false;
         }
         return matchesText;
      }).toList();

      if (_currentFilter == FilterType.recent) {
        tempKeys.sort((a, b) {
          final dateA = _passwords[a]!.lastModified ?? _passwords[a]!.createdAt;
          final dateB = _passwords[b]!.lastModified ?? _passwords[b]!.createdAt;
          return dateB.compareTo(dateA); 
        });
      } else {
        tempKeys.sort((a, b) => a.compareTo(b)); 
      }

      _filteredApps = tempKeys;
    });
  }

  void _toggleFavorite(String appKey) {
    setState(() {
      if (_passwords.containsKey(appKey)) {
        _passwords[appKey]!.isFavorite = !_passwords[appKey]!.isFavorite;
        _filterPasswords();
      }
    });
    _savePasswords();
  }

  // --- SELECCIÓN DE TEMAS ---
  void _showThemeDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Apariencia"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(title: "Claro", mode: AppThemeMode.light),
            _ThemeOption(title: "Gris Oscuro (Material)", mode: AppThemeMode.darkMaterial),
            _ThemeOption(title: "Negro Absoluto (AMOLED)", mode: AppThemeMode.darkAmoled),
          ],
        ),
      ),
    );
  }

  // --- RESPALDOS ---
  Future<void> _importPasswords() async {
     try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        if (!mounted) return;
        Map<String, dynamic> passwordsMap;
        if (content.trim().startsWith('{')) {
          try { passwordsMap = json.decode(content); } catch(e) { return; }
        } else {
          String? password = await _showBackupPasswordDialog(false);
          if (password == null) return;
          try {
            String jsonString = _decryptBackupData(content, password);
            passwordsMap = json.decode(jsonString);
          } catch (e) { return; }
        }
        
        // Importación segura con try/catch en el parseo
        Map<String, PasswordEntry> newPasswords = {};
        passwordsMap.forEach((key, value) { 
          try {
            newPasswords[key] = PasswordEntry.fromJson(Map<String, dynamic>.from(value)); 
          } catch (e) { debugPrint("Error importando $key: $e"); }
        });
        
        setState(() { _passwords = newPasswords; _filterPasswords(); });
        await _savePasswords();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos importados con éxito'), backgroundColor: Colors.green));
      }
    } catch (e) { debugPrint("Fallo al importar: $e"); }
  }

  Future<String?> _showBackupPasswordDialog(bool isExport) {
    TextEditingController passCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isExport ? 'Encriptar Backup' : 'Desencriptar Backup'),
        content: TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña maestra')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () { if (passCtrl.text.isNotEmpty) Navigator.pop(context, passCtrl.text); }, child: const Text('Aceptar')),
        ],
      ),
    );
  }

  Future<void> _exportPasswords() async {
    if (_passwords.isEmpty) return;
    String? password = await _showBackupPasswordDialog(true);
    if (password == null) return;
    try {
      final passwordsMap = _passwords.map((key, value) => MapEntry(key, value.toJson()));
      final encryptedBackup = _encryptBackupData(json.encode(passwordsMap), password);
      final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
      await FilePicker.platform.saveFile(dialogTitle: 'Guardar backup', fileName: fileName, bytes: utf8.encode(encryptedBackup));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup guardado'), backgroundColor: Colors.green));
    } catch (e) { debugPrint("Fallo al exportar: $e"); }
  }

  void _showSaveBottomSheet({String? initialApp, String? initialUser, String? initialPass, String? initialPkg, PasswordEntry? existingEntry, String? oldKey}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PasswordEditorSheet(
          entry: existingEntry,
          initialApp: initialApp, initialUser: initialUser, initialPass: initialPass, initialPkg: initialPkg,
          onSave: (app, user, pass, pkg) {
            _savePasswordLogic(app, user, pass, pkg, oldKey: oldKey, createdAt: existingEntry?.createdAt);
          },
        ),
      ),
    );
  }

  void _savePasswordLogic(String app, String username, String password, String packageId, {String? oldKey, DateTime? createdAt}) async {
    if (app.isEmpty || password.isEmpty) return;
    
    DateTime now = DateTime.now();
    String appKey = app.toLowerCase();
    
    setState(() {
      bool isFav = false; 
      if (oldKey != null && oldKey != appKey) {
        isFav = _passwords[oldKey]?.isFavorite ?? false;
        _passwords.remove(oldKey);
      } else if (oldKey != null) {
        isFav = _passwords[oldKey]?.isFavorite ?? false;
      }
      
      _passwords[appKey] = PasswordEntry(
        app: app, 
        username: username.isEmpty ? null : username, 
        password: password, 
        packageId: packageId.isEmpty ? null : packageId,
        createdAt: createdAt ?? now, 
        lastModified: oldKey != null ? now : null,
        isFavorite: isFav 
      );
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

  // --- WIDGETS UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bóveda Segura", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: _showThemeDialog, tooltip: "Apariencia"),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) { if(v=='export') _exportPasswords(); if(v=='import') _importPasswords(); }, 
            itemBuilder: (c) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'export', child: Row(children: [Icon(Icons.upload_file, size: 20), SizedBox(width: 8), Text('Exportar Backup')])), 
              const PopupMenuItem<String>(value: 'import', child: Row(children: [Icon(Icons.download_rounded, size: 20), SizedBox(width: 8), Text('Importar Backup')]))
            ]
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar contraseñas...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ActionChip(
                  label: Text("Todas", style: TextStyle(color: _currentFilter == FilterType.all ? Colors.white : null)), 
                  onPressed: () => setState(() { _currentFilter = FilterType.all; _filterPasswords(); }), 
                  backgroundColor: _currentFilter == FilterType.all ? Theme.of(context).primaryColor : null, 
                  side: BorderSide.none
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text("Recientes", style: TextStyle(color: _currentFilter == FilterType.recent ? Colors.white : null)), 
                  onPressed: () => setState(() { _currentFilter = FilterType.recent; _filterPasswords(); }), 
                  backgroundColor: _currentFilter == FilterType.recent ? Theme.of(context).primaryColor : null, 
                  side: BorderSide.none
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text("Favoritas", style: TextStyle(color: _currentFilter == FilterType.favorites ? Colors.white : null)), 
                  onPressed: () => setState(() { _currentFilter = FilterType.favorites; _filterPasswords(); }), 
                  backgroundColor: _currentFilter == FilterType.favorites ? Theme.of(context).primaryColor : null, 
                  side: BorderSide.none
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _filteredApps.isEmpty 
              ? Center(child: Text("No se encontraron resultados", style: TextStyle(color: Colors.grey.withValues(alpha: 0.8))))
              : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _filteredApps.length,
              itemBuilder: (context, index) {
                final appKey = _filteredApps[index];
                final entry = _passwords[appKey]!;
                return _PasswordCard(
                  entry: entry, 
                  isVisible: _visiblePasswords.contains(appKey), 
                  onToggleVisibility: () => setState(() { if(_visiblePasswords.contains(appKey)) {
                    _visiblePasswords.remove(appKey);
                  } else {
                    _visiblePasswords.add(appKey);
                  } }),
                  onToggleFavorite: () => _toggleFavorite(appKey), 
                  onEdit: () => _showSaveBottomSheet(existingEntry: entry, oldKey: appKey),
                  onDelete: () => _deletePassword(appKey)
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSaveBottomSheet(),
        icon: const Icon(Icons.add),
        label: const Text("Nueva", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  final PasswordEntry entry;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PasswordCard({
    required this.entry, 
    required this.isVisible, 
    required this.onToggleVisibility, 
    required this.onToggleFavorite, 
    required this.onEdit, 
    required this.onDelete
  });

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
        leading: CircleAvatar(
          backgroundColor: avatarColor.withValues(alpha: 0.15),
          foregroundColor: avatarColor,
          radius: 24,
          child: Text(entry.app.isNotEmpty ? entry.app[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
        ),
        title: Row(
          children: [
            Flexible(child: Text(entry.app, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (entry.isFavorite) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            ]
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.username != null && entry.username!.isNotEmpty) 
              Text(entry.username!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(isVisible ? entry.password : '••••••••', style: GoogleFonts.sourceCodePro(color: isVisible ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'favorite', child: Row(children: [Icon(entry.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded, color: Colors.amber, size: 18), const SizedBox(width: 8), Text(entry.isFavorite ? 'Quitar de Favoritos' : 'Hacer Favorito')])),
                const PopupMenuDivider(),
                if (entry.username != null && entry.username!.isNotEmpty)
                  const PopupMenuItem<String>(value: 'copy_user', child: Row(children: [Icon(Icons.person_outline, size: 18), SizedBox(width: 8), Text('Copiar Usuario')])),
                const PopupMenuItem<String>(value: 'copy_pass', child: Row(children: [Icon(Icons.lock_outline, size: 18), SizedBox(width: 8), Text('Copiar Password')])),
                const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final AppThemeMode mode;
  const _ThemeOption({required this.title, required this.mode});

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return RadioListTile<AppThemeMode>(
      title: Text(title),
      value: mode,
      // ignore: deprecated_member_use
      groupValue: appThemeNotifier.value,
      activeColor: Theme.of(context).primaryColor,
      // ignore: deprecated_member_use
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

class PasswordEditorSheet extends StatefulWidget {
  final PasswordEntry? entry;
  final String? initialApp;
  final String? initialUser;
  final String? initialPass;
  final String? initialPkg;
  final Function(String, String, String, String) onSave;

  const PasswordEditorSheet({super.key, this.entry, this.initialApp, this.initialUser, this.initialPass, this.initialPkg, required this.onSave});

  @override
  State<PasswordEditorSheet> createState() => _PasswordEditorSheetState();
}

class _PasswordEditorSheetState extends State<PasswordEditorSheet> {
  bool _obscurePassword = true;
  bool _showAdvanced = false;
  late TextEditingController _appController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _pkgController;

  @override
  void initState() {
    super.initState();
    _appController = TextEditingController(text: widget.initialApp ?? widget.entry?.app ?? "");
    _userController = TextEditingController(text: widget.initialUser ?? widget.entry?.username ?? "");
    _passController = TextEditingController(text: widget.initialPass ?? widget.entry?.password ?? "");
    _pkgController = TextEditingController(text: widget.initialPkg ?? widget.entry?.packageId ?? "");
    
    if (_pkgController.text.isNotEmpty) _showAdvanced = true;
  }

  void _generatePassword() {
    HapticFeedback.lightImpact();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final rnd = Random.secure();
    final newPass = String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    setState(() {
      _passController.text = newPass;
      _obscurePassword = false;
    });
  }

  @override
  void dispose() {
    _appController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pkgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthAnalyzer.analyzePassword(_passController.text);
    final strengthColor = PasswordStrengthAnalyzer.getStrengthColor(strength);
    double strengthValue = strength.index / 4;
    if (_passController.text.isEmpty) strengthValue = 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.entry == null ? "Nueva Contraseña" : "Editar Contraseña", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          
          TextField(controller: _appController, decoration: InputDecoration(labelText: "Sitio Web / Aplicación", filled: true, fillColor: Theme.of(context).cardColor, prefixIcon: const Icon(Icons.apps), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          
          TextField(controller: _userController, decoration: InputDecoration(labelText: "Usuario o Correo", filled: true, fillColor: Theme.of(context).cardColor, prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          
          TextField(
            controller: _passController,
            obscureText: _obscurePassword,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              labelText: "Contraseña",
              filled: true,
              fillColor: Theme.of(context).cardColor,
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.autorenew), onPressed: _generatePassword, tooltip: "Generar Segura"),
                  IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ],
              ),
            ),
          ),
          
          if (_passController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: strengthValue,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 12),
                Text(strength.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: strengthColor)),
              ],
            ),
          ],

          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              children: [
                Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                const Text('Avanzado (Package ID)', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (_showAdvanced)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _pkgController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'com.ejemplo.app',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  prefixIcon: const Icon(Icons.android, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onSave(_appController.text, _userController.text, _passController.text, _pkgController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Guardar en Bóveda", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}