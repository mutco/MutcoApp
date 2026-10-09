import 'dart:io';

import 'package:flutter/material.dart';

import '../app/mutco_theme.dart';
import '../app/app_language.dart';
import '../data/scan_record.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSettings, onLearn;
  const PageHeader({
    super.key,
    required this.title,
    required this.onSettings,
    required this.onLearn,
  });
  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      child: Row(
        children: [
          IconButton(
            onPressed: onLearn,
            tooltip: tr(context, 'Belajar SNI'),
            icon: Icon(Icons.menu_book_outlined, size: 25, color: p.text),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 25),
          ),
        ],
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  final int selected;
  final VoidCallback onHome, onScan, onHistory;
  const BottomNav({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onScan,
    required this.onHistory,
  });
  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(
            p,
            Icons.home_rounded,
            tr(context, 'Beranda'),
            selected == 0,
            onHome,
          ),
          InkWell(
            onTap: onScan,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: p.text,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: p.background,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(context, 'Pindai'),
                  style: TextStyle(
                    color: p.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _item(
            p,
            Icons.access_time_filled,
            tr(context, 'Riwayat'),
            selected == 1,
            onHistory,
          ),
        ],
      ),
    );
  }

  Widget _item(
    MutcoPalette p,
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 25, color: active ? p.text : p.tertiary),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? p.text : p.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class GradeBadge extends StatelessWidget {
  final String grade;
  final bool compact;
  const GradeBadge(this.grade, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        tr(context, grade),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: p.text, fontSize: compact ? 11 : 13),
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onOpen, onRename, onDelete;
  const RecordTile({
    super.key,
    required this.record,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final imageSize = compact ? 54.0 : 67.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: EdgeInsets.all(compact ? 8 : 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(record.imagePath),
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => SizedBox(
                        width: imageSize,
                        height: imageSize,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(record.date)}  ${record.date.hour.toString().padLeft(2, '0')}:${record.date.minute.toString().padLeft(2, '0')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.secondary,
                            fontSize: compact ? 10 : 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Total: ${record.total}   |   ${tr(context, 'Cacat')}: ${record.defective}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.secondary,
                            fontSize: compact ? 10 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GradeBadge(record.grade, compact: compact),
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    tooltip: tr(context, 'Opsi riwayat'),
                    color: p.surfaceAlt,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 158),
                    onSelected: (action) {
                      if (action == 'open') onOpen();
                      if (action == 'rename') onRename();
                      if (action == 'delete') onDelete();
                    },
                    itemBuilder: (menu) => [
                      PopupMenuItem(
                        value: 'open',
                        child: Text(tr(menu, 'Lihat detail')),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(tr(menu, 'Ubah nama')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          tr(menu, 'Hapus'),
                          style: TextStyle(color: p.danger),
                        ),
                      ),
                    ],
                    child: SizedBox(
                      width: 36,
                      height: 40,
                      child: Center(
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: p.secondary,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> renameRecord(
  BuildContext context,
  ScanRecord record,
  Future<void> Function(ScanRecord) onSave,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _RenameSheet(record: record, onSave: onSave),
  );
}

class _RenameSheet extends StatefulWidget {
  final ScanRecord record;
  final Future<void> Function(ScanRecord) onSave;
  const _RenameSheet({required this.record, required this.onSave});
  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final controller = TextEditingController(text: widget.record.name);
  bool saving = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 25,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Ubah nama'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Text('${tr(context, 'Nama saat ini')}\n${widget.record.name}'),
        const SizedBox(height: 18),
        TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr(context, 'Nama baru'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: Text(tr(context, 'Batal')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        setState(() => saving = true);
                        widget.record.name = name;
                        await widget.onSave(widget.record);
                        if (mounted) Navigator.pop(this.context);
                      },
                child: Text(tr(context, 'Simpan')),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> deleteRecord(
  BuildContext context,
  ScanRecord record,
  Future<void> Function(ScanRecord) onDelete,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 35),
      title: Text(tr(dialog, 'Hapus Sampel?')),
      content: Text(
        isEnglish(dialog)
            ? '"${record.name}" will be permanently deleted. This cannot be undone.'
            : 'Data "${record.name}" akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(tr(dialog, 'Batal')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(tr(dialog, 'Hapus')),
        ),
      ],
    ),
  );
  if (confirmed == true) await onDelete(record);
}
