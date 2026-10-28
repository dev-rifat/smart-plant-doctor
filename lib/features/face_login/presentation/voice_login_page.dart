import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/face_login/data/face_embedder.dart';
import 'package:plant_health/features/face_login/presentation/face_camera.dart';
import 'package:plant_health/features/face_login/presentation/login_cubit.dart';
import 'package:plant_health/features/onboarding/data/farmer_profile_repository.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart'
    show SetupMic;
import 'package:plant_health/features/onboarding/presentation/widgets/assistant_says.dart';

/// Shown after a logout: the assistant greets and logs the farmer in by
/// face, or by mobile number when the face doesn't match.
class VoiceLoginPage extends StatelessWidget {
  const VoiceLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(
        getIt<VoiceInputService>(),
        getIt<VoiceOutputService>(),
        getIt<FarmerProfileRepository>(),
        getIt<FaceEmbedder>(),
      )..start(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  Future<void> _takePhoto(BuildContext context) async {
    final cubit = context.read<LoginCubit>();
    final path = await takeFacePhoto(context);
    if (path != null) await cubit.faceTaken(path);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // The assistant asked for a photo: open the camera by itself.
        BlocListener<LoginCubit, LoginState>(
          listenWhen: (a, b) => b.cameraRequest != a.cameraRequest,
          listener: (context, _) => _takePhoto(context),
        ),
        BlocListener<LoginCubit, LoginState>(
          listenWhen: (a, b) =>
              (b.step == LoginStep.success &&
                  b.mic == SetupMic.idle &&
                  a.mic != SetupMic.idle) ||
              (b.step == LoginStep.newFarmer && a.step != LoginStep.newFarmer),
          listener: (context, state) => Navigator.pushNamedAndRemoveUntil(
            context,
            state.step == LoginStep.success
                ? AppRouter.home
                : AppRouter.onboarding,
            (_) => false,
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9F4),
        body: SafeArea(
          child: BlocBuilder<LoginCubit, LoginState>(
            builder: (context, state) {
              final cubit = context.read<LoginCubit>();
              if (state.step == LoginStep.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                children: [
                  const Center(
                    child: Text(
                      'লগইন',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AssistantSays(state.prompt),
                  const SizedBox(height: 28),
                  if (state.step == LoginStep.phone)
                    _PhoneMic(state: state)
                  else
                    FaceCameraButton(
                      label: 'ছবি তুলে লগইন',
                      busy: state.step == LoginStep.checking,
                      onPressed: state.step == LoginStep.face
                          ? () => _takePhoto(context)
                          : null,
                    ),
                  SizedBox(
                    height: 72,
                    child: Center(
                      child: state.hint == null
                          ? null
                          : Text(
                              state.hint!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFF8A5300),
                              ),
                            ),
                    ),
                  ),
                  if (state.step == LoginStep.phone)
                    _PhoneField(onSubmit: cubit.answerPhone),
                  const SizedBox(height: 16),
                  if (state.step == LoginStep.face)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: cubit.usePhone,
                      icon: const Icon(Icons.phone_android_rounded),
                      label: const Text(
                        'মোবাইল নম্বর দিয়ে লগইন',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  if (state.step == LoginStep.phone && state.hasFace)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: cubit.useFace,
                      icon: const Icon(Icons.face_rounded),
                      label: const Text(
                        'মুখের ছবি দিয়ে লগইন',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () => _confirmStartOver(context, cubit),
                    child: const Text(
                      'অন্য কৃষক? নতুন করে শুরু করুন',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmStartOver(BuildContext context, LoginCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('নতুন করে শুরু করবেন?'),
        content: const Text(
          'আগের কৃষকের নাম, নম্বর ও মুখের ছবির তথ্য এই ফোন থেকে মুছে যাবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.startOver();
            },
            child: const Text(
              'মুছে ফেলুন',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMic extends StatelessWidget {
  const _PhoneMic({required this.state});

  final LoginState state;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (state.mic) {
      SetupMic.speaking => (
        Icons.volume_up_rounded,
        AppColors.primaryDark,
        'বলছি…',
      ),
      SetupMic.listening => (
        Icons.mic_rounded,
        const Color(0xFFD84343),
        'শুনছি… নম্বর বলুন',
      ),
      SetupMic.idle => (
        Icons.mic_none_rounded,
        AppColors.primary,
        'মাইক চেপে নম্বর বলুন',
      ),
    };
    return Column(
      children: [
        GestureDetector(
          onTap: state.mic == SetupMic.idle
              ? context.read<LoginCubit>().listenAgain
              : null,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 60),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
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

class _PhoneField extends StatefulWidget {
  const _PhoneField({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 20, letterSpacing: 1.5),
      onSubmitted: widget.onSubmit,
      decoration: InputDecoration(
        hintText: 'অথবা নম্বর লিখুন',
        suffixIcon: IconButton(
          icon: const Icon(Icons.login_rounded),
          onPressed: () => widget.onSubmit(_text.text),
        ),
      ),
    );
  }
}
