# ML Workspace - KrishiSathi AI (Rice Disease Focus)

এই ফোল্ডারটি Flutter অ্যাপ থেকে আলাদা রাখা হয়েছে।

## উদ্দেশ্য
RiceLeafDiseaseBD ডেটাসেট ব্যবহার করে ধানের পাতা রোগ শনাক্তকরণ মডেল তৈরি করা।

## ওয়ার্কফ্লো
1. Download (Phase 1) - `scripts/download_dataset.py` (শুধু Original images + labels + metadata)
2. Inspect (Phase 1) - `scripts/inspect_dataset.py` → `reports/`
3. Clean & Split (Phase 1/5) - ক্লিনিং, **group-wise** stratified train/val/test (burst leakage এড়াতে)
4. Train (Phase 5) - Transfer Learning (MobileNetV3 vs EfficientNet-Lite), Google Colab এ
5. Evaluate (Phase 5) - Accuracy, Precision, Recall, F1, Confusion Matrix
6. Convert (Phase 5) - Keras -> TensorFlow Lite (.tflite)
7. Integrate (Phase 6) - Flutter এ tflite_flutter দিয়ে ইমপ্লিমেন্ট

## নিরাপত্তা নীতি
- কখনো 100% নির্ভুল দাবি করা যাবে না
- অনিশ্চিত/অস্পষ্ট/অজানা ছবি সনাক্ত করে সতর্কবার্তা দেখাতে হবে
- শুধু মডেলের জানা ক্লাসেই প্রেডিকশন দেখাতে হবে
- আনসার্টেইন কেসে "নিকটস্থ কৃষি কর্মকর্তা" এর পরামর্শ দিতে হবে
- ডোজ/অননুমোদিত কীটনাশক সাজেশন এড়িয়ে চলতে হবে

## Citation (CC BY 4.0)
Munna, M. M. H. et al. (2026), "RiceLeafDiseaseBD: A Field-Based Annotated Smartphone Image Dataset of Healthy and Diseased Rice Leaves from Bangladesh", Mendeley Data, V3, doi: 10.17632/86s4jzj2m4.3
