# KrishiSathi AI (কৃষিসাথী AI) - Implementation Plan

Last updated: 2026-10-27. Status markers: ✅ done and verified · 🟡 exists but needs rework · ⬜ not started.

## 1. Current state (inspected, not assumed)

**Environment:** Flutter 3.41.4 (stable), Dart 3.11.1, Apple M4 Mac. Firebase project `smartkhrishi` (Android, iOS, web configured via FlutterFire).
`flutter analyze`: 0 errors, 0 warnings, 40 infos. `flutter test`: 27 pass, 1 fails (`test/widget_test.dart` is the stale Flutter counter template).

| Area | State | Notes |
|---|---|---|
| Architecture | 🟡 | Feature folders with data/domain/presentation, `get_it` DI, BLoC/Cubit. Navigation uses `onGenerateRoute`, not GoRouter. `home_nav_page.dart` is 1,099 lines. |
| Voice input (STT) | 🟡 | `VoiceInputService` wraps `speech_to_text` with forced `bn-BD`. Used only in the product assistant. |
| Voice output (TTS) | ⬜ | No TTS package. |
| Auth | 🟡 | Email/password only. No anonymous or phone OTP auth, no account linking. |
| Rice disease detection | 🔴 | Sends the photo to Gemini and **asks Gemini to name medicines and dosages**. Violates the safety rules; must be replaced by the TFLite model + verified advice. |
| Gemini access | 🔴 | API keys reach the phone (Remote Config / dart-define). Keys previously committed to the public GitHub repo. Needs a server-side proxy. |
| Rice model | 🟡 | Phase 1 dataset work done (`ml/`, see `ml/docs/PHASE1_FINDINGS.md`). Training running locally; Colab notebook ready. |
| Weather | 🟡 | Open-Meteo, hard-coded to Dhaka, no district selection, no source/time display. |
| Marketplace | 🟡 | Product catalog (local data), cart, COD checkout writing to Firestore `orders`, AI product chat, tests. |
| Firestore rules | 🟡 | Only `orders`. No rules for profiles, reports, chats. |
| Cloud Functions | ⬜ | No `functions/` folder. |
| Blog, FCM, history | ⬜ | Not present. |

## 2. Priorities and why

1. **Safety first:** remove the Gemini-invented diagnosis and dosages (§1). It ships wrong medical advice today.
2. **Reliable rice disease detection** with the on-device TFLite model: works offline, and the confidence is calibrated instead of invented.
3. **Bangla voice loop:** speak → recognised text shown and editable → answer read aloud. STT exists; TTS is missing.
4. **Secure Gemini backend** before any new AI conversation features.
5. Everything else (auth upgrade, weather, blog, FCM) after the first milestone.

## 3. Phases

### Phase A - Foundation clean-up
- ⬜ Fix/replace the stale counter test.
- ⬜ Bangla TTS service (`flutter_tts`) with a language availability check and a stop control.
- ⬜ Migrate to GoRouter; split `home_nav_page.dart` into widgets.
- ⬜ Bangla-first home screen: big mic button and a "রোগ পরীক্ষা" entry first.
- **Accept:** `flutter analyze` has no warnings; all tests pass; the app launches on Android.

### Phase B - Voice interaction (milestone 1 core)
- ⬜ Shared voice cubit: idle / listening / processing / speaking / error states.
- ⬜ Recognised text shown in an editable field, with manual text fallback.
- ⬜ Permission denied, no Bangla recogniser, no Bangla TTS voice, and offline states, each with a Bangla message.
- ⬜ Intent routing for supported commands ("রোগ পরীক্ষা করো", "আগের রিপোর্ট দেখাও", weather).
- **Accept:** on a real Android phone, Bangla speech → text shown → spoken Bangla reply, and it can be interrupted.

### Phase C - Rice disease model (ML side: `ml/`)
- ✅ Dataset inspection, cleaning, group-wise split (`ml/docs/PHASE1_FINDINGS.md`).
- 🟡 Train MobileNetV3-Large vs EfficientNetB0 (`ml/notebooks/train_rice_classifier.py`); found and fixed a Keras 3 BatchNorm fine-tuning bug.
- ⬜ Choose the model on validation; run the test set once; write the model card.
- ⬜ Collect real field photos outside Gazipur plus "not a rice leaf" photos for an out-of-distribution test.
- **Accept:** per-class P/R/F1 + confusion matrix on test; TFLite output matches Keras; limitations documented.

