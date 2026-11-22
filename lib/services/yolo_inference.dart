import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../core/coffee_classes.dart';
import '../core/detection_model.dart';
import '../data/scan_record.dart';

// The filename also versions the native ONNX Runtime temporary-file cache.
const yoloModelAsset = 'assets/models/mutco_yolo11s_best_6bdfb468bd5c.onnx';

class PreparedImage {
  final Float32List tensor;
  final int width, height;
  final double scale;
  final int padX, padY;
  PreparedImage(
    this.tensor,
    this.width,
    this.height,
    this.scale,
    this.padX,
    this.padY,
  );
}

Future<PreparedImage> prepareImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Gambar tidak dapat dibaca.');
  }
  final oriented = img.bakeOrientation(decoded);
  final scale = math.min(640 / oriented.width, 640 / oriented.height);
  final width = math.max(1, (oriented.width * scale).round());
  final height = math.max(1, (oriented.height * scale).round());
  final padX = (640 - width) ~/ 2;
  final padY = (640 - height) ~/ 2;
  final rgb = oriented.convert(format: img.Format.uint8, numChannels: 3);
  final pixels = rgb.getBytes(order: img.ChannelOrder.rgb);
  final tensor = Float32List(3 * 640 * 640);
  tensor.fillRange(0, tensor.length, 114 / 255);
  const area = 640 * 640;
  // Match OpenCV's pixel-center mapping for bilinear interpolation.
  final scaleX = oriented.width / width;
  final scaleY = oriented.height / height;
  for (var y = 0; y < height; y++) {
    final sourceY = ((y + .5) * scaleY - .5).clamp(0, oriented.height - 1);
    final y0 = sourceY.floor();
    final y1 = math.min(y0 + 1, oriented.height - 1);
    final fy = sourceY - y0;
    for (var x = 0; x < width; x++) {
      final sourceX = ((x + .5) * scaleX - .5).clamp(0, oriented.width - 1);
      final x0 = sourceX.floor();
      final x1 = math.min(x0 + 1, oriented.width - 1);
      final fx = sourceX - x0;
      final topLeft = (y0 * oriented.width + x0) * 3;
      final topRight = (y0 * oriented.width + x1) * 3;
      final bottomLeft = (y1 * oriented.width + x0) * 3;
      final bottomRight = (y1 * oriented.width + x1) * 3;
      final i = (y + padY) * 640 + x + padX;
      for (var c = 0; c < 3; c++) {
        final top = pixels[topLeft + c] * (1 - fx) + pixels[topRight + c] * fx;
        final bottom =
            pixels[bottomLeft + c] * (1 - fx) + pixels[bottomRight + c] * fx;
        tensor[c * area + i] = (top * (1 - fy) + bottom * fy).round() / 255;
      }
    }
  }
  return PreparedImage(
    tensor,
    oriented.width,
    oriented.height,
    scale,
    padX,
    padY,
  );
}

class InferenceResult {
  final List<Detection> detections;
  final int width, height, inferenceMs, postprocessMs;
  InferenceResult(
    this.detections,
    this.width,
    this.height,
    this.inferenceMs,
    this.postprocessMs,
  );
}

class YoloInference {
  YoloInference({this.model = DetectionModel.v2});

  final DetectionModel model;
  OrtSession? _session;

  Future<OrtSession> _createSession() async {
    final names = jsonDecode(
      await rootBundle.loadString('assets/models/urutan_kelas.json'),
    ) as List<dynamic>;
    final config = jsonDecode(
      await rootBundle.loadString('assets/models/konfigurasi_aplikasi.json'),
    ) as Map<String, dynamic>;
    if (!listEquals(names, coffeeClasses) ||
        config['file_model'] != DetectionModel.v2.assetPath.split('/').last ||
        config['sha256_model'] !=
            '6bdfb468bd5cec121287cf3f8476d95a1a3d8b00555d26639258e88c1a45cc98' ||
        config['jumlah_kelas'] != coffeeClasses.length ||
        !listEquals(config['masukan']['bentuk'] as List, [1, 3, 640, 640]) ||
        !listEquals(config['keluaran']['bentuk'] as List, [1, 25, 8400])) {
      throw StateError('Konfigurasi model dan urutan kelas tidak sesuai.');
    }
    final session = await OnnxRuntime().createSessionFromAsset(model.assetPath);
    if (!listEquals(session.inputNames, ['images']) ||
        !listEquals(session.outputNames, ['output0'])) {
      await session.close();
      throw StateError(
        'Nama tensor ONNX tidak sesuai dengan model yang diperiksa.',
      );
    }
    return session;
  }

