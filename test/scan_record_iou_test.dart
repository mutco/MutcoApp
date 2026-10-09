import 'package:flutter_test/flutter_test.dart';
import 'package:mutco/data/scan_record.dart';

void main() {
  test('older scans retain their original 45% NMS threshold', () {
    final oldJson = <String, dynamic>{
      'id': 'old', 'name': 'Old scan', 'date': '2026-01-01T00:00:00.000',
      'imagePath': 'old.jpg', 'width': 640, 'height': 640,
      'detections': <Map<String, dynamic>>[], 'threshold': .25,
      'inferenceMs': 1, 'postprocessMs': 1,
    };
    expect(ScanRecord.fromJson(oldJson).iouThreshold, .45);

    final newRecord = ScanRecord.fromJson({...oldJson, 'iouThreshold': .70});
    expect(newRecord.iouThreshold, .70);
    expect(ScanRecord.fromJson(newRecord.toJson()).iouThreshold, .70);
  });
}
