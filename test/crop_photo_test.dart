import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mutco/services/crop_photo.dart';

void main() {
  test('camera photo is cropped to selected square ratio', () async {
    final directory = await Directory.systemTemp.createTemp('mutco_crop_');
    try {
      final path = '${directory.path}/capture.jpg';
      final source = img.Image(width: 400, height: 300);
      await File(path).writeAsBytes(img.encodeJpg(source));
      await cropCameraPhoto((path, 1));
      final result = img.decodeImage(await File(path).readAsBytes())!;
      expect(result.width, 300);
      expect(result.height, 300);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  for (final (label, ratio, expectedWidth, expectedHeight) in [
    ('9:16 portrait', 9 / 16, 675, 1200),
    ('16:9 landscape', 16 / 9, 1600, 900),
  ]) {
    test('camera photo is cropped to $label', () async {
      final directory = await Directory.systemTemp.createTemp('mutco_crop_');
      try {
        final path = '${directory.path}/capture.jpg';
        await File(path)
            .writeAsBytes(img.encodeJpg(img.Image(width: 1600, height: 1200)));
        await cropCameraPhoto((path, ratio));
        final result = img.decodeImage(await File(path).readAsBytes())!;
        expect(result.width, expectedWidth);
        expect(result.height, expectedHeight);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }
}
