import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/navigation/app_router.dart';
import 'package:plant_health/core/services/voice_input_service.dart';
import 'package:plant_health/core/services/voice_output_service.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/onboarding/presentation/cubit/onboarding_cubit.dart'
    show SetupMic;
import 'package:plant_health/features/onboarding/presentation/widgets/assistant_says.dart';
import 'package:plant_health/features/voice_login/data/farmer_account_repository.dart';
import 'package:plant_health/features/voice_login/presentation/login_cubit.dart';

/// Login with mobile number and password; the assistant greets and asks
/// for each, and both can be said or typed.
class VoiceLoginPage extends StatelessWidget {
  const VoiceLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(
        getIt<VoiceInputService>(),
        getIt<VoiceOutputService>(),
        getIt<FarmerAccountRepository>(),
      )..start(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginCubit, LoginState>(
      // Go home once the welcome line has been spoken.
      listenWhen: (a, b) =>
          b.step == LoginStep.success &&
          b.mic == SetupMic.idle &&
          a.mic != SetupMic.idle,
      listener: (context, _) => Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.home,
        (_) => false,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9F4),
        body: SafeArea(
          child: BlocBuilder<LoginCubit, LoginState>(
            builder: (context, state) {
              final cubit = context.read<LoginCubit>();
              final askingPassword = state.step == LoginStep.password;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                children: [
                  const Center(
                    child: Text(
                      'লগইন',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AssistantSays(state.prompt),
                  const SizedBox(height: 28),
                  _Mic(state: state),
                  SizedBox(
                    height: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (state.heard.isNotEmpty)
                          Text(
                            // Never show a spoken password.
                            askingPassword
                                ? 'পাসওয়ার্ড শোনা হয়েছে'
                                : 'আপনি বললেন: "${state.heard}"',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15),
                          ),
                        if (state.hint != null)
                          Text(
                            state.hint!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF8A5300),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (state.step == LoginStep.phone ||
                      state.step == LoginStep.password)
                    _AnswerField(
                      key: ValueKey(state.step),
                      password: askingPassword,
                      onSubmit: cubit.answer,
                    ),
                  if (askingPassword && state.phone != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'নম্বর: ${state.phone}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        TextButton(
                          onPressed: cubit.changePhone,
                          child: const Text('অন্য নম্বর'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: state.step == LoginStep.checking
                        ? null
                        : () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRouter.onboarding,
                            (_) => false,
                          ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'নতুন অ্যাকাউন্ট খুলুন',
                      style: TextStyle(fontSize: 15),
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
}

class _Mic extends StatelessWidget {
  const _Mic({required this.state});

  final LoginState state;

  @override
  Widget build(BuildContext context) {
    final checking = state.step == LoginStep.checking;
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
        (state.step == LoginStep.phone || state.step == LoginStep.password);
    return Column(
      children: [
        Semantics(
          button: canTap,
          label: label,
          child: GestureDetector(
            onTap: canTap ? context.read<LoginCubit>().listenAgain : null,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: state.mic == SetupMic.listening ? 24 : 10,
                    spreadRadius: state.mic == SetupMic.listening ? 6 : 1,
                  ),
                ],
              ),
              child: checking
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Icon(icon, color: Colors.white, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          checking ? 'মিলিয়ে দেখছি…' : label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Number or password box; the password is hidden unless the eye is tapped.
class _AnswerField extends StatefulWidget {
  const _AnswerField({
    super.key,
    required this.password,
    required this.onSubmit,
  });

  final bool password;
  final ValueChanged<String> onSubmit;

  @override
  State<_AnswerField> createState() => _AnswerFieldState();
}

class _AnswerFieldState extends State<_AnswerField> {
  final _text = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      keyboardType: widget.password
          ? TextInputType.visiblePassword
          : TextInputType.phone,
      obscureText: widget.password && _hidden,
      style: const TextStyle(fontSize: 17, letterSpacing: 1.2),
      onSubmitted: widget.onSubmit,
      decoration: InputDecoration(
        hintText: widget.password
            ? 'অথবা পাসওয়ার্ড লিখুন'
            : 'অথবা নম্বর লিখুন',
        prefixIcon: widget.password
            ? IconButton(
                tooltip: _hidden ? 'দেখান' : 'লুকান',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : const Icon(Icons.phone_android_rounded),
        suffixIcon: IconButton(
          icon: const Icon(Icons.send_rounded),
          onPressed: () => widget.onSubmit(_text.text),
        ),
      ),
    );
  }
}
