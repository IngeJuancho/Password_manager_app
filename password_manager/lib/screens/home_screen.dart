import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../models/password_entry.dart';
import '../widgets/password_card.dart';
import '../widgets/password_editor_sheet.dart';
import '../widgets/theme_option.dart';
import '../theme/app_theme.dart';

enum FilterType { all, recent, favorites }

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

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  @override
  void initState() {
    super.initState();
    _loadPasswords();
    _searchController.addListener(_filterPasswords);
    
    // Escucha en tiempo real (incluso si la app estaba en segundo plano)
    platformNav.setMethodCallHandler((call) async {
      if (call.method == 'onPendingEntry') {
        final data = call.arguments;
        if (data is Map) {
          _handlePendingEntry(data);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingEntry();
    });
  }

  Future<void> _handlePendingEntry(Map<dynamic, dynamic> data) async {
    if (mounted) {
      _showSaveBottomSheet(
          initialApp: data['app']?.toString(),
          initialUser: data['username']?.toString(),
          initialPass: data['password']?.toString(),
          initialPkg: data['packageId']?.toString(),
          autoCloseApp: true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚡ Datos capturados de ${data['app']}'),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(seconds: 4)));
    }
  }

  Future<void> _checkForPendingEntry() async {
    try {
      final Map<dynamic, dynamic>? data =
          await platformNav.invokeMethod('checkPendingEntry');
      if (data != null && mounted) {
        _handlePendingEntry(data);
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
      final iv = encrypt.IV.fromSecureRandom(16);
      final enc = encrypt.Encrypter(encrypt.AES(key));
      return '${iv.base64}:${enc.encrypt(plainText, iv: iv).base64}';
    } catch (e) {
      debugPrint("⚠️ Error encriptando: $e");
      return '';
    }
  }

  Future<String> _decryptInternal(String encryptedFullString) async {
    try {
      final parts = encryptedFullString.split(':');
      if (parts.length != 2) return '';
      final iv = encrypt.IV.fromBase64(parts[0]);
      final enc = encrypt.Encrypted.fromBase64(parts[1]);
      final key = await _getInternalKey();
      return encrypt.Encrypter(encrypt.AES(key)).decrypt(enc, iv: iv);
    } catch (e) {
      debugPrint("⚠️ Error desencriptando: $e");
      return '';
    }
  }

  encrypt.Key _deriveKeyFromPassword(String password) {
    return encrypt.Key.fromBase16(
        sha256.convert(utf8.encode(password)).toString());
  }

  String _encryptBackupData(String plainText, String password) {
    final key = _deriveKeyFromPassword(password);
    final iv = encrypt.IV.fromSecureRandom(16);
    final enc = encrypt.Encrypter(encrypt.AES(key));
    return '${iv.base64}:${enc.encrypt(plainText, iv: iv).base64}';
  }

  String _decryptBackupData(String encryptedFullString, String password) {
    final parts = encryptedFullString.split(':');
    if (parts.length != 2) throw Exception('Formato inválido');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final enc = encrypt.Encrypted.fromBase64(parts[1]);
    return encrypt.Encrypter(encrypt.AES(_deriveKeyFromPassword(password)))
        .decrypt(enc, iv: iv);
  }

  Future<void> _updateNativeVault() async {
    try {
      await platform.invokeMethod('saveVault', {
        'data': json.encode(
            _passwords.map((k, v) => MapEntry(k, v.toJson())))
      });
    } on PlatformException catch (e) {
      debugPrint("Error bóveda nativa: '${e.message}'.");
    }
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
            try {
              loaded[key] = PasswordEntry.fromJson(
                  Map<String, dynamic>.from(value));
            } catch (e) {
              debugPrint("Error parseando $key: $e");
            }
          });
          if (mounted) {
            setState(() {
              _passwords = loaded;
              _filterPasswords();
            });
            _updateNativeVault();
          }
        }
      }
    } catch (e, st) {
      debugPrint("⚠️ Error cargando contraseñas: $e\n$st");
    }
  }

  Future<void> _savePasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = await _encryptInternal(
          json.encode(_passwords.map((k, v) => MapEntry(k, v.toJson()))));
      if (encryptedData.isNotEmpty) {
        await prefs.setString(_storageKey, encryptedData);
        await _updateNativeVault();
      }
    } catch (e) {
      debugPrint("⚠️ Error guardando: $e");
    }
  }

  void _filterPasswords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<String> tempKeys = _passwords.keys.where((appKey) {
        final entry = _passwords[appKey]!;
        final matchesText = query.isEmpty ||
            entry.app.toLowerCase().contains(query) ||
            (entry.username?.toLowerCase().contains(query) ?? false);
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

  void _showThemeDialog() {
    HapticFeedback.lightImpact();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text("Apariencia"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const ThemeOption(title: "Claro", mode: AppThemeMode.light),
                const ThemeOption(
                    title: "Gris Oscuro (Material)",
                    mode: AppThemeMode.darkMaterial),
                const ThemeOption(
                    title: "Negro Absoluto (AMOLED)",
                    mode: AppThemeMode.darkAmoled),
              ]),
            ));
  }

  Future<void> _importPasswords() async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.single.path != null) {
        final content = await File(result.files.single.path!).readAsString();
        if (!mounted) return;
        Map<String, dynamic> passwordsMap;
        if (content.trim().startsWith('{')) {
          try {
            passwordsMap = json.decode(content);
          } catch (e) {
            return;
          }
        } else {
          String? password = await _showBackupPasswordDialog(false);
          if (password == null) return;
          try {
            passwordsMap = json.decode(_decryptBackupData(content, password));
          } catch (e) {
            return;
          }
        }
        Map<String, PasswordEntry> newPasswords = {};
        passwordsMap.forEach((key, value) {
          try {
            newPasswords[key] =
                PasswordEntry.fromJson(Map<String, dynamic>.from(value));
          } catch (e) {
            debugPrint("Error importando $key: $e");
          }
        });
        setState(() {
          _passwords = newPasswords;
          _filterPasswords();
        });
        await _savePasswords();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Datos importados con éxito'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Fallo al importar: $e");
    }
  }

  Future<String?> _showBackupPasswordDialog(bool isExport) {
    final ctrl = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(isExport ? 'Encriptar Backup' : 'Desencriptar Backup'),
              content: TextField(
                  controller: ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña maestra')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () {
                      if (ctrl.text.isNotEmpty) Navigator.pop(context, ctrl.text);
                    },
                    child: const Text('Aceptar')),
              ],
            ));
  }

  Future<void> _exportPasswords() async {
    if (_passwords.isEmpty) return;
    String? password = await _showBackupPasswordDialog(true);
    if (password == null) return;
    try {
      final encryptedBackup = _encryptBackupData(
          json.encode(_passwords.map((k, v) => MapEntry(k, v.toJson()))), password);
      final fileName = 'backup_${DateTime.now().millisecondsSinceEpoch}.json';
      await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar backup',
          fileName: fileName,
          bytes: utf8.encode(encryptedBackup));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup guardado'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Fallo al exportar: $e");
    }
  }

  void _showSaveBottomSheet(
      {String? initialApp,
      String? initialUser,
      String? initialPass,
      String? initialPkg,
      PasswordEntry? existingEntry,
      String? oldKey,
      bool autoCloseApp = false}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PasswordEditorSheet(
          entry: existingEntry,
          initialApp: initialApp,
          initialUser: initialUser,
          initialPass: initialPass,
          initialPkg: initialPkg,
          onSave: (app, user, pass, pkg) {
            _savePasswordLogic(app, user, pass, pkg,
                oldKey: oldKey, createdAt: existingEntry?.createdAt, autoCloseApp: autoCloseApp);
          },
        ),
      ),
    );
  }

  void _savePasswordLogic(
      String app, String username, String password, String packageId,
      {String? oldKey, DateTime? createdAt, bool autoCloseApp = false}) async {
    if (app.isEmpty || password.isEmpty) return;
    final now = DateTime.now();
    final appKey = app.toLowerCase();
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
          isFavorite: isFav);
      _filterPasswords();
    });
    await _savePasswords();
    if (!mounted) return;
    
    if (autoCloseApp) {
      SystemNavigator.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Guardado Seguro'), backgroundColor: Colors.green));
    }
  }

  void _deletePassword(String appKey) {
    setState(() {
      _passwords.remove(appKey);
      _visiblePasswords.remove(appKey);
      _filterPasswords();
    });
    _savePasswords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bóveda Segura",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
              icon: const Icon(Icons.palette_outlined),
              onPressed: _showThemeDialog,
              tooltip: "Apariencia"),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'export') _exportPasswords();
              if (v == 'import') _importPasswords();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'export',
                  child: Row(children: [
                    Icon(Icons.upload_file, size: 20),
                    SizedBox(width: 8),
                    Text('Exportar Backup')
                  ])),
              PopupMenuItem(
                  value: 'import',
                  child: Row(children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Importar Backup')
                  ])),
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
                hintText: "Buscar contraseñas...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(children: [
            ActionChip(
                label: Text("Todas",
                    style: TextStyle(
                        color: _currentFilter == FilterType.all
                            ? Colors.white
                            : null)),
                onPressed: () => setState(() {
                      _currentFilter = FilterType.all;
                      _filterPasswords();
                    }),
                backgroundColor: _currentFilter == FilterType.all
                    ? Theme.of(context).primaryColor
                    : null,
                side: BorderSide.none),
            const SizedBox(width: 8),
            ActionChip(
                label: Text("Recientes",
                    style: TextStyle(
                        color: _currentFilter == FilterType.recent
                            ? Colors.white
                            : null)),
                onPressed: () => setState(() {
                      _currentFilter = FilterType.recent;
                      _filterPasswords();
                    }),
                backgroundColor: _currentFilter == FilterType.recent
                    ? Theme.of(context).primaryColor
                    : null,
                side: BorderSide.none),
            const SizedBox(width: 8),
            ActionChip(
                label: Text("Favoritas",
                    style: TextStyle(
                        color: _currentFilter == FilterType.favorites
                            ? Colors.white
                            : null)),
                onPressed: () => setState(() {
                      _currentFilter = FilterType.favorites;
                      _filterPasswords();
                    }),
                backgroundColor: _currentFilter == FilterType.favorites
                    ? Theme.of(context).primaryColor
                    : null,
                side: BorderSide.none),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _filteredApps.isEmpty
              ? Center(
                  child: Text("No se encontraron resultados",
                      style: TextStyle(
                          color: Colors.grey.withValues(alpha: 0.8))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredApps.length,
                  itemBuilder: (_, index) {
                    final appKey = _filteredApps[index];
                    final entry = _passwords[appKey]!;
                    return PasswordCard(
                      entry: entry,
                      isVisible: _visiblePasswords.contains(appKey),
                      onToggleVisibility: () => setState(() {
                        if (_visiblePasswords.contains(appKey)) {
                          _visiblePasswords.remove(appKey);
                        } else {
                          _visiblePasswords.add(appKey);
                        }
                      }),
                      onToggleFavorite: () => _toggleFavorite(appKey),
                      onEdit: () => _showSaveBottomSheet(
                          existingEntry: entry, oldKey: appKey),
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
