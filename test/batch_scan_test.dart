import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mutco/data/local_repository.dart';
import 'package:mutco/data/scan_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScanRecord photo(
  String id,
  List<int> classes, {
  List<ScanRecord> others = const [],
  String? path,
}) => ScanRecord(
  id: id,
  name: 'Sampel',
  date: DateTime(2026),
  imagePath: path ?? '$id.jpg',
  width: 640,
  height: 480,
  detections: classes.map((id) => Detection(id, .9, 10, 20, 30, 40)).toList(),
  threshold: .25,
  iouThreshold: .7,
  inferenceMs: 10,
  postprocessMs: 2,
  additionalPhotos: others,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('combines counts and weighted values, and computes percentage from all beans', () {
    final session = photo(
      'one',
      [5, 5, 9, 17],
      others: [
        photo('two', [5, 9, 9, 17, 17, 17]),
      ],
    );
    expect(session.photoCount, 2);
    expect(session.counts, {5: 3, 9: 3, 17: 4});
    expect(session.total, 10);
    expect(session.defective, 6);
    expect(session.defectValue, closeTo(3.6, .0001));
    expect(session.defectPercentage, 60);
    expect(session.totalInferenceMs, 20);
    // Each preview retains its own detection coordinates.
    expect(session.photos.first.detections.length, 4);
    expect(session.photos.last.detections.length, 6);
  });

  test('110-photo session survives JSON roundtrip without double counting', () {
    final session = photo(
      '0',
      [5, 17],
      others: [
        for (var i = 1; i < 110; i++) photo('$i', [5, 17]),
      ],
    );
    final restored = ScanRecord.fromJson(
      jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
    );
    expect(restored.photoCount, 110);
    expect(restored.total, 220);
    expect(restored.defective, 110);
    expect(restored.defectPercentage, 50);
    expect(restored.defectValue, 110);
    expect(restored.grade, 'Mutu 5');
    expect(restored.photos.last.imagePath, '109.jpg');
    expect(
      restored.photos.last.detections.singleWhere((d) => d.classId == 5).left,
      10,
    );
  });

  test('legacy single photo and empty sessions remain readable', () {
    final legacy = photo('legacy', []).toJson()..remove('additionalPhotos');
    final restored = ScanRecord.fromJson(legacy);
    expect(restored.photoCount, 1);
    expect(restored.total, 0);
    expect(restored.defectPercentage, 0);
    expect(restored.grade, 'Tidak dapat dinilai');
    expect(restored.photos.single.imagePath, 'legacy.jpg');
  });

  for (final clearAll in [false, true]) {
    test(
      'save, reopen and ${clearAll ? 'clear' : 'delete'} removes all session images',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = LocalRepository(
          await SharedPreferences.getInstance(),
        );
        final directory = await Directory.systemTemp.createTemp(
          'mutco_batch_test_',
        );
        addTearDown(() async {
          if (await directory.exists()) await directory.delete(recursive: true);
        });
        final files = [
          for (var i = 0; i < 3; i++) File('${directory.path}/$i.jpg'),
        ];
        for (final file in files) {
          await file.writeAsBytes([1, 2, 3]);
        }
        final session = photo(
          'one',
          [5],
          path: files[0].path,
          others: [
            photo('two', [9], path: files[1].path),
            photo('three', [17], path: files[2].path),
          ],
        );
        await repository.save(session);
        final reopened = repository.records.single;
        expect(reopened.total, 3);
        expect(reopened.photoCount, 3);
        reopened.name = 'Updated session';
        await repository.save(reopened);
        expect(repository.records.single.name, 'Updated session');
        if (clearAll) {
          await repository.clear();
        } else {
          await repository.delete(reopened);
        }
        expect(repository.records, isEmpty);
        for (final file in files) {
          expect(await file.exists(), isFalse);
        }
      },
    );
  }
}
