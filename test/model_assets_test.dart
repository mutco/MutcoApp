import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutco/core/coffee_classes.dart';
import 'package:mutco/core/detection_model.dart';
import 'package:mutco/services/yolo_inference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled model contract agrees with decoder and class order', () async {
    final config = jsonDecode(
      await rootBundle.loadString('assets/models/konfigurasi_aplikasi.json'),
    ) as Map<String, dynamic>;
    final names = jsonDecode(
      await rootBundle.loadString('assets/models/urutan_kelas.json'),
    );
    expect(names, coffeeClasses);
    expect(config['file_model'], yoloModelAsset.split('/').last);
    expect(
      config['sha256_model'],
      '6bdfb468bd5cec121287cf3f8476d95a1a3d8b00555d26639258e88c1a45cc98',
    );
    expect(config['masukan']['nama_tensor'], 'images');
    expect(config['masukan']['bentuk'], [1, 3, 640, 640]);
    expect(config['keluaran']['nama_tensor'], 'output0');
    expect(config['keluaran']['bentuk'], [1, 25, 8400]);
    expect(config['pascaproses']['confidence'], .25);
    expect(config['pascaproses']['iou_nms'], .70);
    expect(config['pascaproses']['class_agnostic_nms'], isTrue);
    expect(config['pascaproses']['max_det'], 300);
    expect(yoloModelAsset, contains('6bdfb468bd5c'));
    final model = await rootBundle.load(yoloModelAsset);
    expect(model.lengthInBytes, greaterThan(30 * 1024 * 1024));
  });

  test('both model versions have distinct bundled assets', () async {
    expect(DetectionModel.v1.assetPath, isNot(DetectionModel.v2.assetPath));
    expect(DetectionModel.v1.sha256, isNot(DetectionModel.v2.sha256));
    for (final choice in DetectionModel.values) {
      final model = await rootBundle.load(choice.assetPath);
      expect(model.lengthInBytes, greaterThan(1024 * 1024));
      expect(YoloInference(model: choice).model, choice);
    }
  });
}
