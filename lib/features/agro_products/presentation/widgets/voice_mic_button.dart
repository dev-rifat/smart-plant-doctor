import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/services/voice_input_service.dart';

/// Tap-to-talk mic. Streams recognised words through [onText] while the
/// farmer speaks; tap again (or pause) to stop.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({super.key, required this.onText, this.size = 44});

  final void Function(String text, bool isFinal) onText;
  final double size;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  final VoiceInputService _voice = getIt<VoiceInputService>();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    // Warm up the recognizer so the first tap starts listening instantly.
    _voice.warmUp();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    final started = await _voice.start(
      onText: (text, isFinal) {
        if (!mounted) return;
        widget.onText(text, isFinal);
        if (isFinal) setState(() => _listening = false);
      },
      onStopped: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: _showMessage,
    );

    if (!mounted) return;
    if (!started) {
      setState(() => _listening = false);
      _showMessage('ভয়েস ইনপুট চালু করা যায়নি। মাইক্রোফোনের অনুমতি দিন।');
    } else if (!_voice.supportsBangla) {
      _showMessage(
        'এই ফোনে বাংলা ভয়েস নেই — AI আপনার কথা বাংলায় রূপান্তর করে নেবে।',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    // Detach so a result arriving after the screen closes is dropped.
    _voice.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _listening
        ? const Color(0xFFD84343)
        : const Color(0xFF2E7D32);

    return Tooltip(
      message: _listening ? 'থামান' : 'ভয়েসে বলুন',
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: _listening ? 1 : 0.12),
            shape: BoxShape.circle,
            boxShadow: _listening
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            _listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: _listening ? Colors.white : color,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}
