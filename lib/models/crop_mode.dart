import 'package:flutter/material.dart' show BoxFit;

/// Port of `data/CropMode.kt`.
enum CropMode {
  fit('FIT'),
  fill('FILL'),
  cropCenter('CROP_CENTER'),
  stretch('STRETCH'),
  zoomIn('ZOOM_IN');

  final String storageKey;
  const CropMode(this.storageKey);

  static CropMode fromKey(String? key) =>
      CropMode.values.firstWhere((e) => e.storageKey == key, orElse: () => CropMode.fit);

  String get label {
    switch (this) {
      case CropMode.fit:
        return 'Fit';
      case CropMode.fill:
        return 'Fill';
      case CropMode.cropCenter:
        return 'Crop';
      case CropMode.stretch:
        return 'Stretch';
      case CropMode.zoomIn:
        return 'Zoom In';
    }
  }

  BoxFit get boxFit {
    switch (this) {
      case CropMode.fit:
        return BoxFit.contain;
      case CropMode.fill:
        return BoxFit.cover;
      case CropMode.cropCenter:
        return BoxFit.cover;
      case CropMode.stretch:
        return BoxFit.fill;
      case CropMode.zoomIn:
        return BoxFit.cover;
    }
  }
}
