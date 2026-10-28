package com.example.plant_health;

import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Intent;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "krishisathi/settings";

    // "Speech Services by Google" language download screen. On phones whose
    // default recognizer is that offline service without Bangla (Redmi
    // Note 12 field test), downloading Bangla here is what makes speech
    // recognition work; the Google app's recognizer can't be used by apps.
    private static final ComponentName SPEECH_LANGUAGES = new ComponentName(
            "com.google.android.tts",
            "com.google.android.libraries.speech.modelmanager.languagepack.legacy.DownloadActivity");

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (!call.method.equals("openVoiceInputSettings")) {
                        result.notImplemented();
                        return;
                    }
                    result.success(open(new Intent().setComponent(SPEECH_LANGUAGES))
                            || open(new Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))
                            // Some skins hide it; the general input settings are the next best place.
                            || open(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)));
                });
    }

    private boolean open(Intent intent) {
        try {
            startActivity(intent);
            return true;
        } catch (ActivityNotFoundException | SecurityException e) {
            return false;
        }
    }
}