  Future<InferenceResult> detect(
    String path,
    double threshold,
    double iouThreshold,
  ) async {
    final prepared = await compute(prepareImage, path);
    _session ??= await _createSession();
    final input = await OrtValue.fromList(prepared.tensor, [1, 3, 640, 640]);
    Map<String, OrtValue> outputs = {};
    try {
      final watch = Stopwatch()..start();
      outputs = await _session!.run({'images': input});
      final inferenceMs = watch.elapsedMilliseconds;
      final output = outputs['output0'];
      if (output == null ||
          output.shape.length != 3 ||
          output.shape[0] != 1 ||
          output.shape[1] != 25 ||
          output.shape[2] != 8400) {
        throw StateError(
          'Format output ONNX tidak sesuai dengan model yang diperiksa.',
        );
      }
      final raw = await output.asFlattenedList();
      final values = Float32List.fromList(
        raw.cast<num>().map((e) => e.toDouble()).toList(),
      );
      final post = Stopwatch()..start();
      final detections = await compute(decodeYolo, (
        values,
        prepared,
        threshold,
        iouThreshold,
      ));
      return InferenceResult(
        detections,
        prepared.width,
        prepared.height,
        inferenceMs,
        post.elapsedMilliseconds,
      );
    } finally {
      await input.dispose();
      for (final value in outputs.values) {
        await value.dispose();
      }
    }
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }
}

List<Detection> decodeYolo((Float32List, PreparedImage, double, double) args) {
  final (data, image, threshold, iouThreshold) = args;
  const candidates = 8400;
  if (data.length != 25 * candidates) {
    throw const FormatException('Jumlah nilai keluaran ONNX tidak sesuai.');
  }
  final found = <Detection>[];
  for (var i = 0; i < candidates; i++) {
    var bestClass = -1;
    var confidence = threshold;
    for (var c = 0; c < 21; c++) {
      final score = data[(4 + c) * candidates + i];
      if (score.isFinite && score > confidence) {
        confidence = score;
        bestClass = c;
      }
    }
    if (bestClass < 0) continue;
    final cx = data[i];
    final cy = data[candidates + i];
    final w = data[2 * candidates + i];
    final h = data[3 * candidates + i];
    if (![cx, cy, w, h].every((v) => v.isFinite) || w <= 0 || h <= 0) continue;
    // Run NMS on the full input-canvas boxes. Clipping first changes IoU
    // for boxes that cross the letterbox padding or photo edges.
    final left = cx - w / 2;
    final top = cy - h / 2;
    final right = cx + w / 2;
    final bottom = cy + h / 2;
    found.add(Detection(bestClass, confidence, left, top, right, bottom));
  }
  found.sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <Detection>[];
  for (final candidate in found) {
    if (kept.every((other) => _iou(other, candidate) <= iouThreshold)) {
      kept.add(candidate);
    }
    if (kept.length >= 300) break;
  }
  final restored = <Detection>[];
  for (final box in kept) {
    final left = ((box.left - image.padX) / image.scale).clamp(
      0.0,
      image.width.toDouble(),
    );
    final top = ((box.top - image.padY) / image.scale).clamp(
      0.0,
      image.height.toDouble(),
    );
    final right = ((box.right - image.padX) / image.scale).clamp(
      0.0,
      image.width.toDouble(),
    );
    final bottom = ((box.bottom - image.padY) / image.scale).clamp(
      0.0,
      image.height.toDouble(),
    );
    if (right > left && bottom > top) {
      restored.add(
        Detection(box.classId, box.confidence, left, top, right, bottom),
      );
    }
  }
  return restored;
}

double _iou(Detection a, Detection b) {
  final width = math.max(
    0,
    math.min(a.right, b.right) - math.max(a.left, b.left),
  );
  final height = math.max(
    0,
    math.min(a.bottom, b.bottom) - math.max(a.top, b.top),
  );
  final intersection = width * height;
  final areaA = (a.right - a.left) * (a.bottom - a.top);
  final areaB = (b.right - b.left) * (b.bottom - b.top);
  return intersection / (areaA + areaB - intersection);
}
