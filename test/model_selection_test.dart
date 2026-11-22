import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutco/app/mutco_app.dart';
import 'package:mutco/core/detection_model.dart';
import 'package:mutco/data/local_repository.dart';
import 'package:mutco/data/scan_record.dart';
import 'package:mutco/features/scan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('model provenance roundtrips and legacy scans remain unassigned', () {
    final record = ScanRecord(
      id: 'model',
      name: 'Sampel',
      date: DateTime(2026),
      imagePath: '',
      width: 640,
      height: 640,
      detections: const [],
      threshold: .25,
      inferenceMs: 0,
      postprocessMs: 0,
      modelVersion: DetectionModel.v1.id,
    );
    final json =
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;
    expect(ScanRecord.fromJson(json).modelVersion, 'v1');
    json['modelVersion'] = 'v2';
    expect(ScanRecord.fromJson(json).modelVersion, 'v2');
    json.remove('modelVersion');
    expect(ScanRecord.fromJson(json).modelVersion, isNull);
    expect(DetectionModel.fromId(null), isNull);
    expect(DetectionModel.fromId('unknown'), isNull);
  });

  testWidgets('selection persists and the next scan uses the selected model', (
    tester,
  ) async {
    const cameraChannel = MethodChannel('plugins.flutter.io/camera');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(cameraChannel, (call) async => []);
    addTearDown(() => messenger.setMockMethodCallHandler(cameraChannel, null));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = LocalRepository(prefs);
    await tester.pumpWidget(MutcoApp(repository: repository, prefs: prefs));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    for (final choice in [DetectionModel.v1, DetectionModel.v2]) {
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Model Deteksi'));
      await tester.pumpAndSettle();
      final v2 = find.text(DetectionModel.v2.label).last;
      final v1 = find.text(DetectionModel.v1.label).last;
      expect(tester.getTopLeft(v2).dy, lessThan(tester.getTopLeft(v1).dy));
      await tester.tap(find.text(choice.label).last);
      await tester.pumpAndSettle();
      expect(prefs.getString('detection_model'), choice.id);
      expect(
        find.text('ONNX · ${choice.validation.photos} foto validasi'),
        findsOneWidget,
      );
      expect(find.text('Hasil Validasi Model'), findsOneWidget);
      for (final value in [
        choice.validation.precision,
        choice.validation.recall,
        choice.validation.map50,
        choice.validation.map5095,
      ]) {
        expect(
          find.text('${value.toStringAsFixed(2).replaceFirst('.', ',')}%'),
          findsOneWidget,
        );
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pindai'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScanScreen>(find.byType(ScanScreen)).inference.model,
        choice,
      );
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
    }

    // A fresh app instance must restore the persisted choice.
    await prefs.setString('detection_model', 'v1');
    await tester.pumpWidget(
      MutcoApp(
        key: const ValueKey('reopened'),
        repository: repository,
        prefs: prefs,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindai'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScanScreen>(find.byType(ScanScreen)).inference.model,
      DetectionModel.v1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
