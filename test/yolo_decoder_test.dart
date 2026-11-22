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

  test('NMS uses unclipped boxes before restoring a letterboxed photo', () {
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    // Box A: (270,50)-(370,250); box B: (270,160)-(370,260).
    // Full-canvas IoU is 0.4286. Clipping at padding y=160 first
    // would incorrectly raise IoU to 0.9 and suppress box B.
    for (var i = 0; i < 2; i++) {
      output[i] = 320;
      output[candidates + i] = i == 0 ? 150 : 210;
      output[2 * candidates + i] = 100;
      output[3 * candidates + i] = i == 0 ? 200 : 100;
      output[4 * candidates + i] = i == 0 ? .9 : .8;
    }
    final image = PreparedImage(Float32List(0), 640, 320, 1, 0, 160);
    final found = decodeYolo((output, image, .25, .70));
    expect(found, hasLength(2));
    expect(found.first.top, 0);
    expect(found.first.bottom, 90);
    expect(found.last.top, 0);
    expect(found.last.bottom, 100);
  });

  test('NMS keeps boxes with IoU exactly at its threshold', () {
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    for (var i = 0; i < 2; i++) {
      output[i] = 320;
      output[candidates + i] = 320;
      output[2 * candidates + i] = 100;
      output[3 * candidates + i] = 80;
      output[4 * candidates + i] = i == 0 ? .9 : .8;
    }
    final image = PreparedImage(Float32List(0), 640, 640, 1, 0, 0);
    expect(decodeYolo((output, image, .25, 1)), hasLength(2));
  });

  test('restores scale and padding after NMS', () {
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    output[0] = 320;
    output[candidates] = 320;
    output[2 * candidates] = 100;
    output[3 * candidates] = 80;
    output[(4 + 20) * candidates] = .9;
    final image = PreparedImage(Float32List(0), 320, 640, 1, 160, 0);
    final found = decodeYolo((output, image, .25, .70));
    expect(found.single.classId, 20);
    expect(found.single.left, 110);
    expect(found.single.right, 210);
    expect(found.single.top, 280);
    expect(found.single.bottom, 360);
    final scaled = PreparedImage(Float32List(0), 1280, 1280, .5, 0, 0);
    final large = decodeYolo((output, scaled, .25, .70));
    expect(large.single.left, 540);
    expect(large.single.right, 740);
    expect(large.single.top, 560);
    expect(large.single.bottom, 720);
  });

  test('rejects malformed output and skips non-finite candidates', () {
    final image = PreparedImage(Float32List(0), 640, 640, 1, 0, 0);
    expect(
      () => decodeYolo((Float32List(25), image, .25, .70)),
      throwsFormatException,
    );
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    output[0] = double.nan;
    output[candidates] = 320;
    output[2 * candidates] = 100;
    output[3 * candidates] = 80;
    output[4 * candidates] = .9;
    expect(decodeYolo((output, image, .25, .70)), isEmpty);
  });

  test('limits detections to 300 after class-agnostic NMS', () {
    const candidates = 8400;
    final output = Float32List(25 * candidates);
    for (var i = 0; i < 301; i++) {
      output[i] = 5 + (i % 31) * 20;
      output[candidates + i] = 5 + (i ~/ 31) * 20;
      output[2 * candidates + i] = 2;
      output[3 * candidates + i] = 2;
      output[4 * candidates + i] = .9;
    }
    final image = PreparedImage(Float32List(0), 640, 640, 1, 0, 0);
    expect(decodeYolo((output, image, .25, .70)), hasLength(300));
  });
}
