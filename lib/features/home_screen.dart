import 'package:flutter/material.dart';

import '../app/mutco_theme.dart';
import '../app/app_language.dart';
import '../data/local_repository.dart';
import '../data/scan_record.dart';
import 'common_widgets.dart';

class HomeScreen extends StatelessWidget {
  final List<ScanRecord> records;
  final LocalRepository repository;
  final VoidCallback onScan, onHistory, onSettings, onLearn, onChanged;
  final void Function(ScanRecord) onOpen;
  const HomeScreen({
    super.key,
    required this.records,
    required this.repository,
    required this.onScan,
    required this.onHistory,
    required this.onSettings,
    required this.onLearn,
    required this.onOpen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    final totalBeans = records.fold<int>(0, (sum, e) => sum + e.total);
    final totalDefects = records.fold<int>(0, (sum, e) => sum + e.defective);
    return Column(
      children: [
        PageHeader(
          title: tr(context, 'Beranda'),
          onSettings: onSettings,
          onLearn: onLearn,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 12),
              Container(
                height: 108,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    _stat(p, tr(context, 'Total sampel'), '${records.length}'),
                    Container(width: 1, color: p.divider),
                    _stat(p, tr(context, 'Total biji'), '$totalBeans'),
                    Container(width: 1, color: p.divider),
                    _stat(p, tr(context, 'Total biji cacat'), '$totalDefects'),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(context, 'Riwayat'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onHistory,
                    label: Text(
                      tr(context, 'Lihat semua'),
                      style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      overlayColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: Icon(Icons.chevron_right, color: p.text, size: 18),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      tr(context, 'Belum ada riwayat pemindaian'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.secondary, fontSize: 14),
                    ),
                  ),
                ),
              for (final record in records.take(5))
                RecordTile(
                  record: record,
                  onOpen: () => onOpen(record),
                  onRename: () => renameRecord(context, record, (item) async {
                    await repository.save(item);
                    onChanged();
                  }),
                  onDelete: () => deleteRecord(context, record, (item) async {
                    await repository.delete(item);
                    onChanged();
                  }),
                ),
            ],
          ),
        ),
        BottomNav(
          selected: 0,
          onHome: () {},
          onScan: onScan,
          onHistory: onHistory,
        ),
      ],
    );
  }

  Widget _stat(MutcoPalette p, String label, String value) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.secondary, fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.text,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
