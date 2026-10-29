import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/features/community/data/community_repository.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';

/// Who is posting: the Firebase account plus the name and district from
/// signup. Null when the farmer logged in offline and has no session yet.
Future<({String uid, String name, String district})?> currentFarmer() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return null;
  FarmerProfile? profile;
  try {
    profile = await getIt<FarmerProfileRepository>().load();
  } catch (_) {}
  return (
    uid: user.uid,
    name: profile?.name ?? user.displayName ?? 'কৃষক',
    district: profile?.district ?? '',
  );
}

const notSignedIn = 'প্রশ্ন বা উত্তর দিতে ইন্টারনেট চালু রেখে আবার লগইন করুন।';

/// Ask the community: an optional photo, a short question and details.
class AskQuestionPage extends StatefulWidget {
  const AskQuestionPage({super.key});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Uint8List? _photo;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await getIt<ImagePicker>().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      return _say('আপনার প্রশ্নটি লিখুন।');
    }
    final me = await currentFarmer();
    if (me == null) return _say(notSignedIn);
    setState(() => _sending = true);
    try {
      await getIt<CommunityRepository>().addPost(
        authorId: me.uid,
        authorName: me.name,
        district: me.district,
        title: _title.text,
        body: _body.text,
        photo: _photo,
      );
      if (!mounted) return;
      _say('প্রশ্ন পাঠানো হয়েছে।');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('💬 Post failed: $e');
      if (mounted) _say('পাঠানো যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(title: const Text('কমিউনিটিতে প্রশ্ন করুন')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_photo == null)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('ছবি তুলুন'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('গ্যালারি'),
                ),
              ],
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _photo!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filledTonal(
                    tooltip: 'ছবি সরান',
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          const Text(
            'আক্রান্ত পাতার ছবি দিলে সঠিক উত্তর পাওয়া সহজ হয়।',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          const Text('আপনার প্রশ্ন', style: label),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: CommunityRepository.maxTitle,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'যেমন: ধানের পাতায় বাদামি দাগ, কী করব?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('সমস্যার বর্ণনা', style: label),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            maxLength: CommunityRepository.maxBody,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'পাতার রং, দাগ, পোকা, কবে থেকে, কতটা জমিতে…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('পাঠান', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
