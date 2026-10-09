import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Crops a camera JPEG to the aspect ratio shown in the preview.
/// The crop runs in an isolate through `compute` before the review is shown.
Future<String> cropCameraPhoto((String path, double ratio) args) async {
  final (path, ratio) = args;
  final decoded = img.decodeImage(await File(path).readAsBytes());
  if (decoded == null) {
    throw const FormatException('Foto kamera tidak dapat dibaca.');
  }
  final source = img.bakeOrientation(decoded);
  final sourceRatio = source.width / source.height;
  final width = sourceRatio > ratio
      ? math.min(source.width, (source.height * ratio).round())
      : source.width;
  final height = sourceRatio > ratio
      ? source.height
      : math.min(source.height, (source.width / ratio).round());
  final cropped = img.copyCrop(
    source,
    x: (source.width - width) ~/ 2,
    y: (source.height - height) ~/ 2,
    width: width,
    height: height,
  );
  await File(path).writeAsBytes(img.encodeJpg(cropped, quality: 92));
  return path;
}
