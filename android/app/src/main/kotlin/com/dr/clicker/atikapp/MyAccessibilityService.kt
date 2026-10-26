package com.dr.clicker.atikapp

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Path
import android.graphics.Rect
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.LinkedHashSet
import java.util.Locale
import java.util.regex.Pattern
import kotlin.random.Random

/**
 * Dr.Clicker Accessibility Engine v2.0
 * Features: Custom click speed, voice announcement, ride history
 */
class MyAccessibilityService : AccessibilityService(), TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "DrClicker"
        private const val CHANNEL_ID = "drclicker_service"
        private const val NOTIF_ID = 1
        private const val THROTTLE_MS = 50L
        private const val WAKELOCK_MS = 600000L
        private const val MAX_HISTORY = 200

        val ACCEPT_KEYWORDS = listOf(
            "accept", "confirm", "match", "take ride", "start ride",
            "ஏற்க",
            "స్వీకరించు",
            "ಸ್ವೀಕರಿಸಿ",
            "स्वीकार करें",
            "स्वीकार",
            "स्वीकार करा",
            "গ্রহণ করুন"
        )

        private val NUMBER_RE = Pattern.compile("^[0-9]+\\.?[0-9]*$")
        private val STRIP_NON_NUM = Pattern.compile("[^0-9.]")

        @Volatile
        var isEngineOn = false
            private set

        // History stored in memory + synced to prefs
        val rideHistory = JSONArray()
    }

    private lateinit var flutterPrefs: SharedPreferences
    private lateinit var meClickerPrefs: SharedPreferences

    private var logFile: File? = null
    private var isForegroundRunning = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastEventMs = 0L

    private val seenNodes = LinkedHashSet<String>()
    private val handler = Handler(Looper.getMainLooper())

    // TextToSpeech
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    // ────────────────────────────────────────────────────────────────
    // LIFECYCLE
    // ────────────────────────────────────────────────────────────────

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 0L
        }
        setServiceInfo(info)

        flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        meClickerPrefs = getSharedPreferences("MeClickerPrefs", MODE_PRIVATE)
        logFile = File(getExternalFilesDir(null), "god_mode_logs.txt")

        // Initialize TTS
        tts = TextToSpeech(this, this)

        // Load saved history
        loadHistory()

        acquireWakeLock()
        log("🚀 Dr.Clicker v2.0 ONLINE | Click Speed + Voice + History")
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            val lang = getVoiceLang()
            val locale = when (lang) {
                "ta" -> Locale("ta", "IN")
                "te" -> Locale("te", "IN")
                "kn" -> Locale("kn", "IN")
                "hi" -> Locale("hi", "IN")
                else -> Locale.ENGLISH
            }
            val result = tts?.setLanguage(locale)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.ENGLISH)
            }
            tts?.setSpeechRate(1.1f)
            log("🔊 TTS initialized with locale: $locale")
        }
    }

    private fun getVoiceLang(): String {
        return flutterPrefs.getString("voice_lang", "en") ?: "en"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        log("🚀 Service onStartCommand called")
        if (getBoolPref("master_switch") || getBoolPref("flutter.masterSwitch")) {
            if (!isForegroundRunning) {
                startForegroundService()
                isForegroundRunning = true
            }
            acquireWakeLock()
        }
        return START_STICKY
    }

    override fun onInterrupt() {
        isEngineOn = false
    }

    override fun onDestroy() {
        isEngineOn = false
        releaseWakeLock()
        tts?.stop()
        tts?.shutdown()
        val masterOn = getBoolPref("master_switch") || getBoolPref("flutter.masterSwitch")
        if (masterOn) {
            log("🔄 Service destroyed, trying to restart...")
            val restartIntent = Intent(this, MyAccessibilityService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= 26) {
                    startForegroundService(restartIntent)
                } else {
                    startService(restartIntent)
                }
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }

    // ────────────────────────────────────────────────────────────────
    // PREFS
    // ────────────────────────────────────────────────────────────────

    private fun getBoolPref(key: String): Boolean {
        val flutterKey = key.replace("flutter.", "")
        if (flutterPrefs.contains(flutterKey)) {
            return flutterPrefs.getBoolean(flutterKey, false)
        }
        if (meClickerPrefs.contains(key)) {
            return meClickerPrefs.getBoolean(key, false)
        }
        return false
    }

    private fun getIntPref(key: String): Int {
        val flutterKey = key.replace("flutter.", "")
        if (flutterPrefs.contains(flutterKey)) {
            return flutterPrefs.getInt(flutterKey, 0)
        }
        if (meClickerPrefs.contains(key)) {
            return try {
                meClickerPrefs.getInt(key, 0)
            } catch (_: Exception) {
                meClickerPrefs.getLong(key, 0L).toInt()
            }
        }
        return 0
    }

    private fun getFloatPref(key: String): Float {
        val flutterKey = key.replace("flutter.", "")
        if (flutterPrefs.contains(flutterKey)) {
            return flutterPrefs.getFloat(flutterKey, 0f)
        }
        return 0f
    }

    /** Read click speed from Flutter prefs — defaults to 50ms */
    private fun getClickSpeed(): Long {
        val speed = flutterPrefs.getFloat("click_speed_ms", 50f)
        return speed.toLong().coerceIn(10L, 500L)
    }

    /** Check if voice announcement is enabled */
    private fun isVoiceOn(): Boolean {
        return flutterPrefs.getBoolean("voice_on", true)
    }

    /** Check if price filter is enabled */
    private fun isPriceFilterOn(): Boolean {
        return flutterPrefs.getBoolean("price_filter_on", false)
    }

    /** Check if distance filter is enabled */
    private fun isDistFilterOn(): Boolean {
        return flutterPrefs.getBoolean("dist_filter_on", false)
    }

    // ────────────────────────────────────────────────────────────────
    // HISTORY
    // ────────────────────────────────────────────────────────────────

    private fun loadHistory() {
        try {
            val saved = meClickerPrefs.getString("ride_history", null)
            if (saved != null && saved.isNotEmpty()) {
                val arr = JSONArray(saved)
                rideHistory.put(arr)
                // rideHistory is a JSONArray, we need to merge
                // Actually let's just replace
                synchronized(rideHistory) {
                    // Clear and repopulate
                    while (rideHistory.length() > 0) rideHistory.remove(0)
                    for (i in 0 until arr.length()) {
                        rideHistory.put(arr.get(i))
                    }
                }
            }
        } catch (e: Exception) {
            log("⚠️ Failed to load history: ${e.message}")
        }
    }

    private fun saveHistory() {
        try {
            meClickerPrefs.edit()
                .putString("ride_history", rideHistory.toString())
                .apply()
        } catch (e: Exception) {
            log("⚠️ Failed to save history: ${e.message}")
        }
    }

    private fun addRideToHistory(app: String, price: Double, pickup: Double, drop: Double,
                                  latencyMs: Long, tapX: Int, tapY: Int) {
        val entry = JSONObject().apply {
            put("app", app)
            put("price", if (price > 0) price.toInt().toString() else "?")
            put("pickup", if (pickup > 0) String.format("%.1f", pickup) else "?")
            put("drop", if (drop > 0) String.format("%.1f", drop) else "?")
            put("latency", latencyMs)
            put("tapX", tapX)
            put("tapY", tapY)
            put("time", SimpleDateFormat("dd MMM yyyy, HH:mm:ss", Locale.getDefault()).format(Date()))
            put("timestamp", System.currentTimeMillis())
        }

        synchronized(rideHistory) {
            rideHistory.put(entry)
            // Keep only last MAX_HISTORY entries
            while (rideHistory.length() > MAX_HISTORY) {
                rideHistory.remove(0)
            }
        }
        saveHistory()
    }

    fun clearHistory() {
        synchronized(rideHistory) {
            while (rideHistory.length() > 0) rideHistory.remove(0)
        }
        saveHistory()
    }

    fun getHistoryJson(): String {
        return rideHistory.toString()
    }

    // ────────────────────────────────────────────────────────────────
    // EVENT LOOP
    // ────────────────────────────────────────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val masterOn = getBoolPref("master_switch") || getBoolPref("flutter.masterSwitch")
        isEngineOn = masterOn

        if (masterOn && !isForegroundRunning) {
            startForegroundService()
            isForegroundRunning = true
        } else if (!masterOn && isForegroundRunning) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            isForegroundRunning = false
            return
        }
        if (!masterOn) return

        val now = System.currentTimeMillis()
        if (now - lastEventMs < THROTTLE_MS) return
        lastEventMs = now

        val allWindows = try { windows } catch (_: Exception) { null } ?: return

        for (win in allWindows) {
            val root = win.root ?: continue
            val type = win.type

            if (type == AccessibilityWindowInfo.TYPE_INPUT_METHOD) {
                recycleNode(root)
                continue
            }

            val pkg = try {
                root.packageName?.toString()?.lowercase(Locale.ROOT) ?: ""
            } catch (_: Exception) { "" }

            val isRapido = pkg.contains("rapido") || pkg.contains("captain")
            val isOla = pkg.contains("ola") && pkg.contains("driver")
            val isUber = pkg.contains("uber") && pkg.contains("driver")
            val isNamma = pkg.contains("namma") || pkg.contains("yatri")
            val isPopup = type == AccessibilityWindowInfo.TYPE_SYSTEM

            val tag = when {
                isOla -> "Ola"
                isUber -> "Uber"
                isNamma -> "Namma"
                isRapido -> "Rapido"
                isPopup -> "Popup"
                else -> pkg.take(20)
            }
            scanAndClick(root, now, tag)
            recycleNode(root)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // SCANNER — Respects filter ON/OFF toggles
    // ────────────────────────────────────────────────────────────────

    private fun scanAndClick(root: AccessibilityNodeInfo, ts: Long, tag: String) {
        // Read filter toggles
        val priceFilterOn = isPriceFilterOn()
        val distFilterOn  = isDistFilterOn()

        // Read filter values (only used when respective toggle is ON)
        val minPrice  = if (priceFilterOn) getIntPref("min_price") else 0
        val maxPrice  = if (priceFilterOn) getIntPref("max_price").let { if (it == 0) 99999 else it } else 99999
        val minPickup = if (distFilterOn) getFloatPref("min_pickup") else 0f
        val maxDrop   = if (distFilterOn) getFloatPref("max_drop").let { if (it == 0f) 999f else it } else 999f

        // Collect visible numbers
        val numbers = mutableListOf<Double>()
        collectText(root) { txt ->
            val n = toNumber(txt)
            if (n > 0) numbers.add(n)
        }

        var price  = numbers.find { it in 10.0..9999.0 } ?: -1.0
        var pickup = numbers.find { it in 0.1..50.0 } ?: -1.0
        var drop   = numbers.find { it in 0.1..200.0 && it != price } ?: -1.0

        // FILTER CHECKS — only when filter is ON
        if (priceFilterOn) {
            if (minPrice > 0 && price > 0 && price < minPrice) {
                log("[$tag] ✗ Price ₹${price.toInt()} < min ₹$minPrice")
                return
            }
            if (maxPrice > 0 && price > 0 && price > maxPrice) {
                log("[$tag] ✗ Price ₹${price.toInt()} > max ₹$maxPrice")
                return
            }
        }
        if (distFilterOn) {
            if (minPickup > 0 && pickup > 0 && pickup < minPickup) {
                log("[$tag] ✗ Pickup ${pickup}km < min ${minPickup}km")
                return
            }
            if (maxDrop > 0 && drop > 0 && drop > maxDrop) {
                log("[$tag] ✗ Drop ${drop}km > max ${maxDrop}km")
                return
            }
        }

        clickAccept(root, ts, tag, price, pickup, drop)
    }

    // ────────────────────────────────────────────────────────────────
    // CLICKER — Uses custom click speed
    // ────────────────────────────────────────────────────────────────

    private fun clickAccept(
        node: AccessibilityNodeInfo, ts: Long, tag: String,
        price: Double, pickup: Double, drop: Double
    ) {
        val text = try { node.text?.toString()?.trim() ?: "" } catch (_: Exception) { "" }
        val desc = try { node.contentDescription?.toString()?.trim() ?: "" } catch (_: Exception) { "" }
        val combined = "$text $desc".lowercase(Locale.ROOT)

        if (ACCEPT_KEYWORDS.any { keyword ->
            combined.contains(keyword.lowercase(Locale.ROOT))
        }) {
            val key = "${node.hashCode()}_$ts"
            if (key in seenNodes) return
            seenNodes.add(key)
            if (seenNodes.size > 300) {
                val iter = seenNodes.iterator()
                repeat(50) { if (iter.hasNext()) { iter.next(); iter.remove() } }
            }

            val bounds = Rect()
            node.getBoundsInScreen(bounds)

            // Use custom click speed from settings
            val baseDelay = getClickSpeed()
            val jitter = Random.nextLong(0L, (baseDelay * 0.2).toLong().coerceAtLeast(5L))
            val delay = baseDelay + jitter

            val priceStr = if (price > 0) "₹${price.toInt()}" else "₹?"
            val pickupStr = if (pickup > 0) "${pickup}km pickup" else ""
            val dropStr = if (drop > 0) "${drop}km drop" else ""

            val startMs = System.currentTimeMillis()

            if (bounds.width() > 0 && bounds.height() > 0) {
                val cx = bounds.centerX().toFloat()
                val cy = bounds.centerY().toFloat()
                handler.postDelayed({
                    tap(cx, cy)
                    val latency = System.currentTimeMillis() - startMs
                    onAccepted(tag, price, pickup, drop, latency, cx.toInt(), cy.toInt())
                }, delay)
            } else {
                handler.postDelayed({
                    node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    val latency = System.currentTimeMillis() - startMs
                    onAccepted(tag, price, pickup, drop, latency, 0, 0)
                }, delay)
            }
            return
        }

        val childCount = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until childCount) {
            val child = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            clickAccept(child, ts, tag, price, pickup, drop)
            recycleNode(child)
        }
    }

    private fun onAccepted(tag: String, price: Double, pickup: Double, drop: Double,
                            latencyMs: Long, tapX: Int, tapY: Int) {
        val count = meClickerPrefs.getInt("accept_count", 0) + 1
        meClickerPrefs.edit()
            .putInt("accept_count", count)
            .putLong("last_latency_ms", latencyMs)
            .apply()

        val priceStr = if (price > 0) "₹${price.toInt()}" else "₹?"
        val pickupStr = if (pickup > 0) "${pickup}km pickup" else ""
        val dropStr = if (drop > 0) "${drop}km drop" else ""

        log("[$tag] ✅ ACCEPTED $priceStr $pickupStr $dropStr latency=${latencyMs}ms total=$count")

        // Add to history
        addRideToHistory(tag, price, pickup, drop, latencyMs, tapX, tapY)

        // Beep
        beep()

        // Voice announcement
        if (isVoiceOn()) {
            announceRide(tag, price, pickup, drop)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // VOICE ANNOUNCEMENT
    // ────────────────────────────────────────────────────────────────

    private fun announceRide(tag: String, price: Double, pickup: Double, drop: Double) {
        if (!ttsReady) return

        val lang = getVoiceLang()
        val message = when (lang) {
            "ta" -> {
                val parts = mutableListOf<String>()
                parts.add("$tag ride accept aayiduchu")
                if (price > 0) parts.add("Price ${price.toInt()} rupees")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometre")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometre")
                parts.joinToString(", ")
            }
            "hi" -> {
                val parts = mutableListOf<String>()
                parts.add("$tag ride accept ho gayi")
                if (price > 0) parts.add("Price ${price.toInt()} rupaye")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometre")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometre")
                parts.joinToString(", ")
            }
            "te" -> {
                val parts = mutableListOf<String>()
                parts.add("$tag ride accept ayindi")
                if (price > 0) parts.add("Price ${price.toInt()} rupayalu")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometres")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometres")
                parts.joinToString(", ")
            }
            "kn" -> {
                val parts = mutableListOf<String>()
                parts.add("$tag ride accept aaytu")
                if (price > 0) parts.add("Price ${price.toInt()} rupayigalu")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometres")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometres")
                parts.joinToString(", ")
            }
            else -> { // English
                val parts = mutableListOf<String>()
                parts.add("$tag ride accepted")
                if (price > 0) parts.add("Price ${price.toInt()} rupees")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometres")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometres")
                parts.joinToString(", ")
            }
        }

        handler.postDelayed({
            try {
                // Switch language if needed
                val locale = when (lang) {
                    "ta" -> Locale("ta", "IN")
                    "te" -> Locale("te", "IN")
                    "kn" -> Locale("kn", "IN")
                    "hi" -> Locale("hi", "IN")
                    else -> Locale.ENGLISH
                }
                tts?.setLanguage(locale)
                tts?.speak(message, TextToSpeech.QUEUE_ADD, null, "ride_${System.currentTimeMillis()}")
                log("🔊 Voice: $message")
            } catch (e: Exception) {
                log("⚠️ TTS error: ${e.message}")
            }
        }, 200L) // small delay after beep
    }

    /** Called from MainActivity to test voice */
    fun testVoice(lang: String) {
        if (!ttsReady) {
            log("⚠️ TTS not ready")
            return
        }
        val message = when (lang) {
            "ta" -> "Vanakkam! Dr.Clicker voice test. Ride accept aayiduchu. Price 150 rupees. Pickup 2 kilometre. Drop 5 kilometre."
            "hi" -> "Namaste! Dr.Clicker voice test. Ride accept ho gayi. Price 150 rupaye. Pickup 2 kilometre. Drop 5 kilometre."
            "te" -> "Namaskaram! Dr.Clicker voice test. Ride accept ayindi. Price 150 rupayalu. Pickup 2 kilometres. Drop 5 kilometres."
            "kn" -> "Namaskara! Dr.Clicker voice test. Ride accept aaytu. Price 150 rupayigalu. Pickup 2 kilometres. Drop 5 kilometres."
            else -> "Hello! Dr.Clicker voice test. Ride accepted. Price 150 rupees. Pickup 2 kilometres. Drop 5 kilometres."
        }
        try {
            val locale = when (lang) {
                "ta" -> Locale("ta", "IN")
                "te" -> Locale("te", "IN")
                "kn" -> Locale("kn", "IN")
                "hi" -> Locale("hi", "IN")
                else -> Locale.ENGLISH
            }
            tts?.setLanguage(locale)
            tts?.speak(message, TextToSpeech.QUEUE_FLUSH, null, "test_voice")
        } catch (e: Exception) {
            log("⚠️ Test voice error: ${e.message}")
        }
    }

    // ────────────────────────────────────────────────────────────────
    // GESTURE TAP
    // ────────────────────────────────────────────────────────────────

    private fun tap(x: Float, y: Float) {
        val duration = ViewConfiguration.getTapTimeout().toLong().coerceAtLeast(40L)
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y + 1f)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0L, duration)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCancelled(gesture: GestureDescription) {
                Log.w(TAG, "Gesture cancelled at ($x,$y)")
            }
        }, handler)
    }

    // ────────────────────────────────────────────────────────────────
    // FOREGROUND NOTIFICATION
    // ────────────────────────────────────────────────────────────────

    private fun startForegroundService() {
        val mgr = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && mgr.getNotificationChannel(CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Dr.Clicker Engine", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) }
            )
        }

        val pi = android.app.PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("⚡ Dr.Clicker v2.0")
            .setContentText("Engine Active — Voice + History enabled")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // WAKELOCK
    // ────────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DrClicker:WakeLock")
            wakeLock?.acquire(WAKELOCK_MS)
        } catch (e: Exception) {
            Log.e(TAG, "WakeLock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
    }

    // ────────────────────────────────────────────────────────────────
    // HELPERS
    // ────────────────────────────────────────────────────────────────

    private fun collectText(node: AccessibilityNodeInfo, fn: (String) -> Unit) {
        try {
            node.text?.toString()?.takeIf { it.isNotBlank() }?.let(fn)
        } catch (_: Exception) {}
        val n = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until n) {
            val child = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            collectText(child, fn)
            recycleNode(child)
        }
    }

    private fun toNumber(text: String): Double {
        return try {
            val clean = STRIP_NON_NUM.matcher(text).replaceAll("")
            if (clean.isNotEmpty() && NUMBER_RE.matcher(clean).matches()) {
                clean.toDouble()
            } else {
                -1.0
            }
        } catch (_: Exception) {
            -1.0
        }
    }

    private fun recycleNode(node: AccessibilityNodeInfo) {
        if (Build.VERSION.SDK_INT < 33) {
            try { node.recycle() } catch (_: Exception) {}
        }
    }

    private fun beep() {
        try {
            val tg = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 90)
            tg.startTone(ToneGenerator.TONE_PROP_BEEP, 90)
            handler.postDelayed({
                tg.startTone(ToneGenerator.TONE_PROP_BEEP, 90)
                handler.postDelayed({ tg.release() }, 200L)
            }, 150L)
        } catch (_: Exception) {}
    }

    private fun log(msg: String) {
        Log.i(TAG, msg)
        try {
            val ts = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
            FileWriter(logFile, true).use { it.write("[$ts] $msg\n") }
        } catch (_: Exception) {}
    }
}
