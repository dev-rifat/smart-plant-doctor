import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_advice_repository.dart';
import 'package:plant_health/features/rice_diagnosis/data/rice_photo_preprocessor.dart';
import 'package:plant_health/features/rice_diagnosis/domain/rice_diagnosis.dart';

/// Turns a model result into the Bangla shown and spoken to the farmer.
///
/// One place for the wording so the screen and the voice never disagree,
/// and so "নিশ্চিত নই" is said the same way everywhere.
abstract final class DiagnosisWording {
  static String percent(double p) =>
      '${BanglaFormat.digits((p * 100).round())}%';

  static String issue(PhotoIssue issue) => switch (issue) {
    PhotoIssue.tooDark => 'ছবিটি বেশি অন্ধকার।',
    PhotoIssue.tooBright => 'ছবিটিতে আলো বেশি।',
    PhotoIssue.blurry => 'ছবিটি ঝাপসা।',
    PhotoIssue.tooSmall => 'ছবিটি খুব ছোট।',
  };

  static const retakeTip =
      'দিনের আলোয়, কাছ থেকে, আক্রান্ত একটি পাতার পরিষ্কার ছবি তুলুন। হাত স্থির রাখুন।';

  /// Why the model won't give an answer.
  static String uncertainReason(RiceDiagnosis d) {
    if (d.photoIssues.isNotEmpty) return d.photoIssues.map(issue).join(' ');
    if (!d.viewsAgree) {
      return 'ছবির বিভিন্ন অংশে ভিন্ন ভিন্ন রোগের মতো লাগছে, তাই মডেল নিশ্চিত নয়।';
    }
    return 'ছবি দেখে মডেল কোনো রোগের ব্যাপারে যথেষ্ট নিশ্চিত হতে পারছে না।';
  }

  static String headline(RiceDiagnosis d, RiceAdvice advice) {
    if (!d.isConfident) return 'নিশ্চিত হতে পারছি না';
    if (d.top.label == 'Healthy') return 'রোগের স্পষ্ট লক্ষণ দেখা যায়নি';
    return 'সম্ভাব্য রোগ: ${advice.forLabel(d.top.label).nameBn}';
  }

  /// What is read aloud: short, the essentials only; details stay on screen.
  static String speech(RiceDiagnosis d, RiceAdvice advice) {
    if (!d.isConfident) {
      return 'নিশ্চিত হতে পারছি না। ${uncertainReason(d)} $retakeTip '
          'সমস্যা থাকলে কৃষি কর্মকর্তাকে দেখান।';
    }
    final a = advice.forLabel(d.top.label);
    return '${headline(d, advice)}। ${a.about} '
        'যাচাই করুন: ${a.check.first} '
        'এখন করুন: ${a.doNow.join(' ')} '
        '${a.seeOfficer} ${advice.noChemicalAdvice}';
  }
}
