import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutco/services/yolo_inference.dart';

void main() {
  test('decodes channel-first output and suppresses duplicate boxes', () {
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    for (var i = 0; i < 2; i++) {
      output[i] = 320;
      output[candidates + i] = 320;
      output[2 * candidates + i] = 100;
      output[3 * candidates + i] = 80;
    }
    output[4 * candidates] = .9;
    output[5 * candidates + 1] = .8;
    final image = PreparedImage(Float32List(0), 640, 640, 1, 0, 0);
    final found = decodeYolo((output, image, .25, .70));
    expect(found, hasLength(1));
    expect(found.single.classId, 0);
    expect(found.single.left, 270);
    expect(found.single.top, 280);
  });
  test('IoU threshold changes NMS overlap filtering', () {
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    for (var i = 0; i < 2; i++) {
      output[i] = i == 0 ? 320 : 340;
      output[candidates + i] = 320;
      output[2 * candidates + i] = 100;
      output[3 * candidates + i] = 80;
      output[4 * candidates + i] = i == 0 ? .9 : .8;
    }
    final image = PreparedImage(Float32List(0), 640, 640, 1, 0, 0);
    expect(decodeYolo((output, image, .25, .45)), hasLength(1));
    expect(decodeYolo((output, image, .25, .70)), hasLength(2));
  });
}
