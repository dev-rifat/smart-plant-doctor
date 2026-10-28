import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Why a photo gave no usable face.
enum FaceProblem { noFace, manyFaces, tooSmall, notFacing }

/// A face embedding, or why there is none.
class FaceScan {
  const FaceScan.face(List<double> this.embedding) : problem = null;
  const FaceScan.failed(FaceProblem this.problem) : embedding = null;

  final List<double>? embedding;
  final FaceProblem? problem;
}

abstract class FaceEmbedder {
  Future<FaceScan> scan(String photoPath);
}

/// Finds the face with ML Kit, then turns it into a 192-number embedding
/// with MobileFaceNet (`assets/models/mobilefacenet.tflite`, BSD-3, from
/// MCarlomagno/FaceRecognitionAuth). Both run on the phone, offline.
class MobileFaceNetEmbedder implements FaceEmbedder {
  MobileFaceNetEmbedder({
    this.modelAsset = 'assets/models/mobilefacenet.tflite',
  });

  final String modelAsset;

  static const _size = 112;

  Interpreter? _interpreter;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  @override
  Future<FaceScan> scan(String photoPath) async {
    _interpreter ??= await Interpreter.fromAsset(modelAsset);

    // Upright and smaller first: the camera's EXIF rotation is applied, so
    // ML Kit's face box and our crop see the same picture.
    final upright = await compute(
      _upright,
      await File(photoPath).readAsBytes(),
    );
    final uprightPath = '$photoPath.face.jpg';
    await File(uprightPath).writeAsBytes(upright.jpg);

    final faces = await _detector.processImage(
      InputImage.fromFilePath(uprightPath),
    );
    if (faces.isEmpty) return const FaceScan.failed(FaceProblem.noFace);

    faces.sort((a, b) => _area(b).compareTo(_area(a)));
    final face = faces.first;
    // Two people in the picture: we can't know which one is logging in.
    if (faces.length > 1 && _area(faces[1]) > 0.4 * _area(face)) {
      return const FaceScan.failed(FaceProblem.manyFaces);
    }
    if (face.boundingBox.width < upright.width * 0.2) {
      return const FaceScan.failed(FaceProblem.tooSmall);
    }
    // A face turned sideways gives a different embedding.
    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (yaw.abs() > 25 || roll.abs() > 25) {
      return const FaceScan.failed(FaceProblem.notFacing);
    }

    final box = face.boundingBox;
    final input = await compute(_cropFace, (
      upright.jpg,
      box.left,
      box.top,
      box.width,
      box.height,
    ));
    final output = [List<double>.filled(192, 0)];
    _interpreter!.run(input.buffer.asUint8List(), output);
    return FaceScan.face(normalize(output.first));
  }

  static double _area(Face f) => f.boundingBox.width * f.boundingBox.height;

  /// Unit length, so comparing two faces is a plain dot product.
  static List<double> normalize(List<double> v) {
    final norm = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
    return norm == 0 ? v : [for (final x in v) x / norm];
  }

  static ({Uint8List jpg, int width}) _upright(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Not an image');
    var photo = img.bakeOrientation(decoded);
    if (math.max(photo.width, photo.height) > 960) {
      photo = photo.width >= photo.height
          ? img.copyResize(photo, width: 960)
          : img.copyResize(photo, height: 960);
    }
    return (jpg: img.encodeJpg(photo, quality: 92), width: photo.width);
  }

  /// Square crop around the face box with a 10% margin each side, resized
  /// to 112×112 and scaled to [-1, 1] - the same rule used to pick the
  /// match threshold (`ml/face/calibrate_face_threshold.py`).
  static Float32List _cropFace(
    (Uint8List, double, double, double, double) args,
  ) {
    final (jpg, left, top, width, height) = args;
    final photo = img.decodeJpg(jpg)!;
    final side = math.max(width, height) * 1.2;
    final cx = left + width / 2, cy = top + height / 2;
    final x0 = math.max(0, (cx - side / 2).round());
    final y0 = math.max(0, (cy - side / 2).round());
    final x1 = math.min(photo.width, (cx + side / 2).round());
    final y1 = math.min(photo.height, (cy + side / 2).round());
    final face = img.copyResize(
      img.copyCrop(photo, x: x0, y: y0, width: x1 - x0, height: y1 - y0),
      width: _size,
      height: _size,
      interpolation: img.Interpolation.linear,
    );
    final out = Float32List(_size * _size * 3);
    var i = 0;
    for (final p in face) {
      out[i++] = (p.r - 127.5) / 128;
      out[i++] = (p.g - 127.5) / 128;
      out[i++] = (p.b - 127.5) / 128;
    }
    return out;
  }
}
