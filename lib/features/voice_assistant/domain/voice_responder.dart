/// Screens a voice command can open. The UI decides how to get there.
enum VoiceAction { openDiseaseCheck, openProfile }

class VoiceReply {
  const VoiceReply(this.text, {this.action});

  /// Bangla answer, shown and read aloud.
  final String text;

  /// Screen to open after answering, if the farmer asked for one.
  final VoiceAction? action;
}

/// Turns what the farmer said into the Bangla answer that is shown and
/// read aloud.
///
/// Kept separate from the voice cubit so the "brain" can change (local
/// command matching now, the secure Gemini backend later) without touching
/// the listening/speaking flow. Throw an [Exception] with a Bangla message
/// to show it to the farmer.
abstract class VoiceResponder {
  Future<VoiceReply> respond(String text);
}
