package com.dr.clicker.atikapp

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.meclicker/settings"
    private val OVERLAY_REQ = 1001
    private val BATTERY_REQ = 1002

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityEnabled())
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "isOverlayPermissionGranted" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= 23)
                                Settings.canDrawOverlays(this)
                            else true
                        )
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, OVERLAY_REQ)
                        }
                        result.success(null)
                    }

                    "isBatteryOptimizationIgnored" -> {
                        if (Build.VERSION.SDK_INT >= 23) {
                            val pm = getSystemService(android.os.PowerManager::class.java)
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } else {
                            result.success(true)
                        }
                    }

                    "requestIgnoreBatteryOptimization" -> {
                        if (Build.VERSION.SDK_INT >= 23) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, BATTERY_REQ)
                        }
                        result.success(null)
                    }

                    "startFloatingPanel" -> {
                        if (Settings.canDrawOverlays(this)) {
                            val intent = Intent(this, FloatingPanelService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }

                    "stopFloatingPanel" -> {
                        stopService(Intent(this, FloatingPanelService::class.java))
                        result.success(null)
                    }

                    "isFloatingPanelRunning" -> {
                        result.success(FloatingPanelService.isRunning)
                    }

                    "getStats" -> {
                        val prefs = getSharedPreferences("MeClickerPrefs", MODE_PRIVATE)
                        result.success(mapOf(
                            "acceptCount"   to prefs.getInt("accept_count", 0),
                            "lastLatencyMs" to prefs.getLong("last_latency_ms", 0L)
                        ))
                    }

                    "resetStats" -> {
                        getSharedPreferences("MeClickerPrefs", MODE_PRIVATE)
                            .edit()
                            .putInt("accept_count", 0)
                            .putLong("last_latency_ms", 0L)
                            .apply()
                        result.success(null)
                    }

                    "isEngineRunning" -> {
                        result.success(MyAccessibilityService.isEngineOn)
                    }

                    // ── NEW: Get ride history as JSON string ──
                    "getHistory" -> {
                        val prefs = getSharedPreferences("MeClickerPrefs", MODE_PRIVATE)
                        val history = prefs.getString("ride_history", null)
                        result.success(history ?: "[]")
                    }

                    // ── NEW: Clear all ride history ──
                    "clearHistory" -> {
                        getSharedPreferences("MeClickerPrefs", MODE_PRIVATE)
                            .edit()
                            .remove("ride_history")
                            .apply()
                        // Also clear in-memory history
                        val service = MyAccessibilityService()
                        try { service.clearHistory() } catch (_: Exception) {}
                        result.success(null)
                    }

                    // ── NEW: Test voice announcement ──
                    "testVoice" -> {
                        val lang = call.argument<String>("lang") ?: "en"
                        // We can't call the service directly from here safely,
                        // so we use TTS directly for test
                        val tts = android.speech.tts.TextToSpeech(this,
                            android.speech.tts.TextToSpeech.OnInitListener { status ->
                                if (status == android.speech.tts.TextToSpeech.SUCCESS) {
                                    val locale = when (lang) {
                                        "ta" -> Locale("ta", "IN")
                                        "te" -> Locale("te", "IN")
                                        "kn" -> Locale("kn", "IN")
                                        "hi" -> Locale("hi", "IN")
                                        else -> Locale.ENGLISH
                                    }
                                    tts?.setLanguage(locale)
                                    tts?.setSpeechRate(1.1f)
                                    val message = when (lang) {
                                        "ta" -> "Vanakkam! Dr.Clicker voice test. Ride accept aayiduchu. Price 150 rupees."
                                        "hi" -> "Namaste! Dr.Clicker voice test. Ride accept ho gayi. Price 150 rupaye."
                                        "te" -> "Namaskaram! Dr.Clicker voice test. Ride accept ayindi. Price 150 rupayalu."
                                        "kn" -> "Namaskara! Dr.Clicker voice test. Ride accept aaytu. Price 150 rupayigalu."
                                        else -> "Hello! Dr.Clicker voice test. Ride accepted. Price 150 rupees."
                                    }
                                    tts?.speak(message, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, "test")
                                    // Shutdown after speaking
                                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                        tts?.stop()
                                        tts?.shutdown()
                                    }, 5000L)
                                }
                            })
                        result.success(null)
                    }

                    "getLogPath" -> {
                        val logFile = File(getExternalFilesDir(null), "god_mode_logs.txt")
                        if (!logFile.exists()) {
                            logFile.parentFile?.mkdirs()
                            val header = "--- DRCLICKER: ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())} ---\n" +
                                    "System Ready. Waiting for rides...\n\n"
                            try {
                                FileOutputStream(logFile).use {
                                    it.write(header.toByteArray(StandardCharsets.UTF_8))
                                }
                            } catch (_: Exception) {}
                        }
                        result.success(logFile.absolutePath)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val target = "$packageName/${MyAccessibilityService::class.java.canonicalName}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(":").any { it.equals(target, ignoreCase = true) }
    }
}
