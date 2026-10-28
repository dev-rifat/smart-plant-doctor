import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/core/services/phone_settings.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/face_login/data/face_embedder.dart';
import 'package:plant_health/features/face_login/presentation/face_camera.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/onboarding/domain/bangla_answers.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:plant_health/features/onboarding/presentation/widgets/assistant_says.dart';

/// First launch: the assistant talks the farmer through setup. No password,
/// nothing to read; typing and buttons are there only as a fallback.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(
        getIt<VoiceInputService>(),
        getIt<VoiceOutputService>(),
        getIt<FarmerProfileRepository>(),
        getIt<FaceEmbedder>(),
      )..start(),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Leave once the goodbye line has been spoken.
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (a, b) =>
              b.step == SetupStep.done &&
              b.mic == SetupMic.idle &&
              a.mic != SetupMic.idle,
          listener: (context, _) => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.home,
            (_) => false,
          ),
        ),
        // The assistant asked for the face photo: open the camera itself.
        BlocListener<OnboardingCubit, OnboardingState>(
          listenWhen: (a, b) => b.cameraRequest != a.cameraRequest,
          listener: (context, _) => _takeFacePhoto(context),
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9F4),
        body: SafeArea(
          child: BlocBuilder<OnboardingCubit, OnboardingState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                _Progress(step: state.step),
                const SizedBox(height: 24),
                AssistantSays(state.prompt),
                const SizedBox(height: 28),
                if (state.step == SetupStep.face)
                  FaceCameraButton(
                    label: 'ছবি তুলুন',
                    busy: state.prompt == 'ছবি দেখছি…',
                    onPressed: () => _takeFacePhoto(context),
                  )
                else
                  _MicIndicator(state: state),
                // Fixed height, so buttons below never jump when a hint
                // appears or disappears (a farmer's tap would miss).
                SizedBox(
                  height: 84,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state.heard.isNotEmpty)
                        Text(
                          'আপনি বললেন: "${state.heard}"',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18),
                        ),
                      if (state.hint != null)
                        Text(
                          state.hint!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF8A5300),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Fallback(state: state),
                // Below the answer box, so the box never moves when it shows.
                if (state.voiceProblem) ...[
                  const SizedBox(height: 16),
                  const _VoiceFixCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _takeFacePhoto(BuildContext context) async {
  final cubit = context.read<OnboardingCubit>();
  final path = await takeFacePhoto(context);
  if (path != null) await cubit.faceTaken(path);
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final SetupStep step;

  @override
  Widget build(BuildContext context) {
    final index = switch (step) {
      SetupStep.name || SetupStep.confirmName => 0,
      SetupStep.district => 1,
      SetupStep.crop => 2,
      SetupStep.phone || SetupStep.confirmPhone => 3,
      SetupStep.face => 4,
      _ => 5,
    };
    const labels = ['নাম', 'জেলা', 'ফসল', 'মোবাইল', 'মুখ'];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < labels.length; i++)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              i < index ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: i <= index ? AppColors.primary : Colors.black38,
            ),
            label: Text(labels[i], style: const TextStyle(fontSize: 15)),
          ),
      ],
    );
  }
}

