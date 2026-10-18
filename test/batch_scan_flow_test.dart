import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mutco/data/local_repository.dart';
import 'package:mutco/data/scan_record.dart';
import 'package:mutco/features/scan_screen.dart';
import 'package:mutco/services/yolo_inference.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestRepository extends LocalRepository {
  TestRepository(super.prefs);
  @override
  Future<String> persistImage(String source, String id) async => source;
}

class TestInference extends YoloInference {
  final calls = <String>[];
  String? failOnce;
  Completer<void>? gate;
  int active = 0, maxActive = 0;

  @override
  Future<InferenceResult> detect(
    String path,
    double threshold,
    double iouThreshold,
  ) async {
    calls.add(path);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (gate != null) await gate!.future;
      if (path == failOnce) {
        failOnce = null;
        throw const FormatException('Unreadable photo');
      }
      return InferenceResult(const [Detection(5, .9, 0, 0, 1, 1)], 2, 2, 10, 1);
    } finally {
      active--;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final retry in [false, true]) {
    testWidgets(
      retry
          ? 'retry processes only failed photos'
          : 'gallery photos run sequentially and produce one combined result',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'mutco_scan_flow_',
        );
        addTearDown(() async {
          imageCache.clear();
          imageCache.clearLiveImages();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (await directory.exists()) await directory.delete(recursive: true);
        });
        final png = img.encodePng(img.Image(width: 2, height: 2));
        final first = File('${directory.path}/first.png')
          ..writeAsBytesSync(png);
        final second = File('${directory.path}/second.png')
          ..writeAsBytesSync(png);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
        const cameraChannel = MethodChannel('plugins.flutter.io/camera');
        messenger.setMockMethodCallHandler(
          pickerChannel,
          (call) async => [first.path, second.path],
        );
        messenger.setMockMethodCallHandler(cameraChannel, (call) async => []);
        addTearDown(() {
          messenger.setMockMethodCallHandler(pickerChannel, null);
          messenger.setMockMethodCallHandler(cameraChannel, null);
        });
        SharedPreferences.setMockInitialValues({});
        final repository = TestRepository(
          await SharedPreferences.getInstance(),
        );
        final inference = TestInference();
        if (retry) inference.failOnce = second.path;
        ScanRecord? result;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('id'),
            supportedLocales: const [Locale('id'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ScanScreen(
                        inference: inference,
                        repository: repository,
                        threshold: .25,
                        iouThreshold: .7,
                        onResult: (record) => result = record,
                      ),
                    ),
                  ),
                  child: const Text('Open scan'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open scan'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(ScanScreen));
          for (final file in [first, second]) {
            await precacheImage(FileImage(file), context);
            if (!context.mounted) return;
            await precacheImage(
              ResizeImage(FileImage(file), width: 150),
              context,
            );
          }
        });
        await tester.tap(find.byIcon(Icons.photo_library_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Analisis (2)'), findsOneWidget);
        if (!retry) inference.gate = Completer<void>();
        await tester.runAsync(() async {
          await tester.tap(find.text('Analisis (2)'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        if (!retry) {
          expect(find.text('Memproses 1 dari 2 foto'), findsOneWidget);
          expect(inference.calls, [first.path]);
          await tester.runAsync(() async {
            inference.gate!.complete();
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
        } else {
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(find.text('Analisis belum lengkap'), findsOneWidget);
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Analisis (2)'));
        }
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.photoCount, 2);
        expect(result!.total, 2);
        expect(result!.counts, {5: 2});
        expect(
          inference.calls,
          retry
              ? [first.path, second.path, second.path]
              : [first.path, second.path],
        );
        expect(inference.maxActive, 1);
        expect(find.text('Open scan'), findsOneWidget);
        expect(find.byType(ScanScreen), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
      },
    );
  }
}
