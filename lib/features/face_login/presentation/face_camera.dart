import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the front camera for a face photo; null if the farmer cancels.
///
/// Debug builds also offer the gallery, because the emulator's camera has
/// no real face to photograph.
Future<String?> takeFacePhoto(BuildContext context) async {
  var source = ImageSource.camera;
  if (kDebugMode) {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_front_rounded),
              title: const Text('ক্যামেরা'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('গ্যালারি (শুধু পরীক্ষার জন্য)'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return null;
    source = picked;
  }
  final photo = await ImagePicker().pickImage(
    source: source,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1280,
    imageQuality: 92,
  );
  return photo?.path;
}

/// The big round "take a photo" button used at signup and login.
class FaceCameraButton extends StatelessWidget {
  const FaceCameraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    return Column(
      children: [
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: busy ? null : onPressed,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: green.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          busy ? 'মিলিয়ে দেখছি…' : label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: green,
          ),
        ),
      ],
    );
  }
}
