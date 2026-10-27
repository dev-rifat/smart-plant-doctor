package com.example.plant_health;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    // Opens the phone's "default voice input" screen so a farmer whose
    // recognizer has no Bangla can switch to Google voice input.
    private static final String CHANNEL = "krishisathi/settings";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
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
    }
}