### Phase D - Disease detection in the app (milestone 1 core)
- ⬜ `tflite_flutter` (or LiteRT) inference service: whole-photo resize to 224×224, float 0-255, output order from `labels.json`.
- ⬜ Image quality gate (too dark, blurry, small) before inference.
- ⬜ Uncertainty handling: below the calibrated threshold → "ছবিটি পরিষ্কার নয় / নিশ্চিত নই", ask for another photo, suggest an agriculture officer.
- ⬜ Bangla result screen: সম্ভাব্য রোগ, নির্ভরযোগ্যতা, কীভাবে যাচাই করবেন, এখন কী করবেন, কখন কৃষি কর্মকর্তা. Read aloud.
- ⬜ Verified advice content (`assets/advice/rice_diseases_bn.json`) with source + review date per entry; **no pesticide names or doses until an expert has reviewed them**.
- ⬜ Remove the Gemini image-diagnosis path.
- **Accept:** a real model prediction on device; no fabricated confidence; widget tests for the certain and uncertain flows.

### Phase E - Firebase accounts and history
- ⬜ Anonymous sign-in on first launch; phone OTP linking (`linkWithCredential`); keep email login for existing users.
- ⬜ Profile: name, district, upazila, primary crop (voice-assisted).
- ⬜ `disease_reports` (per user, image upload opt-in only) and history screen.
- ⬜ Firestore + Storage rules with ownership checks; rules unit tests with the emulator.
- **Accept:** a user can read/write only their own data (emulator tests).

### Phase F - Secure AI assistant
- ⬜ Cloud Function (callable, App Check + auth required) proxying Gemini; key held in Secret Manager.
- ⬜ Remove all client-side Gemini keys; **user must revoke the leaked keys**.
- ⬜ System prompt and guardrails: no dosages or product claims, follow-up questions, escalation to an officer; ground in the verified advice content.
- **Accept:** no API key in the APK (checked with `strings`); the assistant refuses dose questions and redirects safely.

### Phase G - Weather, marketplace, blog, notifications
- ⬜ Weather by district (manual or location), showing source and update time, stale-data warning.
- ⬜ Marketplace: keep it, mark checkout clearly as demo/COD, add voice search.
- ⬜ Blog: admin-managed Firestore articles, read-aloud, saved articles.
- ⬜ FCM weather alerts (only from real forecast data).

### Phase H - Testing and release
- ⬜ Unit, widget, integration tests for the voice and diagnosis flows; poor-network tests; accessibility review; release checklist.

## 4. Firestore schema (draft, finalised in Phase E)

| Collection | Key fields | Access |
|---|---|---|
| `users/{uid}` | name, district, upazila, primaryCrop, language, createdAt | owner only |
| `users/{uid}/disease_reports/{id}` | label, probabilities, modelVersion, uncertain, imagePath?, createdAt | owner only |
| `users/{uid}/chat_sessions/{id}/messages/{id}` | role, text, createdAt | owner only |
| `orders/{id}` | existing rules | owner read/create/cancel |
| `products`, `articles` | public catalog/content | read all, write admin only |
| `users/{uid}/settings/notifications` | weatherAlerts, district | owner only |

Profiles and preferences live under `users/{uid}` instead of separate top-level collections, so one ownership rule covers them.

## 5. Risks and open questions

- **Leaked Gemini keys** in the public repo history: the user must revoke them in Google AI Studio.
- **GitHub push blocked:** the local credential is `lutfurDev`, without access to `dev-rifat/plant-health-checker`.
- **Bangla TTS availability** depends on the phone's TTS engine (Google Speech Services with Bengali voice data). Needs a real-device check; a cloud TTS is the fallback.
- **STT accuracy** for regional accents is unknown: the editable transcript and text fallback are mandatory.
- **Model scope:** 6 classes, one district, one season. It will misclassify diseases it doesn't know; the uncertainty threshold and the OOD test set mitigate this but don't solve it.
- **Label conflicts** in the dataset (same leaf, two diseases) need an agronomist's opinion.
- **Treatment advice** needs review by an agriculture expert before showing any chemical recommendation.
