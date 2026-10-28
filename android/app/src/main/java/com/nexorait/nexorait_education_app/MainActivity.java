package com.nexorait.master_app;

import android.media.AudioManager;
import android.media.ToneGenerator;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    /** Short beep after a free-card attendance scan (lib/core/voice/attendance_voice.dart). */
    private static final String BEEP_CHANNEL = "nexora/beep";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), BEEP_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (!"beep".equals(call.method)) {
                    result.notImplemented();
                    return;
                }
                try {
                    final ToneGenerator tone = new ToneGenerator(AudioManager.STREAM_MUSIC, 80);
                    tone.startTone(ToneGenerator.TONE_PROP_BEEP, 150);
                    // free it after the beep
                    new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(tone::release, 300);
                    result.success(null);
                } catch (Exception e) {
                    result.error("beep", e.getMessage(), null);
                }
            });
    }
}
