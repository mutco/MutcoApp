import 'package:flutter/material.dart';
import '../app/mutco_theme.dart';
import '../app/app_language.dart';
import '../data/local_repository.dart';
import '../data/scan_record.dart';
import 'common_widgets.dart';

class HistoryScreen extends StatefulWidget {
  final List<ScanRecord> records;
  final LocalRepository repository;
  final VoidCallback onScan, onHome, onSettings, onLearn, onChanged;
  final void Function(ScanRecord) onOpen;
  const HistoryScreen({super.key, required this.records, required this.repository,
    required this.onScan, required this.onHome, required this.onSettings,
    required this.onLearn,
    required this.onOpen, required this.onChanged});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String query = '', filter = 'Semua';
  bool newest = true;
  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    final shown = widget.records.where((r) =>
      r.name.toLowerCase().contains(query.toLowerCase()) &&
      (filter == 'Semua' || r.grade == filter)).toList()
      ..sort((a, b) => newest ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return Column(children: [
      PageHeader(title: tr(context, 'Riwayat'), onSettings: widget.onSettings, onLearn: widget.onLearn),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Row(children: [
        Expanded(child: SizedBox(height: 48, child: TextField(
          onChanged: (value) => setState(() => query = value),
          style: TextStyle(color: p.text, fontSize: 15),
          decoration: InputDecoration(hintText: tr(context, 'Cari riwayat'),
            prefixIcon: Icon(Icons.search, color: p.secondary, size: 21),
            filled: true, fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))))),
        const SizedBox(width: 8),
        Tooltip(message: tr(context, newest ? 'Terbaru dahulu' : 'Terlama dahulu'),
          child: Material(color: p.surface, borderRadius: BorderRadius.circular(14),
            child: InkWell(borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => newest = !newest),
              child: SizedBox(width: 48, height: 48,
                child: Icon(Icons.swap_vert, color: p.text, size: 22))))),
      ])),
      const SizedBox(height: 12),
      SizedBox(height: 45, child: ListView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18), children: [
          for (final grade in const ['Semua','Mutu 1','Mutu 2','Mutu 3','Mutu 4a','Mutu 4b','Mutu 5','Mutu 6','Di luar mutu SNI'])
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text(tr(context, grade)), selected: filter == grade,
              selectedColor: p.text,
              checkmarkColor: p.background,
              labelStyle: TextStyle(color: filter == grade
                ? p.background : p.text, fontSize: 13),
              onSelected: (_) => setState(() => filter = grade))),
        ])),
      const SizedBox(height: 13),
      Expanded(child: shown.isEmpty
        ? Center(child: Text(tr(context, widget.records.isEmpty
          ? 'Belum ada riwayat pemindaian' : 'Tidak ada hasil yang cocok'),
          style: TextStyle(color: p.secondary, fontSize: 15)))
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: shown.length, itemBuilder: (context, index) {
            final record = shown[index];
            return RecordTile(record: record, onOpen: () => widget.onOpen(record),
              onRename: () => renameRecord(context, record, (item) async {
                await widget.repository.save(item); widget.onChanged();
              }),
              onDelete: () => deleteRecord(context, record, (item) async {
                await widget.repository.delete(item); widget.onChanged();
              }));
          })),
      BottomNav(selected: 1, onHome: widget.onHome, onScan: widget.onScan, onHistory: () {}),
    ]);
  }
}
