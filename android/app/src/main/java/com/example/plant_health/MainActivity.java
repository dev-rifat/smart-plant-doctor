package com.example.plant_health;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.provider.Settings;
import android.speech.RecognizerIntent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;

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
    private MethodChannel.Result pendingSpeech;

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
                            try {
                                pendingSpeech = result;
                                startActivityForResult(intent, REQUEST_SPEECH);
                            } catch (ActivityNotFoundException e) {
                                pendingSpeech = null;
                                result.error("unavailable", "No speech dialog on this phone", null);
                            }
                            break;
                        default:
                            result.notImplemented();
                    }
                });
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
