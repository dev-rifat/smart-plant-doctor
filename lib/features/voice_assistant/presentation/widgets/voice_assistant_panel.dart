import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/voice_assistant/data/local_command_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';

/// Home-screen voice assistant: one big mic, what was heard (editable),
/// and the answer with "শুনুন / থামুন".
///
/// Every spoken answer is also shown as text, and every voice action has a
/// tap/typing fallback, because recognition and Bangla TTS are not
/// available or reliable on every phone.
class VoiceAssistantPanel extends StatefulWidget {
  const VoiceAssistantPanel({super.key});

  @override
  State<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends State<VoiceAssistantPanel> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(VoiceAssistantCubit cubit) {
    _focus.unfocus();
    cubit.submit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceAssistantCubit>();

    return BlocConsumer<VoiceAssistantCubit, VoiceAssistantState>(
      // Mirror recognized speech into the field, but never overwrite what
      // the farmer is typing/correcting.
      listenWhen: (a, b) => a.transcript != b.transcript,
      listener: (_, state) {
        if (!_focus.hasFocus) _text.text = state.transcript;
      },
      builder: (context, state) {
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _MicButton(state: state, cubit: cubit),
                const SizedBox(height: 10),
                _StatusLine(state: state),
                const SizedBox(height: 14),
                TextField(
                  controller: _text,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 17),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(cubit),
                  decoration: InputDecoration(
                    hintText: 'অথবা এখানে লিখে প্রশ্ন করুন',
                    suffixIcon: IconButton(
                      tooltip: 'পাঠান',
                      icon: const Icon(Icons.send_rounded),
                      onPressed: state.status == VoiceStatus.processing
                          ? null
                          : () => _send(cubit),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ReplyBox(state: state, cubit: cubit),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.cubit});

  final VoiceAssistantState state;
  final VoiceAssistantCubit cubit;

  @override
  Widget build(BuildContext context) {
    final listening = state.status == VoiceStatus.listening;
    final color = listening ? const Color(0xFFD84343) : AppColors.primary;

    return Semantics(
      button: true,
      label: listening ? 'শোনা থামান' : 'মাইক চেপে কথা বলুন',
      child: GestureDetector(
        onTap: listening ? cubit.stopListening : cubit.startListening,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: listening ? 0.5 : 0.25),
                blurRadius: listening ? 24 : 12,
                spreadRadius: listening ? 6 : 1,
              ),
            ],
          ),
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final VoiceAssistantState state;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (state.status) {
      VoiceStatus.idle => ('মাইক চেপে কথা বলুন', Colors.black87),
      VoiceStatus.listening => ('শুনছি… বলা শেষ হলে একটু থামুন', const Color(0xFFD84343)),
      VoiceStatus.processing => ('ভাবছি…', AppColors.primaryDark),
      VoiceStatus.speaking => ('বলছি…', AppColors.primaryDark),
      VoiceStatus.error => (state.errorMessage ?? 'সমস্যা হয়েছে', const Color(0xFFB3261E)),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.status == VoiceStatus.processing) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 10),
        ],
        if (state.status == VoiceStatus.error) ...[
          Icon(Icons.error_outline_rounded, color: color),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}

class _ReplyBox extends StatelessWidget {
  const _ReplyBox({required this.state, required this.cubit});

  final VoiceAssistantState state;
  final VoiceAssistantCubit cubit;

  @override
  Widget build(BuildContext context) {
    final reply = state.reply ?? LocalCommandResponder.greeting;
    final speaking = state.status == VoiceStatus.speaking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reply, style: const TextStyle(fontSize: 18, height: 1.45)),
          const SizedBox(height: 10),
          if (!state.canSpeak)
            const Text(
              'এই ফোনে বাংলা কণ্ঠ নেই, তাই উত্তর শুধু লেখায় দেখানো হচ্ছে।',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
                onPressed: state.status == VoiceStatus.processing
                    ? null
                    : speaking
                    ? cubit.stopSpeaking
                    : state.reply == null
                    ? () => cubit.say(reply)
                    : cubit.repeat,
                icon: Icon(speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
                label: Text(
                  speaking ? 'থামুন' : 'শুনুন',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
