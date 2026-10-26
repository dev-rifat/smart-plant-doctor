# Phase 1 Findings - RiceLeafDiseaseBD v3

তারিখ: 2026-10-26
উৎস: Mendeley README, `Dataset metadata.xlsx`, এবং পুরো ডেটাসেটে `inspect_dataset.py` ও `make_splits.py` চালানোর ফল।
পূর্ণ রিপোর্ট: `ml/reports/dataset_inspection.txt`, `ml/reports/split_report.txt`
কাঁচা ডকুমেন্টেশন: `ml/data/raw/_docs/`

## ১) ডেটাসেট (verified)

| বিষয় | তথ্য |
|---|---|
| লাইসেন্স | CC BY 4.0 - অ্যাপে ও রিপোর্টে citation দিতে হবে |
| DOI | 10.17632/86s4jzj2m4.3 |
| মোট ছবি | 9,769 - সব খোলে (decode failure 0), সব 1024×1024 RGB JPEG |
| ক্লাস (৬টি) | Rice Tungro 2244, Brown spot 2178, Sheath blight 1722, Healthy 1575, Blast 1326, Leaf smut 724 |
| ইমব্যালেন্স | 3.1x → class weights দরকার |
| মূল ছবি | বেশিরভাগ 1200×1600 / 1600×1200 (3:4), পরে 1024×1024 করা |
| স্থান / সময় | শুধু Gazipur, 2025-04-01 থেকে 2025-05-03 (১৩ দিন), একটি মৌসুম, BRRI dhan28/29 |
| ডাউনলোড | দরকারি অংশ 3.31 GB (`download_dataset.py`), ~৩৭ মিনিট |

ZIP-এর আসল কাঠামো README থেকে ভিন্ন:

```
RiceLeafDiseaseBD/
├── Dataset metadata.xlsx
├── Original images/<Class>/<class>_<n>.jpg                      ← classification-এ এটাই ব্যবহার
└── Annotated images ( visual with labels)/<Class>/
    ├── visuals/*.jpg    ← লাল বক্স আঁকা ছবি - কখনো ট্রেনিং-এ নয় (ডাউনলোডই করা হয়নি)
    └── labels/*.txt     ← YOLO বক্স (Healthy নেই)
```

## ২) পাওয়া সমস্যা ও সমাধান

1. **Burst leakage।** অনেক ছবি সেকেন্ডের ব্যবধানে তোলা, অনেক সময় দুটি ফোনে একই সেকেন্ডে, আবার burst mode (`_01`, `_02`)। পরিমাপ: একই ক্লাসে পরপর তোলা ছবির ব্যবধান <2s হলে প্রায় একই ছবি (median dHash 10)। ব্যবধান ≥5s হলে random জোড়ার মতো আলাদা (median ~30)। তাই প্রতিটি ক্লাসের ভেতরে ≤10s = এক burst। ফল: 2,302 burst, 2,249 leakage group (সবচেয়ে বড়টিতে 101টি ছবি)। প্রথমে 60s নেওয়া হয়েছিল, তাতে পুরো session এক group-এ (900+ ছবি) মিলে যায়, তাই বাতিল।
2. **একই পাতা, দুই রোগের লেবেল (label conflict)।** 8টি ছবি হুবহু একই ফাইল হয়েও দুই ক্লাসে আছে। এছাড়া প্রায় একই ছবি (dHash ≤4) ভিন্ন ক্লাসে আছে, চোখে দেখে নিশ্চিত হওয়া গেছে এগুলো একই পাতা (যেমন Brown spot বনাম Rice Tungro, Tungro বনাম Sheath blight)। dHash 6-এ মিশ্র, ≥8 হলে আলাদা ছবি। **dHash ≤6 পর্যন্ত সব cross-class জোড়া বাদ।** কারণ হতে পারে লেবেলিং ভুল, অথবা একই পাতায় একাধিক রোগ (single-label মডেল যা প্রকাশ করতে পারে না)। কৃষি বিশেষজ্ঞের সাথে আলোচনার বিষয়।
3. **YOLO class ID README-এর সাথে মেলে না (পুরো ডেটায় নিশ্চিত)।** ফাইলে Blast=0, Brown spot=1, Leaf smut=2, Rice Tungro=3, Sheath blight=4, কিন্তু README বলে 1, 0, 3, 4, 5। Detection করলে ফোল্ডারের নাম থেকে ID নিতে হবে। একটি Blast label ফাইল খালি।
4. **README-তে সংখ্যা স্ববিরোধী:** বক্স 21,460 বনাম 22,123। আসল ফাইলে 21,460 (Sheath blight 2,607, README-এর টেবিলে 2,605)।
5. **Shortcut ঝুঁকি: ফোন ও ছবির দিক (orientation)।** Sheath blight-এর 86% ছবি একটি ফোন-প্যাটার্নের (`yyyymmdd_hhmmss`), Brown spot-এর 72% অন্যটির (`IMG…`)। Sheath blight-এর 88% ছবি মূলত landscape, Brown spot-এর 64% portrait। 3:4 থেকে 1:1 করতে stretch করা হলে বিকৃতির দিক (চওড়া নাকি লম্বা) নিজেই ক্লাসের সংকেত হয়ে যেতে পারে। **Phase 5-এ:** random aspect-ratio ও 90° rotation augmentation, এবং ফোন-প্যাটার্ন অনুযায়ী আলাদা accuracy যাচাই। Brightness ও sharpness সব ক্লাসে প্রায় সমান, সেখানে ঝুঁকি দেখা যায়নি।
6. **Out-of-distribution:** শুধু Gazipur, এক মৌসুম, দুই জাত। Bacterial Leaf Blight, Hispa ইত্যাদি নেই, তাই মডেল এগুলো চিনবে না। আলাদা field test set দরকার।
7. **খোলা প্রশ্ন:** 1024×1024 করতে stretch নাকি crop ব্যবহার হয়েছে - এখনও অনিশ্চিত। লেখককে ইমেইল করে জানা যায় (README-তে ঠিকানা আছে)।

