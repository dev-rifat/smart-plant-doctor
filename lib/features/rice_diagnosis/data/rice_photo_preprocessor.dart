import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum PhotoIssue { tooDark, tooBright, blurry, tooSmall }

class PreparedPhoto {
  const PreparedPhoto(this.input, this.issues);

  /// 224×224×3 RGB, float 0-255, row-major - the model's input tensor.
  final Float32List input;

  /// Ways this photo differs from what the model was trained on.
  final Set<PhotoIssue> issues;
}

/// Prepares a photo the same way training did
/// (`ml/notebooks/train_rice_classifier.py`): the whole photo, no crop,
/// shrunk to 256×256 with area averaging (TF's antialiased resize), then
/// bilinear to 224×224, as raw 0-255 floats. Any difference here silently
/// shifts the model's answers, so keep the two in sync.
abstract final class RicePhotoPreprocessor {
  static const inputSize = 224;
  static const _cacheSize = 256;

  // Training photos (manifest.csv): brightness 84-174 and Laplacian
  // variance >= 104 on a 256px grey image (0.1-99.9th percentiles).
  // Outside these the model is guessing, so ask for a new photo.
  static const _minBrightness = 70.0;
  static const _maxBrightness = 190.0;
  static const _minSharpness = 80.0;
  static const _minSide = 300;

  /// Pure function on bytes so it can run in `compute()`: decoding a phone
  /// photo takes far too long for the UI thread.
  static PreparedPhoto prepare(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Not an image');
    // Phones store rotation in EXIF; apply it so the leaf is upright.
    final photo = img.bakeOrientation(decoded);

    final cached = img.copyResize(
      photo,
      width: _cacheSize,
      height: _cacheSize,
      interpolation: img.Interpolation.average,
    );
    final small = img.copyResize(
      cached,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = Float32List(inputSize * inputSize * 3);
    var i = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final p = small.getPixel(x, y);
        input[i++] = p.r.toDouble();
        input[i++] = p.g.toDouble();
        input[i++] = p.b.toDouble();
      }
    }

    return PreparedPhoto(input, {
      ..._checkQuality(cached),
      if (photo.width < _minSide || photo.height < _minSide)
        PhotoIssue.tooSmall,
    });
  }

  /// Same measures as `inspect_dataset.py`: mean grey level and variance of
  /// the 4-neighbour Laplacian (low = blurry).
  static Set<PhotoIssue> _checkQuality(img.Image square) {
    const n = _cacheSize;
    final grey = Float64List(n * n);
    var sum = 0.0;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final p = square.getPixel(x, y);
        final v = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        grey[y * n + x] = v;
        sum += v;
      }
    }
    final brightness = sum / (n * n);

    var lapSum = 0.0, lapSq = 0.0;
    const count = (n - 2) * (n - 2);
    for (var y = 1; y < n - 1; y++) {
      for (var x = 1; x < n - 1; x++) {
        final c = y * n + x;
        final lap =
            grey[c - 1] + grey[c + 1] + grey[c - n] + grey[c + n] - 4 * grey[c];
        lapSum += lap;
        lapSq += lap * lap;
      }
    }
    final mean = lapSum / count;
    final sharpness = lapSq / count - mean * mean;

    return {
      if (brightness < _minBrightness) PhotoIssue.tooDark,
      if (brightness > _maxBrightness) PhotoIssue.tooBright,
      if (sharpness < _minSharpness) PhotoIssue.blurry,
    };
  }
}
