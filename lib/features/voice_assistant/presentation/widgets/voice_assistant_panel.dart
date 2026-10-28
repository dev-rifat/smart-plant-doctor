import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/core/services/phone_settings.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/features/voice_assistant/data/local_command_responder.dart';
import 'package:plant_health/features/voice_assistant/presentation/cubit/voice_assistant_cubit.dart';

/// Home-screen assistant, shown as a conversation with "কৃষিসাথী": what the
/// farmer said on the right, the answer on the left, one big living mic.
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
        final busy = state.status == VoiceStatus.processing;
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8F5E9), Color(0xFFFFF8E1)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.transcript.isNotEmpty) ...[
                _Bubble(text: state.transcript, fromFarmer: true),
                const SizedBox(height: 8),
              ],
              _Bubble(
                text: busy
                    ? 'একটু ভাবছি…'
                    : state.reply ?? LocalCommandResponder.greeting,
                fromFarmer: false,
                trailing: state.canSpeak && !busy
                    ? _SpeakerButton(state: state, cubit: cubit)
                    : null,
              ),
              if (!state.canSpeak)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 52),
                  child: Text(
                    'এই ফোনে বাংলা কণ্ঠ নেই, তাই উত্তর শুধু লেখায় দেখানো হচ্ছে।',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 22),
              Center(
                child: _LivingMic(state: state, cubit: cubit),
              ),
              const SizedBox(height: 12),
              if (state.voiceProblem && state.status != VoiceStatus.listening)
                const _NoBanglaNote()
              else
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
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'পাঠান',
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: busy ? null : () => _send(cubit),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF66BB6A), AppColors.primaryDark],
        ),
      ),
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
    );
  }
}

/// Chat bubble: the farmer's words on the right, the assistant on the left.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromFarmer, this.trailing});

  final String text;
  final bool fromFarmer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: fromFarmer ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(fromFarmer ? 20 : 4),
          bottomRight: Radius.circular(fromFarmer ? 4 : 20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                height: 1.45,
                color: fromFarmer ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );

    return Row(
      mainAxisAlignment: fromFarmer
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!fromFarmer) ...[const _Avatar(), const SizedBox(width: 10)],
        Flexible(child: bubble),
        if (fromFarmer) ...[
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 21,
            backgroundColor: Color(0xFFFFE0B2),
            child: Icon(Icons.person_rounded, color: Color(0xFF8D6E63)),
          ),
        ],
      ],
    );
  }
}

class _SpeakerButton extends StatelessWidget {
  const _SpeakerButton({required this.state, required this.cubit});

  final VoiceAssistantState state;
  final VoiceAssistantCubit cubit;

  @override
  Widget build(BuildContext context) {
    final speaking = state.status == VoiceStatus.speaking;
    return IconButton.filledTonal(
      tooltip: speaking ? 'থামুন' : 'শুনুন',
      iconSize: 26,
      onPressed: speaking
          ? cubit.stopSpeaking
          : state.reply == null
          ? () => cubit.say(LocalCommandResponder.greeting)
          : cubit.repeat,
      icon: Icon(speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
    );
  }
}

/// Big mic that breathes: rings pulse out while listening, bars dance while
/// the assistant speaks, so a farmer who can't read still sees what's on.
class _LivingMic extends StatefulWidget {
  const _LivingMic({required this.state, required this.cubit});

  final VoiceAssistantState state;
  final VoiceAssistantCubit cubit;

  @override
  State<_LivingMic> createState() => _LivingMicState();
}

class _LivingMicState extends State<_LivingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _animated =>
      widget.state.status == VoiceStatus.listening ||
      widget.state.status == VoiceStatus.speaking;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_LivingMic old) {
    super.didUpdateWidget(old);
    _sync();
  }

  // Animation only runs while something is happening, so idle screens (and
  // widget tests) are still.
  void _sync() {
    if (_animated && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!_animated && _anim.isAnimating) {
      _anim
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.status;
    final listening = status == VoiceStatus.listening;
    final speaking = status == VoiceStatus.speaking;
    final color = listening ? const Color(0xFFE53935) : AppColors.primary;

    return Semantics(
      button: true,
      label: listening ? 'শোনা থামান' : 'মাইক চেপে কথা বলুন',
      child: GestureDetector(
        onTap: listening
            ? widget.cubit.stopListening
            : widget.cubit.startListening,
        child: SizedBox(
          width: 170,
          height: 170,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                if (listening)
                  for (final offset in [0.0, 0.5])
                    _Ring(progress: (_anim.value + offset) % 1, color: color),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withValues(alpha: 0.85), color],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: speaking
                      ? _SoundBars(progress: _anim.value)
                      : Icon(
                          listening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = 104 + 66 * progress;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.45 * (1 - progress)),
          width: 3,
        ),
      ),
    );
  }
}

class _SoundBars extends StatelessWidget {
  const _SoundBars({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 7,
            height:
                14 + 26 * (0.5 + 0.5 * math.sin(2 * math.pi * progress + i)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final VoiceAssistantState state;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (state.status) {
      VoiceStatus.idle => ('মাইক চেপে কথা বলুন', AppColors.primaryDark),
      VoiceStatus.listening => (
        'শুনছি… বলা শেষ হলে একটু থামুন',
        const Color(0xFFE53935),
      ),
      VoiceStatus.processing => ('ভাবছি…', AppColors.primaryDark),
      VoiceStatus.speaking => ('বলছি…', AppColors.primaryDark),
      VoiceStatus.error => (
        state.errorMessage ?? 'সমস্যা হয়েছে',
        const Color(0xFFB3261E),
      ),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown instead of a red error when this phone can't recognise Bangla:
/// short and calm, because everything else still works by tap and text.
class _NoBanglaNote extends StatelessWidget {
  const _NoBanglaNote();

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
              'এই ফোনে বাংলা কথা বোঝা যাচ্ছে না। নিচের বোতাম বা লেখা ব্যবহার করুন।',
              style: TextStyle(fontSize: 15, color: Color(0xFF5D3A00)),
            ),
          ),
          TextButton(
            onPressed: PhoneSettings.openVoiceInput,
            child: const Text('ঠিক করুন', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