## ৩) চূড়ান্ত split (`make_splits.py`, seed 114)

বাদ: 227টি ছবি (180 cross-class near-identical, 31 একই ক্লাসে হুবহু কপি, 16 অন্য ক্লাসে হুবহু একই ফাইল)। তালিকা: `ml/data/splits/excluded.csv`

| ক্লাস | train | val | test | মোট |
|---|---:|---:|---:|---:|
| Blast | 897 | 191 | 192 | 1280 |
| Brown spot | 1420 | 328 | 375 | 2123 |
| Healthy | 1143 | 235 | 180 | 1558 |
| Leaf smut | 518 | 106 | 85 | 709 |
| Rice Tungro | 1620 | 278 | 303 | 2201 |
| Sheath blight | 1180 | 201 | 290 | 1671 |
| **মোট** | **6778 (71%)** | **1339 (14%)** | **1425 (15%)** | **9542** |

যাচাই: split-গুলোর মধ্যে shared group 0, হুবহু একই ফাইল 0, প্রায়-একই জোড়া (dHash ≤4) 0 → **PASS**।
100টি seed থেকে সবচেয়ে ভারসাম্যপূর্ণটি বাছাই হয়েছে, শুধু লেবেল দেখে (কোনো ক্লাসের অনুপাত target থেকে সর্বোচ্চ 3.6 পয়েন্ট দূরে)।

**মডেলের output ক্রম (`labels.json`), অ্যাপেও এই ক্রম ব্যবহার করতে হবে:**
`["Blast", "Brown spot", "Healthy", "Leaf smut", "Rice Tungro", "Sheath blight"]`

## ৪) সিদ্ধান্ত

- **Image classification উপযুক্ত: হ্যাঁ।** `Original images/` ব্যবহার করা হবে, উপরের split দিয়ে।
- **Test set একবারই চলবে, শেষে।** মডেল বাছাই শুধু validation দিয়ে।
- **আলাদা field test:** Gazipur-এর বাইরের নিজের তোলা ছবি (লক্ষ্য প্রতি ক্লাসে 30+), সাথে "ধানের পাতা নয়" এমন ছবি।
- **Unknown handling:** শুধু softmax threshold যথেষ্ট নয়। Phase 5-এ temperature scaling এবং "ধানের পাতা নয়" যাচাই পরীক্ষা করা হবে।
- **Phase 5-এ যাওয়ার সিদ্ধান্ত: GO।**
