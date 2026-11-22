typedef ModelValidation = ({
  int photos,
  double precision,
  double recall,
  double map50,
  double map5095,
});

enum DetectionModel {
  v2(
    'v2',
    'MUTCO v2',
    'assets/models/mutco_yolo11s_best_6bdfb468bd5c.onnx',
    '6bdfb468bd5cec121287cf3f8476d95a1a3d8b00555d26639258e88c1a45cc98',
    // SEL 114: evaluation of the exported ONNX on the revised validation set.
    (photos: 90, precision: 82.22, recall: 77.32, map50: 83.61, map5095: 74.04),
  ),
  v1(
    'v1',
    'MUTCO V1',
    'assets/models/mutco_yolo11s_best.onnx',
    '8580261a06f055e6783122e1d0c958066a5658227a5d349660881d13dc1c74ad',
    // Original thesis, Tables 4.7 and 4.11: validation of the original ONNX.
    (photos: 75, precision: 53.47, recall: 55.73, map50: 51.65, map5095: 46.78),
  );

  const DetectionModel(
    this.id,
    this.label,
    this.assetPath,
    this.sha256,
    this.validation,
  );
  final String id;
  final String label;
  final String assetPath;
  final String sha256;

  final ModelValidation validation;

  static DetectionModel? fromId(String? id) {
    for (final model in values) {
      if (model.id == id) return model;
    }
    return null;
  }
}
