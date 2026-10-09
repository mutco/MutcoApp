import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/mutco_theme.dart';
import '../app/app_language.dart';
import '../core/coffee_classes.dart';
import '../data/scan_record.dart';

class ResultScreen extends StatefulWidget {
  final ScanRecord record;
  final bool saved, boxes, labels;
  final Future<void> Function() onSave;
  final VoidCallback? onClose;
  final VoidCallback onRescan;
  final void Function(bool) onBoxes, onLabels;
  const ResultScreen({
    super.key,
    required this.record,
    required this.saved,
    required this.boxes,
    required this.labels,
    required this.onSave,
    this.onClose,
    required this.onRescan,
    required this.onBoxes,
    required this.onLabels,
  });
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late bool boxes = widget.boxes, labels = widget.labels;
  bool didSave = false, downloading = false;

  Future<void> _downloadImage() async {
    if (downloading) return;
    final english = isEnglish(context);
    setState(() => downloading = true);
    try {
      final record = widget.record;
      final targetWidth = record.width.clamp(1, 1600);
      final targetHeight = (targetWidth * record.height / record.width).round();
      final bytes = await File(record.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final source = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(targetWidth.toDouble(), targetHeight.toDouble());
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        Offset.zero & size,
        Paint(),
      );
      _DetectionPainter(record, boxes, labels, english).paint(canvas, size);
      final image = await recorder.endRecording().toImage(
        targetWidth,
        targetHeight,
      );
      source.dispose();
      codec.dispose();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) throw StateError('PNG encoding failed');
      await const MethodChannel('com.usk.mutco/export')
          .invokeMethod<String>('savePng', <String, Object>{
            'name': 'Mutco_${record.id}.png',
            'bytes': png.buffer.asUint8List(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              english ? 'Image saved.' : 'Gambar berhasil disimpan.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              english
                  ? 'Could not download image: $error'
                  : 'Gagal mengunduh gambar: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  void dispose() {
    if (!widget.saved && !didSave) {
      File(widget.record.imagePath)
          .delete()
          .catchError((Object _) => File(widget.record.imagePath));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final p = MutcoPalette.of(context);
    final counts = record.counts.entries.where((e) => e.key != 17).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        widget.onClose ??
                        () =>
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst),
                    icon: Icon(Icons.close, color: p.text, size: 27),
                  ),
                  Expanded(
                    child: Text(
                      tr(context, 'Hasil Deteksi'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .45,
                      ),
                      child: AspectRatio(
                        aspectRatio: record.width / record.height,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _ZoomScreen(
                                      record: record,
                                      boxes: boxes,
                                      labels: labels,
                                      onBoxes: (v) {
                                        setState(() => boxes = v);
                                        widget.onBoxes(v);
                                      },
                                      onLabels: (v) {
                                        setState(() => labels = v);
                                        widget.onLabels(v);
                                      },
                                    ),
                                  ),
                                ),
                                child: DetectionImage(
                                  record: record,
                                  boxes: boxes,
                                  labels: labels,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  _imageButton(
                                    downloading
                                        ? Icons.hourglass_top_rounded
                                        : Icons.download_rounded,
                                    downloading ? null : _downloadImage,
                                    tr(context, 'Unduh gambar'),
                                  ),
                                  _imageButton(
                                    Icons.visibility_outlined,
                                    () => setState(() {
                                      boxes = !boxes;
                                      widget.onBoxes(boxes);
                                    }),
                                    tr(context, 'Tampilkan Box'),
                                  ),
                                  _imageButton(
                                    Icons.text_fields,
                                    () => setState(() {
                                      labels = !labels;
                                      widget.onLabels(labels);
                                    }),
                                    tr(context, 'Tampilkan Label'),
                                  ),
                                  _imageButton(
                                    Icons.fullscreen,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => _ZoomScreen(
                                          record: record,
                                          boxes: boxes,
                                          labels: labels,
                                          onBoxes: (v) {
                                            setState(() => boxes = v);
                                            widget.onBoxes(v);
                                          },
                                          onLabels: (v) {
                                            setState(() => labels = v);
                                            widget.onLabels(v);
                                          },
                                        ),
                                      ),
                                    ),
                                    tr(context, 'Gambar Diperbesar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: _decoration(p),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(context, 'Hasil Mutu (SNI)'),
                                style: TextStyle(
                                  color: p.secondary,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                tr(context, record.grade),
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 54, color: p.separator),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            isEnglish(context)
                                ? 'Defect value ${_number(record.defectValue)}\nBased on SNI 01-2907-2008'
                                : 'Nilai cacat ${_number(record.defectValue)}\nBerdasarkan SNI 01-2907-2008',
                            style: TextStyle(
                              color: p.secondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _stat(
                            p,
                            width,
                            tr(context, 'Total Biji'),
                            '${record.total}',
                            isEnglish(context) ? 'objects' : 'objek',
                          ),
                          _stat(
                            p,
                            width,
                            tr(context, 'Biji Cacat'),
                            '${record.defective}',
                            isEnglish(context) ? 'objects' : 'objek',
                          ),
                          _stat(
                            p,
                            width,
                            tr(context, 'Persentase Cacat'),
                            '${record.defectPercentage.toStringAsFixed(1)}%',
                            '',
                          ),
                          _stat(
                            p,
                            width,
                            tr(context, 'Inferensi'),
                            '${record.inferenceMs}',
                            'ms',
                          ),
                          _stat(
                            p,
                            width,
                            tr(context, 'Ambang'),
                            '${(record.threshold * 100).round()}%',
                            '',
                          ),
                          _stat(
                            p,
                            width,
                            'IoU (NMS)',
                            '${(record.iouThreshold * 100).round()}%',
                            '',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, 'Rincian Cacat'),
                    style: TextStyle(
                      color: p.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: _decoration(p),
                    child: Column(
                      children: [
                        if (counts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Text(
                              tr(context, 'Tidak ada cacat terdeteksi.'),
                              style: TextStyle(color: p.secondary),
                            ),
                          ),
                        for (final entry in counts)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    coffeeName(
                                      context,
                                      entry.key,
                                      coffeeClasses[entry.key],
                                    ),
                                    style: TextStyle(
                                      color: p.text,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.value}  ',
                                  style: TextStyle(color: p.text),
                                ),
                                Text(
                                  '(${_number(entry.value * defectWeights[entry.key])})',
                                  style: TextStyle(color: p.secondary),
                                ),
                              ],
                            ),
                          ),
                        Divider(height: 17, thickness: 1, color: p.divider),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr(context, 'Total nilai cacat'),
                                  style: TextStyle(
                                    color: p.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _number(record.defectValue),
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => widget.onRescan(),
                            );
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 54),
                            backgroundColor: p.surface,
                            foregroundColor: p.text,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(tr(context, 'Pindai ulang')),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: FilledButton(
                          onPressed: widget.saved
                              ? null
                              : () async {
                                  await widget.onSave();
                                  didSave = true;
                                  if (context.mounted) {
                                    Navigator.of(context)
                                        .popUntil((route) => route.isFirst);
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 54),
                          ),
                          child: Text(
                            tr(
                              context,
                              widget.saved ? 'Tersimpan' : 'Simpan hasil',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageButton(IconData icon, VoidCallback? tap, String tooltip) =>
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton.filled(
          onPressed: tap,
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white, size: 19),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            minimumSize: const Size(35, 35),
            padding: const EdgeInsets.all(7),
          ),
        ),
      );

  Widget _stat(
    MutcoPalette p,
    double width,
    String title,
    String value,
    String unit,
  ) => Container(
    width: width,
    padding: const EdgeInsets.all(10),
    decoration: _decoration(p),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: p.secondary, fontSize: 13)),
        const SizedBox(height: 5),
        Text(
          '$value $unit',
          maxLines: 1,
          style: TextStyle(
            color: p.text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  BoxDecoration _decoration(MutcoPalette p) =>
      BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16));
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');

class DetectionImage extends StatelessWidget {
  final ScanRecord record;
  final bool boxes, labels;
  const DetectionImage({
    super.key,
    required this.record,
    required this.boxes,
    required this.labels,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: AspectRatio(
      aspectRatio: record.width / record.height,
      child: LayoutBuilder(
        builder: (context, size) => Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(record.imagePath), fit: BoxFit.fill),
            CustomPaint(
              painter: _DetectionPainter(
                record,
                boxes,
                labels,
                isEnglish(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetectionPainter extends CustomPainter {
  static const _classColors = <Color>[
    Color(0xffd95f59),
    Color(0xff4d80b8),
    Color(0xff57a564),
    Color(0xffa06cba),
    Color(0xffe08a36),
    Color(0xff3f9ba2),
    Color(0xffcb5d88),
    Color(0xffa0775a),
    Color(0xffb3a139),
    Color(0xff616bb5),
    Color(0xff56a8be),
    Color(0xffc46b37),
    Color(0xff839e42),
    Color(0xff9463a9),
    Color(0xff458fc3),
    Color(0xffc85955),
    Color(0xff4a9f83),
    Color(0xffe3e7eb),
    Color(0xff8d528c),
    Color(0xffb9824f),
    Color(0xff536a98),
  ];
  final ScanRecord record;
  final bool boxes, labels, english;
  _DetectionPainter(this.record, this.boxes, this.labels, this.english);
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / record.width, sy = size.height / record.height;
    final scale = (size.width / 320).clamp(.7, 5.0).toDouble();
    Rect boxFor(Detection detection) => Rect.fromLTRB(
      detection.left * sx,
      detection.top * sy,
      detection.right * sx,
      detection.bottom * sy,
    );
    Color colorFor(Detection detection) => _classColors[detection.classId];

    if (boxes) {
      for (final detection in record.detections) {
        canvas.drawRect(
          boxFor(detection),
          Paint()
            ..color = colorFor(detection)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * scale,
        );
      }
    }
    if (!labels) return;

    final detections = [...record.detections]
      ..sort((a, b) => a.top.compareTo(b.top));
    for (final detection in detections) {
      final rect = boxFor(detection);
      final name = coffeeShortNameForId(detection.classId, english: english);
      final text = TextPainter(
        text: TextSpan(
          text: '$name ${(detection.confidence * 100).round()}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: (record.detections.length >= 40 ? 7 : 8) * scale,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width * .38);
      final labelWidth = text.width + 4 * scale;
      final labelHeight = text.height + 2 * scale;
      final maxLeft = (size.width - labelWidth).clamp(0.0, size.width);
      final maxTop = (size.height - labelHeight).clamp(0.0, size.height);
      final labelRect = Rect.fromLTWH(
        rect.left.clamp(0.0, maxLeft),
        (rect.top - labelHeight + scale).clamp(0.0, maxTop),
        labelWidth,
        labelHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, Radius.circular(2 * scale)),
        Paint()
          ..color = detection.classId == 17
              ? const Color(0xe61b1b1b)
              : Color.lerp(colorFor(detection), Colors.black, .35)!,
      );
      text.paint(canvas, labelRect.topLeft + Offset(2 * scale, scale));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter old) =>
      old.record != record ||
      old.boxes != boxes ||
      old.labels != labels ||
      old.english != english;
}

class _ZoomScreen extends StatefulWidget {
  final ScanRecord record;
  final bool boxes, labels;
  final void Function(bool) onBoxes, onLabels;
  const _ZoomScreen({
    required this.record,
    required this.boxes,
    required this.labels,
    required this.onBoxes,
    required this.onLabels,
  });
  @override
  State<_ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<_ZoomScreen> {
  late bool boxes = widget.boxes, labels = widget.labels;
  final zoom = TransformationController();
  TapDownDetails? doubleTap;
  @override
  void dispose() {
    zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (zoom.value.getMaxScaleOnAxis() > 1.1) {
      zoom.value = Matrix4.identity();
      return;
    }
    final position = doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    zoom.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = MutcoPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(tr(context, 'Gambar Diperbesar')),
            Text(
              isEnglish(context)
                  ? '${widget.record.total} beans · ${widget.record.defective} defective'
                  : '${widget.record.total} biji · ${widget.record.defective} biji cacat',
              style: TextStyle(color: p.secondary, fontSize: 13),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onDoubleTapDown: (details) => doubleTap = details,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: zoom,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .7,
                    ),
                    child: DetectionImage(
                      record: widget.record,
                      boxes: boxes,
                      labels: labels,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: Text(
                      tr(context, 'Tampilkan Box'),
                      style: TextStyle(color: p.text, fontSize: 13),
                    ),
                    value: boxes,
                    onChanged: (v) {
                      setState(() => boxes = v);
                      widget.onBoxes(v);
                    },
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    title: Text(
                      tr(context, 'Tampilkan Label'),
                      style: TextStyle(color: p.text, fontSize: 13),
                    ),
                    value: labels,
                    onChanged: (v) {
                      setState(() => labels = v);
                      widget.onLabels(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
