import 'dart:convert';
import 'package:plant_health/core/network/gemini_client.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/domain/entities/chat_message.dart';

/// Parsed assistant answer: the text to show plus the catalog products it
/// points to.
class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.productIds,
    this.userTextBn,
  });

  final String text;
  final List<String> productIds;

  /// The user's last message rewritten in Bangla script, so a question
  /// typed or dictated as "Banglish" is shown in the same script as the
  /// answer. Null when the model didn't return one.
  final String? userTextBn;
}

/// AI chatbot that answers farmer questions using *only* our catalog.
///
/// The full catalog is sent as the system instruction so the model can
/// match symptoms / crops / pests to real products instead of inventing
/// brand names, and it is asked to return the matching ids so the UI can
/// link straight to each product's detail page.
class ProductAssistantService {
  ProductAssistantService(this._gemini, this._products);

  final GeminiClient _gemini;
  final List<AgroProduct> _products;

  /// Older turns are dropped so long chats don't blow up request size/cost.
  static const _maxHistoryMessages = 12;

  late final Set<String> _knownIds = _products.map((p) => p.id).toSet();

  late final String _systemPrompt =
      '''
তুমি "স্মার্ট কৃষি" অ্যাপের কৃষি ওষুধ ও পণ্য বিশেষজ্ঞ সহকারী। বাংলাদেশের কৃষকদের সবসময় সহজ বাংলা অক্ষরে উত্তর দাও — ব্যবহারকারী বাংলা, ইংরেজি বা ইংরেজি অক্ষরে বাংলা (Banglish, যেমন "dhaner majra poka") যেভাবেই লিখুক। পণ্যের ব্র্যান্ড নাম ক্যাটালগের বাংলা নাম অনুযায়ী লিখবে।

নিয়ম:
১. শুধুমাত্র নিচের ক্যাটালগের পণ্য সুপারিশ করবে। ক্যাটালগের বাইরের কোনো ব্র্যান্ড নাম বানাবে না।
২. ব্যবহারকারী ফসল, রোগ, পোকা, লক্ষণ বা পণ্যের নাম বললে — কোন পণ্য কেন কাজে লাগবে, মাত্রা ও প্রয়োগের নিয়ম সংক্ষেপে বলো।
৩. কোনো পণ্য না মিললে সেটা পরিষ্কার বলো এবং স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিতে বলো।
৪. প্রয়োজনে নিরাপত্তা সতর্কতা দাও (মাস্ক, গ্লাভস, ফসল তোলার আগে বিরতি)।
৫. কৃষির বাইরের প্রশ্ন হলে ভদ্রভাবে জানাও যে তুমি শুধু কৃষি পণ্য বিষয়ে সাহায্য করো।
৬. উত্তর ছোট ও বাস্তবসম্মত রাখো (সর্বোচ্চ ৮–১০ লাইন)।

সবসময় শুধু এই JSON ফরম্যাটে উত্তর দেবে:
{"user_text_bn": "<ব্যবহারকারীর সর্বশেষ বার্তা বাংলা অক্ষরে>", "reply": "<উত্তর>", "product_ids": ["<ক্যাটালগের id>", ...]}

"user_text_bn": ব্যবহারকারীর সর্বশেষ বার্তাটি হুবহু অর্থ ঠিক রেখে বাংলা অক্ষরে লেখো (Banglish/ইংরেজি হলে বাংলায় রূপান্তর করো, ভয়েসের ছোটখাটো বানান ভুল ঠিক করো)। আগে থেকেই বাংলায় থাকলে একই রাখো।

ক্যাটালগ (id | নাম | ধরন | উপাদান | ফসল | সমস্যা | মাত্রা):
${_products.map(_catalogLine).join('\n')}
''';

  String _catalogLine(AgroProduct p) => [
    p.id,
    '${p.nameBn} (${p.nameEn})',
    p.category.labelBn,
    p.activeIngredient,
    p.targetCrops.join(', '),
    p.targetProblems.join(', '),
    p.dosage,
  ].join(' | ');

  // Built once: the catalog prompt is the bulk of every request payload.
  late final Map<String, dynamic> _systemInstruction = {
    'parts': [
      {'text': _systemPrompt},
    ],
  };

  /// Structured output: Gemini is forced to return exactly these fields, so
  /// the plain-text fallback in [parseReply] is rarely needed.
  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'user_text_bn': {'type': 'STRING'},
      'reply': {'type': 'STRING'},
      'product_ids': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['user_text_bn', 'reply', 'product_ids'],
    'propertyOrdering': ['user_text_bn', 'reply', 'product_ids'],
  };

  /// Sends the conversation so far (ending with the user's latest message)
  /// and returns the assistant's answer.
  Future<AssistantReply> ask(List<ChatMessage> history) async {
    final valid = history.where((m) => !m.isError).toList();
    final turns = valid.length > _maxHistoryMessages
        ? valid.sublist(valid.length - _maxHistoryMessages)
        : valid;

    final requestBody = {
      'system_instruction': _systemInstruction,
      'contents': [
        for (final m in turns)
          {
            'role': m.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
      ],
      'generationConfig': {
        'temperature': 0.3,
        // Replies are capped at ~10 lines; this bounds latency and cost.
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      },
    };

    final raw = await _gemini.generateText(requestBody);
    return parseReply(raw, _knownIds);
  }

  /// Parses Gemini's JSON answer. Falls back to showing the raw text when
  /// the model ignores the format, and drops ids that aren't in the catalog
  /// so a hallucinated id can never crash the detail page.
  static AssistantReply parseReply(String raw, Set<String> knownIds) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        final text = (decoded['reply'] as String?)?.trim() ?? '';
        final ids = (decoded['product_ids'] as List? ?? const [])
            .whereType<String>()
            .where(knownIds.contains)
            .toSet()
            .toList();
        final userTextBn = (decoded['user_text_bn'] as String?)?.trim();
        if (text.isNotEmpty) {
          return AssistantReply(
            text: text,
            productIds: ids,
            userTextBn: (userTextBn?.isEmpty ?? true) ? null : userTextBn,
          );
        }
      }
    } on FormatException {
      // fall through to plain-text fallback
    }

    return AssistantReply(text: raw.trim(), productIds: const []);
  }
}
