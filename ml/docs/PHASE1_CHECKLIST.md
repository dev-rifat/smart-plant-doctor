# Phase 1 Checklist - KrishiSathi AI

## মূল লক্ষ্য
RiceLeafDiseaseBD ডেটাসেটের সত্যতা নিশ্চিত করা এবং মডেল ওয়ার্কফ্লো নির্ধারণ করা।
বিস্তারিত তথ্য: `PHASE1_FINDINGS.md`

## কাজের তালিকা
- [x] ml/ ওয়ার্কস্পেস তৈরি
- [x] ডেটাসেট ডকুমেন্টেশন ডাউনলোড (`ml/data/raw/_docs/`)
- [x] Metadata বিশ্লেষণ: ক্লাস সংখ্যা, capture timestamp, burst, ডুপ্লিকেট original filename
- [x] ZIP-এর আসল ফোল্ডার কাঠামো যাচাই (README থেকে ভিন্ন)
- [x] `download_dataset.py` (শুধু দরকারি 3.3 GB, CRC যাচাই, resume) - নমুনায় পরীক্ষিত
- [x] `inspect_dataset.py` নতুন করে লেখা - নমুনায় পরীক্ষিত
- [x] `.gitignore`-এ ml data/models/venv যোগ
- [x] পুরো ডেটাসেট ডাউনলোড
- [x] পুরো ডেটাসেটে inspector চালানো → `ml/reports/dataset_inspection.txt`
- [x] Cross-class জোড়া চোখে দেখে সিদ্ধান্ত: dHash ≤6 বাদ (FINDINGS §২.২)
- [x] Section 6 (shortcut risk) পর্যালোচনা: ফোন/orientation ঝুঁকি (FINDINGS §২.৫)
- [x] Group-wise split (`make_splits.py`) - PASS
- [x] আসল সংখ্যা `PHASE1_FINDINGS.md`-এ লেখা

## গ্রহণযোগ্যতা শর্ত (Acceptance Criteria)
- [x] `ml/reports/dataset_inspection.txt` বিদ্যমান, decode failure = 0 অথবা ব্যাখ্যা করা
- [x] প্রতিটি cross-class duplicate-এর সিদ্ধান্ত লেখা (রাখা / বাদ / লেবেল ঠিক)
- [x] Split by `group_id`: কোনো group একাধিক split-এ নেই (স্ক্রিপ্ট দিয়ে যাচাই)
- [x] প্রতিটি split-এ সব ৬ ক্লাস আছে, ক্লাস অনুপাত কাছাকাছি
- [x] Phase 5-এর আগে "GO" সিদ্ধান্ত
