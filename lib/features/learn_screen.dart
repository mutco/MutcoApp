import 'package:flutter/material.dart';
import '../app/app_language.dart';
import '../app/mutco_theme.dart';
import '../core/coffee_classes.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _sniOrder = [5, 7, 6, 10, 4, 11, 13, 12, 0, 14, 16, 15,
    9, 8, 2, 1, 3, 18, 20, 19, 17];
  static const _grades = [
    ('Mutu 1', '≤ 11'), ('Mutu 2', '12–25'), ('Mutu 3', '26–44'),
    ('Mutu 4a', '45–60'), ('Mutu 4b', '61–80'), ('Mutu 5', '81–150'),
    ('Mutu 6', '151–225'), ('Di luar rentang', '> 225'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    final en = isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Belajar SNI'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Container(padding: const EdgeInsets.all(18), decoration: _card(p),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.menu_book_outlined, color: p.text),
              const SizedBox(width: 9),
              Expanded(child: Text(en ? 'SNI 01-2907-2008 · Coffee beans'
                : 'SNI 01-2907-2008 · Biji kopi',
                style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)))]),
            const SizedBox(height: 10),
            Text(en
              ? 'Defect value is determined from a 300 g sample. If one bean has multiple defects, use its highest defect value.'
              : 'Nilai cacat ditentukan dari contoh uji seberat 300 g. Jika satu biji memiliki lebih dari satu jenis cacat, gunakan nilai cacat yang paling besar.',
              style: TextStyle(color: p.secondary, fontSize: 15, height: 1.4)),
          ])),
        const SizedBox(height: 22),
        _heading(p, tr(context, 'Tabel nilai cacat')),
        const SizedBox(height: 10),
        Container(decoration: _card(p), child: Column(children: [
          _tableHeader(p, tr(context, 'Jenis cacat'), tr(context, 'Nilai')),
          for (final id in _sniOrder) _defectRow(context, p, id),
        ])),
        const SizedBox(height: 22),
        _heading(p, tr(context, 'Penggolongan mutu')),
        const SizedBox(height: 10),
        Container(decoration: _card(p), child: Column(children: [
          _tableHeader(p, tr(context, 'Mutu'), tr(context, 'Jumlah nilai cacat')),
          for (final grade in _grades)
            _gradeRow(p, tr(context, grade.$1), grade.$2),
        ])),
        const SizedBox(height: 16),
        Text(en
          ? 'App results are visual estimates from the photo. Moisture, odor, impurities, and sample weight still require SNI testing.'
          : 'Hasil di aplikasi adalah estimasi visual dari objek pada foto. Pemeriksaan kadar air, bau, kotoran, dan bobot sampel tetap memerlukan pengujian sesuai SNI.',
          style: TextStyle(color: p.secondary, fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _heading(MutcoPalette p, String title) => Text(title,
    style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w700));

  BoxDecoration _card(MutcoPalette p) => BoxDecoration(color: p.surface,
    borderRadius: BorderRadius.circular(18), border: Border.all(color: p.separator));

  Widget _tableHeader(MutcoPalette p, String left, String right) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Row(children: [Expanded(child: Text(left,
      style: TextStyle(color: p.secondary, fontSize: 14, fontWeight: FontWeight.w700))),
      Text(right, style: TextStyle(color: p.secondary, fontSize: 14,
        fontWeight: FontWeight.w700))]));

  Widget _defectRow(BuildContext context, MutcoPalette p, int id) => Container(
    decoration: BoxDecoration(border: Border(top: BorderSide(color: p.divider, width: .5))),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Expanded(child: Text(coffeeName(context, id, coffeeClasses[id]),
        style: TextStyle(color: p.text, fontSize: 15))),
      const SizedBox(width: 12),
      Text(_weight(defectWeights[id]), style: TextStyle(color: p.text,
        fontSize: 15, fontWeight: FontWeight.w700)),
    ]));

  Widget _gradeRow(MutcoPalette p, String label, String range) => Container(
    decoration: BoxDecoration(border: Border(top: BorderSide(color: p.divider, width: .5))),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: p.text, fontSize: 15))),
      Text(range, style: TextStyle(color: p.text, fontSize: 15,
        fontWeight: FontWeight.w700)),
    ]));

  String _weight(double value) => value == value.roundToDouble()
    ? value.toInt().toString() : value.toString();
}
