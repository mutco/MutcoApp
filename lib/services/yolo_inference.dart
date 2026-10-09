import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../data/scan_record.dart';

class PreparedImage {
  final Float32List tensor;
  final int width, height;
  final double scale;
  final int padX, padY;
  PreparedImage(this.tensor, this.width, this.height, this.scale, this.padX, this.padY);
}

Future<PreparedImage> prepareImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Gambar tidak dapat dibaca.');
  final oriented = img.bakeOrientation(decoded);
  final scale = math.min(640 / oriented.width, 640 / oriented.height);
  final width = (oriented.width * scale).round();
  final height = (oriented.height * scale).round();
  final padX = (640 - width) ~/ 2;
  final padY = (640 - height) ~/ 2;
  final resized = img.copyResize(oriented, width: width, height: height,
    interpolation: img.Interpolation.linear);
  final tensor = Float32List(3 * 640 * 640);
  tensor.fillRange(0, tensor.length, 114 / 255);
  const area = 640 * 640;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = resized.getPixel(x, y);
      final i = (y + padY) * 640 + x + padX;
      tensor[i] = pixel.r / 255;
      tensor[area + i] = pixel.g / 255;
      tensor[2 * area + i] = pixel.b / 255;
    }
  }
  return PreparedImage(tensor, oriented.width, oriented.height, scale, padX, padY);
}

class InferenceResult {
  final List<Detection> detections;
  final int width, height, inferenceMs, postprocessMs;
  InferenceResult(this.detections, this.width, this.height, this.inferenceMs, this.postprocessMs);
}

class YoloInference {
  OrtSession? _session;

  Future<InferenceResult> detect(String path, double threshold, double iouThreshold) async {
    final prepared = await compute(prepareImage, path);
    _session ??= await OnnxRuntime().createSessionFromAsset('assets/models/mutco_yolo11s_best.onnx');
    final input = await OrtValue.fromList(prepared.tensor, [1, 3, 640, 640]);
    Map<String, OrtValue> outputs = {};
    try {
      final watch = Stopwatch()..start();
      outputs = await _session!.run({'images': input});
      final inferenceMs = watch.elapsedMilliseconds;
      final output = outputs['output0'];
      if (output == null || output.shape.length != 3 ||
          output.shape[1] != 25 || output.shape[2] != 8400) {
        throw StateError('Format output ONNX tidak sesuai dengan model yang diperiksa.');
      }
      final raw = await output.asFlattenedList();
      final values = Float32List.fromList(raw.cast<num>().map((e) => e.toDouble()).toList());
      final post = Stopwatch()..start();
      final detections = await compute(decodeYolo, (values, prepared, threshold, iouThreshold));
      return InferenceResult(detections, prepared.width, prepared.height,
        inferenceMs, post.elapsedMilliseconds);
    } finally {
      await input.dispose();
      for (final value in outputs.values) { await value.dispose(); }
    }
  }

  Future<void> dispose() async { await _session?.close(); _session = null; }
}

List<Detection> decodeYolo((Float32List, PreparedImage, double, double) args) {
  final (data, image, threshold, iouThreshold) = args;
  const candidates = 8400;
  final found = <Detection>[];
  for (var i = 0; i < candidates; i++) {
    var bestClass = -1;
    var confidence = threshold;
    for (var c = 0; c < 21; c++) {
      final score = data[(4 + c) * candidates + i];
      if (score > confidence) { confidence = score; bestClass = c; }
    }
    if (bestClass < 0) continue;
    final cx = data[i];
    final cy = data[candidates + i];
    final w = data[2 * candidates + i];
    final h = data[3 * candidates + i];
    final left = ((cx - w / 2 - image.padX) / image.scale).clamp(0.0, image.width.toDouble());
    final top = ((cy - h / 2 - image.padY) / image.scale).clamp(0.0, image.height.toDouble());
    final right = ((cx + w / 2 - image.padX) / image.scale).clamp(0.0, image.width.toDouble());
    final bottom = ((cy + h / 2 - image.padY) / image.scale).clamp(0.0, image.height.toDouble());
    if (right <= left || bottom <= top) continue;
    found.add(Detection(bestClass, confidence, left, top, right, bottom));
  }
  found.sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <Detection>[];
  for (final candidate in found) {
    if (kept.every((other) => _iou(other, candidate) < iouThreshold)) {
      kept.add(candidate);
    }
    if (kept.length >= 300) break;
  }
  return kept;
}

double _iou(Detection a, Detection b) {
  final width = math.max(0, math.min(a.right, b.right) - math.max(a.left, b.left));
  final height = math.max(0, math.min(a.bottom, b.bottom) - math.max(a.top, b.top));
  final intersection = width * height;
  final areaA = (a.right - a.left) * (a.bottom - a.top);
  final areaB = (b.right - b.left) * (b.bottom - b.top);
  return intersection / (areaA + areaB - intersection);
}
