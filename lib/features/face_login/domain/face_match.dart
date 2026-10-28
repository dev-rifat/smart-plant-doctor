/// Decides whether a login photo shows the farmer from the signup photo.
abstract final class FaceMatch {
  /// Cosine similarity needed to log in. On LFW test pairs with the app's
  /// own crop rule (`ml/face/calibrate_face_threshold.py`) 0.5 let in 80% of
  /// same-person pairs and 0.2% of strangers. LFW pairs are years apart;
  /// two selfies of a farmer are closer, and a miss only means saying the
  /// phone number instead.
  static const threshold = 0.5;

  /// Both embeddings are unit length, so this is their cosine similarity.
  static double similarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  static bool isSamePerson(List<double> signup, List<double> login) =>
      similarity(signup, login) >= threshold;
}
