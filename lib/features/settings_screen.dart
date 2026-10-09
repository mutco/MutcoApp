import 'package:flutter/material.dart';

import '../app/app_language.dart';
import '../app/mutco_theme.dart';

class SettingsScreen extends StatefulWidget {
  final bool dark;
  final String language;
  final double threshold;
  final double iouThreshold;
  final Future<void> Function(String, Object) onPreference;
  final Future<void> Function() onClear;
  final Future<void> Function() onResetSettings;
  const SettingsScreen({
    super.key,
    required this.dark,
    required this.language,
    required this.threshold,
    required this.iouThreshold,
    required this.onPreference,
    required this.onClear,
    required this.onResetSettings,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool dark = widget.dark;
  late String language = widget.language;
  late double threshold = widget.threshold;
  late double iouThreshold = widget.iouThreshold;

  Future<void> _chooseTheme() async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _ChoiceSheet<bool>(
        title: tr(sheet, 'Tema'),
        current: dark,
        options: [
          (false, tr(sheet, 'Terang'), Icons.light_mode_outlined),
          (true, tr(sheet, 'Gelap'), Icons.dark_mode_outlined),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await widget.onPreference('dark', selected);
    if (mounted) setState(() => dark = selected);
  }

  Future<void> _chooseLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _ChoiceSheet<String>(
        title: tr(sheet, 'Bahasa'),
        current: language,
        options: const [
          ('id', 'Bahasa Indonesia', Icons.translate),
          ('en', 'English', Icons.language),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await widget.onPreference('language', selected);
    if (mounted) setState(() => language = selected);
  }

  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(context, 'Pengaturan'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          _section(p, tr(context, 'Preferensi')),
          _card(p, [
            _row(
              p,
              Icons.palette_outlined,
              tr(context, 'Tema'),
              tr(context, dark ? 'Gelap' : 'Terang'),
              _chooseTheme,
            ),
            _row(
              p,
              Icons.language,
              tr(context, 'Bahasa'),
              language == 'en' ? 'English' : 'Bahasa Indonesia',
              _chooseLanguage,
            ),
          ]),
          _section(p, tr(context, 'Deteksi')),
          _card(p, [
            _row(
              p,
              Icons.tune,
              tr(context, 'Pengaturan Deteksi'),
              '${(threshold * 100).round()}% / ${(iouThreshold * 100).round()}%',
              _detectionSheet,
            ),
            _row(
              p,
              Icons.memory_outlined,
              tr(context, 'Model'),
              'YOLO11s ONNX',
              () => _info(
                tr(context, 'Model'),
                isEnglish(context)
                    ? 'The YOLO11s ONNX model runs offline on your device. It uses 640 × 640 input and detects 21 coffee bean classes.'
                    : 'Model YOLO11s ONNX berjalan lokal tanpa internet. Input 640 × 640 dengan 21 kelas biji kopi.',
              ),
            ),
          ]),
          _section(p, tr(context, 'Data')),
          _card(p, [
            _row(
              p,
              Icons.restart_alt_rounded,
              tr(context, 'Atur Ulang Pengaturan'),
              null,
              _resetSettings,
            ),
            _row(
              p,
              Icons.delete_outline,
              tr(context, 'Hapus Data'),
              null,
              _clearData,
            ),
          ]),
          _section(p, tr(context, 'Lainnya')),
          _card(p, [
            _row(
              p,
              Icons.info_outline,
              tr(context, 'Tentang Aplikasi'),
              null,
              () => _info(
                tr(context, 'Tentang Aplikasi'),
                isEnglish(context)
                    ? 'Mutco estimates robusta coffee bean defect values using SNI 01-2907-2008. Review all detections before using the result.'
                    : 'Mutco menghitung estimasi nilai cacat biji kopi robusta berdasarkan SNI 01-2907-2008. Tinjau hasil deteksi sebelum digunakan.',
              ),
            ),
            _row(
              p,
              Icons.description_outlined,
              tr(context, 'Panduan Penggunaan'),
              null,
              () => _info(
                tr(context, 'Panduan Penggunaan'),
                isEnglish(context)
                    ? 'Capture or choose a clear photo of separated coffee beans, review detections, then save the result.'
                    : 'Pindai atau pilih foto biji kopi yang jelas dan terpisah, tinjau deteksi, lalu simpan hasil.',
              ),
            ),
            _row(
              p,
              Icons.verified_user_outlined,
              tr(context, 'Kebijakan Privasi'),
              null,
              () => _info(
                tr(context, 'Kebijakan Privasi'),
                isEnglish(context)
                    ? 'Photos and results stay on this device. Inference runs offline.'
                    : 'Foto dan hasil analisis disimpan lokal di perangkat. Inferensi berjalan tanpa server.',
              ),
            ),
            _row(
              p,
              Icons.help_outline,
              tr(context, 'Bantuan'),
              null,
              () => _info(
                tr(context, 'Bantuan'),
                isEnglish(context)
                    ? 'If the camera is unavailable, check Android camera permission or choose a photo from the gallery.'
                    : 'Jika kamera tidak tersedia, periksa izin kamera Android atau pilih foto dari galeri.',
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(MutcoPalette p, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 21, 0, 10),
    child: Text(
      title,
      style: TextStyle(
        color: p.secondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _card(MutcoPalette p, List<Widget> children) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Material(
      color: p.surface,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 60,
                endIndent: 16,
                color: p.divider,
              ),
            children[i],
          ],
        ],
      ),
    ),
  );

  Widget _row(
    MutcoPalette p,
    IconData icon,
    String title,
    String? value,
    VoidCallback onTap,
  ) => ListTile(
    onTap: onTap,
    minTileHeight: 54,
    contentPadding: const EdgeInsets.symmetric(horizontal: 17),
    leading: Icon(icon, color: p.text, size: 22),
    title: Text(title, style: TextStyle(color: p.text, fontSize: 17)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 125),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(width: 7),
        Icon(Icons.chevron_right, color: p.tertiary, size: 20),
      ],
    ),
  );

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr(dialog, 'Hapus semua data?')),
        content: Text(
          tr(dialog, 'Semua riwayat dan foto sampel akan dihapus permanen.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(tr(dialog, 'Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr(dialog, 'Hapus')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onClear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Semua data telah dihapus.'))),
      );
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr(dialog, 'Atur ulang pengaturan?')),
        content: Text(
          tr(
            dialog,
            'Tema, bahasa, ambang deteksi, dan tampilan kotak serta label akan kembali ke bawaan. Riwayat tetap tersimpan.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(tr(dialog, 'Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr(dialog, 'Atur Ulang')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onResetSettings();
    if (!mounted) return;
    setState(() {
      dark = false;
      language = 'id';
      threshold = .25;
      iouThreshold = .70;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, 'Pengaturan kembali ke bawaan.'))),
    );
  }

  void _info(String title, String message) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 15, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(tr(dialog, 'Tutup')),
        ),
      ],
    ),
  );

  Future<void> _detectionSheet() async {
    var draftConfidence = threshold;
    var draftIou = iouThreshold;
    final selected = await showModalBottomSheet<(double, double)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) {
          final p = MutcoPalette.of(sheet);
          final en = isEnglish(sheet);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * .78,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(sheet, 'Pengaturan Deteksi'),
                      style: TextStyle(
                        color: p.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr(sheet, 'Ambang Keyakinan'),
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(draftConfidence * 100).round()}%',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      en
                          ? 'Minimum confidence for a detection. Training notebook prediction: 25% at 640 x 640.'
                          : 'Keyakinan minimal agar objek terdeteksi. Prediksi notebook training: 25% pada 640 x 640.',
                      style: TextStyle(
                        color: p.secondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    Slider(
                      value: draftConfidence,
                      min: .05,
                      max: .95,
                      divisions: 18,
                      onChanged: (value) =>
                          update(() => draftConfidence = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5%',
                          style: TextStyle(color: p.secondary, fontSize: 13),
                        ),
                        Text(
                          '95%',
                          style: TextStyle(color: p.secondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr(sheet, 'Ambang IoU (NMS)'),
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(draftIou * 100).round()}%',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      en
                          ? 'NMS removes boxes that overlap beyond this value. Training log: 70%.'
                          : 'NMS menghapus kotak yang tumpang tindih melebihi nilai ini. Log training: 70%.',
                      style: TextStyle(
                        color: p.secondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    Slider(
                      value: draftIou,
                      min: .10,
                      max: .90,
                      divisions: 16,
                      onChanged: (value) => update(() => draftIou = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '10%',
                          style: TextStyle(color: p.secondary, fontSize: 13),
                        ),
                        Text(
                          '90%',
                          style: TextStyle(color: p.secondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () =>
                            Navigator.pop(sheet, (draftConfidence, draftIou)),
                        child: Text(tr(sheet, 'Simpan')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    await widget.onPreference('threshold', selected.$1);
    await widget.onPreference('iou_threshold', selected.$2);
    if (mounted) {
      setState(() {
        threshold = selected.$1;
        iouThreshold = selected.$2;
      });
    }
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  final String title;
  final T current;
  final List<(T, String, IconData)> options;
  const _ChoiceSheet({
    required this.title,
    required this.current,
    required this.options,
  });
  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(
                    color: option.$1 == current ? p.surfaceAlt : p.background,
                    child: ListTile(
                      onTap: () => Navigator.pop(context, option.$1),
                      leading: Icon(option.$3, color: p.text),
                      title: Text(
                        option.$2,
                        style: TextStyle(color: p.text, fontSize: 16),
                      ),
                      trailing: option.$1 == current
                          ? Icon(Icons.check_circle, color: p.text, size: 22)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
