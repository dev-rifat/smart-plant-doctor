package com.example.plant_health;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    // Opens the phone's "default voice input" screen so a farmer whose
    // recognizer has no Bangla can switch to Google voice input.
    private static final String SETTINGS_CHANNEL = "krishisathi/settings";

    // Google's own speech dialog (RecognizerIntent). It uses the Google app's
    // online recognizer whatever the phone's default voice input is, so
    // Bangla works even where the default is the offline "Speech Services
    // by Google" without Bangla data (seen on a Redmi Note 12).
    private static final String VOICE_CHANNEL = "krishisathi/voice";
    private static final int REQUEST_SPEECH = 4711;
    private static final String GOOGLE_APP = "com.google.android.googlequicksearchbox";
    private MethodChannel.Result pendingSpeech;

    // The Google app's own recognition service, used directly (no dialog).
    // On the Redmi test phone it is installed but not the default, and the
    // default (Speech Services) does not understand Bangla.
    private static final ComponentName GOOGLE_RECOGNIZER = new ComponentName(
            "com.google.android.googlequicksearchbox",
            "com.google.android.voicesearch.serviceapi.GoogleRecognitionService");
    private SpeechRecognizer googleRecognizer;
    private MethodChannel.Result pendingService;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SETTINGS_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (!call.method.equals("openVoiceInputSettings")) {
                        result.notImplemented();
                        return;
                    }
                    try {
                        startActivity(new Intent(Settings.ACTION_VOICE_INPUT_SETTINGS));
                        result.success(true);
                    } catch (ActivityNotFoundException e) {
                        // Some skins hide it; the general input settings are the next best place.
                        try {
                            startActivity(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS));
                            result.success(true);
                        } catch (ActivityNotFoundException e2) {
                            result.success(false);
                        }
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), VOICE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "defaultRecognizer":
                            // Readable without a permission; null on some phones.
                            result.success(Settings.Secure.getString(
                                    getContentResolver(), "voice_recognition_service"));
                            break;
                        case "recognize":
                            if (pendingSpeech != null) {
                                result.error("busy", "Already listening", null);
                                return;
                            }
                            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                            String language = call.argument("language");
                            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, language);
                            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, language);
                            String prompt = call.argument("prompt");
                            if (prompt != null) intent.putExtra(RecognizerIntent.EXTRA_PROMPT, prompt);
                            intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
                            // Prefer the Google app: on the Redmi test phone the
                            // default handler was "Speech Services by Google",
                            // which recorded 5 s of Bangla and returned nothing.
                            Intent google = new Intent(intent).setPackage(GOOGLE_APP);
                            Intent target = google.resolveActivity(getPackageManager()) != null
                                    ? google : intent;
                            try {
                                pendingSpeech = result;
                                startActivityForResult(target, REQUEST_SPEECH);
                            } catch (ActivityNotFoundException e) {
                                pendingSpeech = null;
                                result.error("unavailable", "No speech dialog on this phone", null);
                            }
                            break;
                        case "listenGoogleService":
                            listenGoogleService(call.argument("language"), result);
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    /** Replies {"text": String|null, "error": Integer|null} (SpeechRecognizer error codes). */
    private void listenGoogleService(String language, MethodChannel.Result result) {
        if (pendingService != null) {
            result.error("busy", "Already listening", null);
            return;
        }
        try {
            googleRecognizer = SpeechRecognizer.createSpeechRecognizer(this, GOOGLE_RECOGNIZER);
        } catch (RuntimeException e) {
            result.error("unavailable", e.getMessage(), null);
            return;
        }
        pendingService = result;
        googleRecognizer.setRecognitionListener(new RecognitionListener() {
            @Override public void onResults(Bundle results) {
                ArrayList<String> m = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                finishService(m != null && !m.isEmpty() ? m.get(0) : null, null);
            }
            @Override public void onError(int error) { finishService(null, error); }
            @Override public void onReadyForSpeech(Bundle params) {}
            @Override public void onBeginningOfSpeech() {}
            @Override public void onRmsChanged(float rmsdB) {}
            @Override public void onBufferReceived(byte[] buffer) {}
            @Override public void onEndOfSpeech() {}
            @Override public void onPartialResults(Bundle partialResults) {}
            @Override public void onEvent(int eventType, Bundle params) {}
        });
        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, language);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, language);
        intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        googleRecognizer.startListening(intent);
    }

    private void finishService(String text, Integer error) {
        MethodChannel.Result result = pendingService;
        pendingService = null;
        if (googleRecognizer != null) {
            googleRecognizer.destroy();
            googleRecognizer = null;
        }
        if (result == null) return;
        Map<String, Object> reply = new HashMap<>();
        reply.put("text", text);
        reply.put("error", error);
        result.success(reply);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_SPEECH || pendingSpeech == null) return;
        MethodChannel.Result result = pendingSpeech;
        pendingSpeech = null;
        String text = null;
        if (resultCode == Activity.RESULT_OK && data != null) {
            ArrayList<String> matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
            if (matches != null && !matches.isEmpty()) text = matches.get(0);
        }
        // null = nothing heard or the farmer closed the dialog.
        result.success(text);
    }
}
