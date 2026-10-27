import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_classifier.dart';
import 'package:plant_health/features/rice_diagnosis/presentation/cubit/rice_diagnosis_cubit.dart';
import 'package:plant_health/features/rice_diagnosis/presentation/widgets/diagnosis_result_view.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';

/// "রোগ পরীক্ষা" tab: photo in, on-device model result out. No network.
class RiceDiagnosisPage extends StatelessWidget {
  const RiceDiagnosisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RiceDiagnosisCubit(
        getIt<RiceClassifier>(),
        getIt<RiceAdviceRepository>(),
        getIt<VoiceOutputService>(),
      ),
      child: const _RiceDiagnosisView(),
    );
  }
}

class _RiceDiagnosisView extends StatelessWidget {
  const _RiceDiagnosisView();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final cubit = context.read<RiceDiagnosisCubit>();
    try {
      // 1600px keeps lesions sharp (training photos were 1200x1600) while
      // keeping the on-phone decode quick.
      final file = await getIt<ImagePicker>().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file == null) return; // farmer cancelled
      await cubit.analyze(await file.readAsBytes());
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'ক্যামেরা খোলা যায়নি। সেটিংসে ক্যামেরার অনুমতি দিন।'
                : 'গ্যালারি খোলা যায়নি। সেটিংসে ছবির অনুমতি দিন।',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ধানের রোগ পরীক্ষা'),
        actions: const [VoiceGuideButton(screen: GuideScreen.diagnosis)],
      ),
      body: BlocBuilder<RiceDiagnosisCubit, RiceDiagnosisState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: switch (state.status) {
              DiagnosisStatus.initial => [
                const _PhotoTips(),
                const SizedBox(height: 20),
                _PickButtons(onPick: (s) => _pick(context, s)),
              ],
              DiagnosisStatus.analyzing => [
                _PhotoPreview(state),
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                const Text(
                  'পরীক্ষা করছি…',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
              DiagnosisStatus.failure => [
                _PhotoPreview(state),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFFB3261E),
                  ),
                ),
                const SizedBox(height: 16),
                _PickButtons(onPick: (s) => _pick(context, s)),
              ],
              DiagnosisStatus.result => [
                _PhotoPreview(state),
                const SizedBox(height: 16),
                DiagnosisResultView(
                  diagnosis: state.diagnosis!,
                  advice: state.advice!,
                ),
                const SizedBox(height: 16),
                _PickButtons(onPick: (s) => _pick(context, s), again: true),
              ],
            },
          );
        },
      ),
    );
  }
}

class _PhotoTips extends StatelessWidget {
  const _PhotoTips();

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.wb_sunny_rounded, 'দিনের আলোয় ছবি তুলুন'),
      (Icons.center_focus_strong_rounded, 'কাছ থেকে, আক্রান্ত একটি পাতা'),
      (Icons.pan_tool_rounded, 'হাত স্থির রাখুন, ছবি যেন ঝাপসা না হয়'),
    ];
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF5EC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ধানের পাতার ছবি দিন',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final (icon, text) in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text, style: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'এখন শুধু ধানের ৫টি রোগ চেনে: ব্লাস্ট, বাদামি দাগ, লিফ স্মাট, '
              'টুংরো ও খোল পোড়া। ইন্টারনেট ছাড়াও কাজ করে।',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickButtons extends StatelessWidget {
  const _PickButtons({required this.onPick, this.again = false});

  final void Function(ImageSource) onPick;
  final bool again;

  @override
  Widget build(BuildContext context) {
    const big = Size.fromHeight(64);
    const label = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: big),
          onPressed: () => onPick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_rounded, size: 30),
          label: Text(again ? 'আরেকটি ছবি তুলুন' : 'ছবি তুলুন', style: label),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: big),
          onPressed: () => onPick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_rounded, size: 28),
          label: const Text('গ্যালারি থেকে নিন', style: label),
        ),
      ],
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview(this.state);

  final RiceDiagnosisState state;

  @override
  Widget build(BuildContext context) {
    final photo = state.photo;
    if (photo == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}
