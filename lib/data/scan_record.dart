import '../core/sni_calculator.dart';

class Detection {
  final int classId;
  final double confidence;
  final double left, top, right, bottom;
  const Detection(this.classId, this.confidence, this.left, this.top, this.right, this.bottom);

  Map<String, dynamic> toJson() => {
    'classId': classId, 'confidence': confidence, 'left': left,
    'top': top, 'right': right, 'bottom': bottom,
  };

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
    json['classId'] as int, (json['confidence'] as num).toDouble(),
    (json['left'] as num).toDouble(), (json['top'] as num).toDouble(),
    (json['right'] as num).toDouble(), (json['bottom'] as num).toDouble(),
  );
}

class ScanRecord {
  final String id;
  String name;
  final DateTime date;
  final String imagePath;
  final int width, height;
  final List<Detection> detections;
  final double threshold;
  final double iouThreshold;
  final int inferenceMs, postprocessMs;

  ScanRecord({required this.id, required this.name, required this.date,
    required this.imagePath, required this.width, required this.height,
    required this.detections, required this.threshold, this.iouThreshold = 0.7,
    required this.inferenceMs, required this.postprocessMs});

  Map<int, int> get counts {
    final result = <int, int>{};
    for (final detection in detections) {
      result.update(detection.classId, (value) => value + 1, ifAbsent: () => 1);
    }
    return result;
  }

  int get total => detections.length;
  int get defective => detections.where((d) => d.classId != 17).length;
  double get defectValue => SniCalculator.defectValue(counts);
  String get grade => total == 0 ? 'Tidak dapat dinilai' : SniCalculator.grade(defectValue);
  double get defectPercentage => total == 0 ? 0 : 100 * defective / total;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'date': date.toIso8601String(),
    'imagePath': imagePath, 'width': width, 'height': height,
    'detections': detections.map((e) => e.toJson()).toList(),
    'threshold': threshold, 'iouThreshold': iouThreshold, 'inferenceMs': inferenceMs,
    'postprocessMs': postprocessMs,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    id: json['id'] as String, name: json['name'] as String,
    date: DateTime.parse(json['date'] as String),
    imagePath: json['imagePath'] as String,
    width: json['width'] as int, height: json['height'] as int,
    detections: (json['detections'] as List).map((e) => Detection.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    threshold: (json['threshold'] as num).toDouble(),
    iouThreshold: (json['iouThreshold'] as num?)?.toDouble() ?? 0.45,
    inferenceMs: json['inferenceMs'] as int,
    postprocessMs: json['postprocessMs'] as int,
  );
}