class _MicIndicator extends StatelessWidget {
  const _MicIndicator({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final busy = state.step == SetupStep.saving;
    final (IconData icon, Color color, String label) = switch (state.mic) {
      SetupMic.speaking => (
        Icons.volume_up_rounded,
        AppColors.primaryDark,
        'বলছি…',
      ),
      SetupMic.listening => (
        Icons.mic_rounded,
        const Color(0xFFD84343),
        'শুনছি… এখন বলুন',
      ),
      SetupMic.idle => (
        Icons.mic_none_rounded,
        AppColors.primary,
        'মাইক চেপে বলুন',
      ),
    };
    final canTap =
        state.mic == SetupMic.idle &&
        !busy &&
        state.step != SetupStep.done &&
        state.step != SetupStep.failed;

    return Column(
      children: [
        Semantics(
          button: canTap,
          label: label,
          child: GestureDetector(
            onTap: canTap ? cubit.listenAgain : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: state.mic == SetupMic.listening ? 30 : 12,
                    spreadRadius: state.mic == SetupMic.listening ? 8 : 1,
                  ),
                ],
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Icon(icon, color: Colors.white, size: 60),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          // The hint below already says what to do; don't say it twice.
          state.mic == SetupMic.idle && state.hint != null ? '' : label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _VoiceFixCard extends StatelessWidget {
  const _VoiceFixCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_off_rounded, color: Color(0xFF8A5300)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'এই ফোনে বাংলা কথা বোঝা যাচ্ছে না। লিখে বা বেছে নিয়ে উত্তর দিন।',
              style: TextStyle(fontSize: 15, color: Color(0xFF5D3A00)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final opened = await PhoneSettings.openVoiceInput();
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('সেটিং খোলা যায়নি।')),
                );
              }
            },
            child: const Text('ঠিক করুন', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// Buttons and a text box for the current question, for when speaking
/// doesn't work or the farmer prefers to tap.
class _Fallback extends StatefulWidget {
  const _Fallback({required this.state});

  final OnboardingState state;

  @override
  State<_Fallback> createState() => _FallbackState();
}

class _FallbackState extends State<_Fallback> {
  final _text = TextEditingController();

  @override
  void didUpdateWidget(_Fallback old) {
    super.didUpdateWidget(old);
    if (old.state.step != widget.state.step) _text.clear();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDistrict(
    BuildContext context,
    OnboardingCubit cubit,
  ) async {
    final districts = [...BanglaAnswers.districts]..sort();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: ListView.separated(
          itemCount: districts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => ListTile(
            title: Text(districts[i], style: const TextStyle(fontSize: 20)),
            onTap: () => Navigator.pop(context, districts[i]),
          ),
        ),
      ),
    );
    if (picked != null) await cubit.answer(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final s = widget.state;
    const big = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);

    switch (s.step) {
      case SetupStep.confirmName || SetupStep.confirmPhone:
        return Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: () => cubit.answer('হ্যাঁ'),
                child: const Text('হ্যাঁ', style: big),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: () => cubit.answer('না'),
                child: const Text('না', style: big),
              ),
            ),
          ],
        );
      case SetupStep.crop:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final crop in BanglaAnswers.crops.keys)
              ActionChip(
                label: Text(crop, style: const TextStyle(fontSize: 19)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                onPressed: () => cubit.answer(crop),
              ),
          ],
        );
      case SetupStep.name || SetupStep.district:
        final field = TextField(
          controller: _text,
          style: const TextStyle(fontSize: 19),
          textInputAction: TextInputAction.done,
          onSubmitted: cubit.answer,
          decoration: InputDecoration(
            hintText: s.step == SetupStep.name
                ? 'অথবা নাম লিখুন'
                : 'অথবা জেলার নাম লিখুন',
            suffixIcon: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () => cubit.answer(_text.text),
            ),
          ),
        );
        if (s.step == SetupStep.name) return field;
        // Typing a district is hard for many farmers: offer the list.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => _pickDistrict(context, cubit),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text(
                'তালিকা থেকে জেলা বেছে নিন',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),
            field,
          ],
        );
      case SetupStep.phone:
        return TextField(
          controller: _text,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 20, letterSpacing: 1.5),
          onSubmitted: cubit.answer,
          decoration: InputDecoration(
            hintText: 'অথবা নম্বর লিখুন',
            suffixIcon: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () => cubit.answer(_text.text),
            ),
          ),
        );
      case SetupStep.face:
        return TextButton(
          onPressed: cubit.skipFace,
          child: const Text(
            'এখন না, পরে (লগইন হবে মোবাইল নম্বরে)',
            style: TextStyle(fontSize: 16),
          ),
        );
      case SetupStep.failed:
        return FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          onPressed: cubit.retry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('আবার চেষ্টা করুন', style: big),
        );
      case SetupStep.saving || SetupStep.done:
        return const SizedBox.shrink();
    }
  }
}
