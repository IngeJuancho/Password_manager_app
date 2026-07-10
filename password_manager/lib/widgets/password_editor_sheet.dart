import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/password_entry.dart';
import '../utils/password_analyzer.dart';

class PasswordEditorSheet extends StatefulWidget {
  final PasswordEntry? entry;
  final String? initialApp, initialUser, initialPass, initialPkg;
  final Function(String, String, String, String) onSave;

  const PasswordEditorSheet({
    super.key,
    this.entry,
    this.initialApp,
    this.initialUser,
    this.initialPass,
    this.initialPkg,
    required this.onSave,
  });

  @override
  State<PasswordEditorSheet> createState() => _PasswordEditorSheetState();
}

class _PasswordEditorSheetState extends State<PasswordEditorSheet> {
  bool _obscurePassword = true, _showAdvanced = false;
  late TextEditingController _appController, _userController, _passController, _pkgController;

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
    setState(() {
      _passController.text = String.fromCharCodes(
          Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
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
    final strengthValue = _passController.text.isEmpty ? 0.0 : strength.index / 4;

    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24.0),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(widget.entry == null ? "Nueva Contraseña" : "Editar Contraseña",
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 20),
            TextField(
                controller: _appController,
                decoration: InputDecoration(
                    labelText: "Sitio Web / Aplicación",
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    prefixIcon: const Icon(Icons.apps),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            TextField(
                controller: _userController,
                decoration: InputDecoration(
                    labelText: "Usuario o Correo",
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: "Contraseña",
                filled: true,
                fillColor: Theme.of(context).cardColor,
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: const Icon(Icons.autorenew),
                      onPressed: _generatePassword,
                      tooltip: "Generar Segura"),
                  IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                ]),
              ),
            ),
            if (_passController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: LinearProgressIndicator(
                        value: strengthValue,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 6)),
                const SizedBox(width: 12),
                Text(strength.name.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: strengthColor)),
              ]),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(children: [
                Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                const Text('Avanzado (Package ID)',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none))),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onSave(_appController.text, _userController.text,
                      _passController.text, _pkgController.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Guardar en Bóveda",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
    );
  }
}
