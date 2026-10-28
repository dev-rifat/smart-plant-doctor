import 'package:plant_health/core/utils/bangla_format.dart';

/// Understands short spoken answers during the voice setup: yes/no, a
/// name, one of Bangladesh's 64 districts, a crop.
///
/// Speech recognition spells the same word in several ways (বগুড়া / বগুরা,
/// নোয়াখালী / নোয়াখালি), so matching works on a loosened spelling.
abstract final class BanglaAnswers {
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll('ড়', 'র')
      .replaceAll('ঢ়', 'র')
      .replaceAll('য়', 'য')
      .replaceAll('ী', 'ি')
      .replaceAll('ূ', 'ু')
      .replaceAll('ঁ', '')
      .replaceAll('ৎ', 'ত')
      .replaceAll(RegExp('[।,.!?"\'-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const _yes = [
    'হ্যাঁ',
    'হ্যা',
    'হা',
    'হাঁ',
    'জি',
    'জ্বি',
    'ঠিক',
    'সঠিক',
    'আচ্ছা',
    'ok',
    'okay',
    'yes',
    'ha',
    'hya',
  ];
  static const _no = ['না', 'ভুল', 'নাহ', 'no', 'na', 'abar', 'আবার'];

  /// true = yes, false = no, null = unclear (ask again).
  static bool? yesNo(String text) {
    final words = normalize(text).split(' ');
    // "না" is checked first: "ঠিক না" means no.
    if (words.any((w) => _no.map(normalize).contains(w))) return false;
    if (words.any((w) => _yes.map(normalize).contains(w))) return true;
    return null;
  }

  static const _namePrefixes = [
    'আমার নাম',
    'আমার নাম হলো',
    'আমার নাম হল',
    'নাম',
    'আমি',
    'my name is',
  ];
  static const _nameSuffixes = ['বলে', 'হয়', 'আমার নাম'];

  /// "আমার নাম করিম মিয়া" → "করিম মিয়া". Null if nothing usable is left.
  static String? name(String text) {
    var t = text
        .replaceAll(RegExp(r'[।,.!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    for (final p in [..._namePrefixes]..sort((a, b) => b.length - a.length)) {
      if (t == p || t.startsWith('$p ')) {
        t = t.substring(p.length).trim();
        break;
      }
    }
    for (final s in _nameSuffixes) {
      if (t.endsWith(' $s')) t = t.substring(0, t.length - s.length).trim();
    }
    if (t.isEmpty || t.length > 40) return null;
    return t;
  }

  /// All 64 districts, official Bangla spelling.
  static const districts = [
    // Dhaka
    'ঢাকা', 'ফরিদপুর', 'গাজীপুর', 'গোপালগঞ্জ', 'কিশোরগঞ্জ', 'মাদারীপুর',
    'মানিকগঞ্জ',
    'মুন্সীগঞ্জ',
    'নারায়ণগঞ্জ',
    'নরসিংদী',
    'রাজবাড়ী',
    'শরীয়তপুর',
    'টাঙ্গাইল',
    // Chattogram
    'চট্টগ্রাম',
    'কক্সবাজার',
    'বান্দরবান',
    'রাঙ্গামাটি',
    'খাগড়াছড়ি',
    'কুমিল্লা',
    'ব্রাহ্মণবাড়িয়া', 'চাঁদপুর', 'ফেনী', 'লক্ষ্মীপুর', 'নোয়াখালী',
    // Rajshahi
    'রাজশাহী', 'বগুড়া', 'জয়পুরহাট', 'নওগাঁ', 'নাটোর', 'চাঁপাইনবাবগঞ্জ',
    'পাবনা', 'সিরাজগঞ্জ',
    // Khulna
    'খুলনা',
    'বাগেরহাট',
    'চুয়াডাঙ্গা',
    'যশোর',
    'ঝিনাইদহ',
    'কুষ্টিয়া',
    'মাগুরা',
    'মেহেরপুর', 'নড়াইল', 'সাতক্ষীরা',
    // Barishal
    'বরিশাল', 'বরগুনা', 'ভোলা', 'ঝালকাঠি', 'পটুয়াখালী', 'পিরোজপুর',
    // Sylhet
    'সিলেট', 'হবিগঞ্জ', 'মৌলভীবাজার', 'সুনামগঞ্জ',
    // Rangpur
    'রংপুর', 'দিনাজপুর', 'গাইবান্ধা', 'কুড়িগ্রাম', 'লালমনিরহাট', 'নীলফামারী',
    'পঞ্চগড়', 'ঠাকুরগাঁও',
    // Mymensingh
    'ময়মনসিংহ', 'জামালপুর', 'নেত্রকোনা', 'শেরপুর',
  ];

  /// Common other spellings/romanisations the recogniser or a keyboard
  /// produces, mapped to the official name.
  static const _districtAliases = {
    'চিটাগাং': 'চট্টগ্রাম',
    'চট্রগ্রাম': 'চট্টগ্রাম',
    'কুমিলা': 'কুমিল্লা',
    'রাঙামাটি': 'রাঙ্গামাটি',
    'টাঙাইল': 'টাঙ্গাইল',
    'চুয়াডাঙা': 'চুয়াডাঙ্গা',
    'যশোহর': 'যশোর',
    'বরিশাল': 'বরিশাল',
    'নবাবগঞ্জ': 'চাঁপাইনবাবগঞ্জ',
    'মৈমনসিংহ': 'ময়মনসিংহ',
    'নেত্রকোণা': 'নেত্রকোনা',
    'dhaka': 'ঢাকা',
    'rangpur': 'রংপুর',
    'bogura': 'বগুড়া',
    'bogra': 'বগুড়া',
    'rajshahi': 'রাজশাহী',
    'khulna': 'খুলনা',
    'sylhet': 'সিলেট',
    'barishal': 'বরিশাল',
    'mymensingh': 'ময়মনসিংহ',
    'gazipur': 'গাজীপুর',
    'chittagong': 'চট্টগ্রাম',
    'comilla': 'কুমিল্লা',
    'dinajpur': 'দিনাজপুর',
  };

  /// Finds a district named anywhere in the answer ("আমি রংপুর জেলায়
  /// থাকি" → রংপুর). Longest match wins (চাঁপাইনবাবগঞ্জ over নবাবগঞ্জ).
  static String? district(String text) {
    final t = normalize(text);
    String? best;
    var bestLength = 0;
    void consider(String spoken, String official) {
      final n = normalize(spoken);
      if (n.length > bestLength && t.contains(n)) {
        best = official;
        bestLength = n.length;
      }
    }

    for (final d in districts) {
      consider(d, d);
    }
    _districtAliases.forEach(consider);
    return best;
  }

  static const crops = {
    'ধান': ['ধান', 'চাল', 'dhan', 'rice', 'বোরো', 'আমন', 'আউশ'],
    'গম': ['গম', 'wheat'],
    'পাট': ['পাট', 'jute'],
    'ভুট্টা': ['ভুট্টা', 'ভুটা', 'maize', 'corn'],
    'আলু': ['আলু', 'potato'],
    'সবজি': ['সবজি', 'শাক', 'বেগুন', 'টমেটো', 'লাউ', 'vegetable'],
    'ডাল': ['ডাল', 'মসুর', 'মুগ'],
    'সরিষা': ['সরিষা', 'সর্ষে', 'mustard'],
  };

  /// "আমি ধান চাষ করি" → ধান. Null if no known crop is named.
  static String? crop(String text) {
    final t = normalize(text);
    for (final entry in crops.entries) {
      if (entry.value.any((w) => t.contains(normalize(w)))) return entry.key;
    }
    return null;
  }

  /// Spoken digits, as the recognizer may write them out.
  static const _digitWords = {
    'শূন্য': '0', 'শুন্য': '0', 'জিরো': '0', 'zero': '0',
    'এক': '1', 'ওয়ান': '1', 'one': '1',
    'দুই': '2', 'দু': '2', 'টু': '2', 'two': '2',
    'তিন': '3', 'থ্রি': '3', 'three': '3',
    'চার': '4', 'ফোর': '4', 'four': '4',
    'পাঁচ': '5', 'ফাইভ': '5', 'five': '5',
    // য় comes either as one character or as য + nukta.
    'ছ\u09DF': '6', 'ছ\u09AF\u09BC': '6', 'ছ': '6', 'সিক্স': '6', 'six': '6',
    'সাত': '7', 'সেভেন': '7', 'seven': '7',
    'আট': '8', 'এইট': '8', 'eight': '8',
    'ন\u09DF': '9', 'ন\u09AF\u09BC': '9', 'নাইন': '9', 'nine': '9',
  };

  /// A Bangladeshi mobile number as 11 ASCII digits ("01712345678"), from
  /// digits in either script, spoken digit words, or with +88; else null.
  static String? phone(String text) {
    final words = {
      for (final e in _digitWords.entries) normalize(e.key): e.value,
    };
    final digits = StringBuffer();
    final t = normalize(BanglaFormat.asciiDigits(text)).replaceAll('+', ' ');
    for (final token in t.split(' ')) {
      if (RegExp(r'^\d+$').hasMatch(token)) {
        digits.write(token);
      } else if (words[token] != null) {
        digits.write(words[token]);
      }
    }
    var number = digits.toString();
    if (number.length == 13 && number.startsWith('88')) {
      number = number.substring(2);
    }
    return RegExp(r'^01[3-9]\d{8}$').hasMatch(number) ? number : null;
  }

  /// "০ ১ ৭ ১ ২ …" so the number is read out digit by digit.
  static String spokenPhone(String phone) =>
      BanglaFormat.digits(phone.split('').join(' '));
}
