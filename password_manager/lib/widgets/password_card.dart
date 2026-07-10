import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/password_entry.dart';

class PasswordCard extends StatelessWidget {
  final PasswordEntry entry;
  final bool isVisible;
  final VoidCallback onToggleVisibility, onToggleFavorite, onEdit, onDelete;

  const PasswordCard({
    super.key,
    required this.entry,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getAvatarColor(String appName) {
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.indigoAccent
    ];
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
            child: Text(
                entry.app.isNotEmpty ? entry.app[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 20))),
        title: Row(children: [
          Flexible(
              child: Text(entry.app,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
          if (entry.isFavorite) ...[
            const SizedBox(width: 6),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16)
          ],
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (entry.username != null && entry.username!.isNotEmpty)
            Text(entry.username!,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(isVisible ? entry.password : '••••••••',
              style: GoogleFonts.sourceCodePro(
                  color: isVisible ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey),
              onPressed: onToggleVisibility),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'favorite') {
                onToggleFavorite();
                HapticFeedback.selectionClick();
              }
              if (val == 'edit') onEdit();
              if (val == 'copy_pass') {
                Clipboard.setData(ClipboardData(text: entry.password));
                HapticFeedback.mediumImpact();
              }
              if (val == 'copy_user' && entry.username != null) {
                Clipboard.setData(ClipboardData(text: entry.username!));
                HapticFeedback.mediumImpact();
              }
              if (val == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'favorite',
                  child: Row(children: [
                    Icon(
                        entry.isFavorite
                            ? Icons.star_outline_rounded
                            : Icons.star_rounded,
                        color: Colors.amber,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(entry.isFavorite
                        ? 'Quitar de Favoritos'
                        : 'Hacer Favorito')
                  ])),
              const PopupMenuDivider(),
              if (entry.username != null && entry.username!.isNotEmpty)
                const PopupMenuItem(
                    value: 'copy_user',
                    child: Row(children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Copiar Usuario')
                    ])),
              const PopupMenuItem(
                  value: 'copy_pass',
                  child: Row(children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Copiar Password')
                  ])),
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Editar')
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red))
                  ])),
            ],
          ),
        ]),
      ),
    );
  }
}
