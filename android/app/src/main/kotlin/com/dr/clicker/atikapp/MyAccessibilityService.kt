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
 * Dr.Clicker Accessibility Engine v2.1
 * Features: Anti-bot detection, blocklist, click speed, voice, history
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
            "ஏற்க", "స్వీకరించు", "ಸ್ವೀಕರಿಸಿ",
            "स्वीकार करें", "स्वीकार", "स्वीकार करा", "গ্রহণ করুন"
        )

        private val NUMBER_RE = Pattern.compile("^[0-9]+\\.?[0-9]*$")
        private val STRIP_NON_NUM = Pattern.compile("[^0-9.]")

        @Volatile var isEngineOn = false
            private set

        val rideHistory = JSONArray()

        // ── ANTI-BOT: Track recent click patterns to avoid detection ──
        private val recentClickTimes = mutableListOf<Long>()
        private var lastIdleUntil = 0L
        private var clickCountSinceIdle = 0
    }

    private lateinit var flutterPrefs: SharedPreferences
    private lateinit var meClickerPrefs: SharedPreferences
    private var logFile: File? = null
    private var isForegroundRunning = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var lastEventMs = 0L
    private val seenNodes = LinkedHashSet<String>()
    private val handler = Handler(Looper.getMainLooper())
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
        tts = TextToSpeech(this, this)
        loadHistory()
        acquireWakeLock()
        log("🚀 Dr.Clicker v2.1 | Anti-Bot + Blocklist + Voice + History")
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            val locale = langToLocale(getVoiceLang())
            tts?.setLanguage(locale)
            tts?.setSpeechRate(1.1f)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (getBoolPref("master_switch")) {
            if (!isForegroundRunning) { startForegroundService(); isForegroundRunning = true }
            acquireWakeLock()
        }
        return START_STICKY
    }

    override fun onInterrupt() { isEngineOn = false }

    override fun onDestroy() {
        isEngineOn = false
        releaseWakeLock()
        tts?.stop(); tts?.shutdown()
        if (getBoolPref("master_switch")) {
            try {
                if (Build.VERSION.SDK_INT >= 26)
                    startForegroundService(Intent(this, MyAccessibilityService::class.java))
                else startService(Intent(this, MyAccessibilityService::class.java))
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }

    // ────────────────────────────────────────────────────────────────
    // PREFS HELPERS
    // ────────────────────────────────────────────────────────────────

    private fun getBoolPref(key: String): Boolean = try {
        flutterPrefs.getBoolean("flutter.$key", false)
    } catch (_: Exception) { false }

    private fun getIntPref(key: String): Int = try {
        flutterPrefs.getInt("flutter.$key", 0)
    } catch (_: Exception) { 0 }

    private fun getFloatPref(key: String): Float = try {
        flutterPrefs.getFloat("flutter.$key", 0f)
    } catch (_: Exception) { 0f }

    private fun getClickSpeed(): Long = try {
        flutterPrefs.getFloat("flutter.click_speed_ms", 50f).toLong().coerceIn(10L, 500L)
    } catch (_: Exception) { 50L }

    private fun isVoiceOn(): Boolean = try {
        flutterPrefs.getBoolean("flutter.voice_on", true)
    } catch (_: Exception) { true }

    private fun isPriceFilterOn(): Boolean = try {
        flutterPrefs.getBoolean("flutter.price_filter_on", false)
    } catch (_: Exception) { false }

    private fun isDistFilterOn(): Boolean = try {
        flutterPrefs.getBoolean("flutter.dist_filter_on", false)
    } catch (_: Exception) { false }

    private fun getVoiceLang(): String = try {
        flutterPrefs.getString("flutter.voice_lang", "en") ?: "en"
    } catch (_: Exception) { "en" }

    /** Get blocklist as list of lowercase strings */
    private fun getBlocklist(): List<String> = try {
        val raw = flutterPrefs.getString("flutter.blocklist", "") ?: ""
        if (raw.isEmpty()) emptyList()
        else raw.split("|||").filter { it.isNotBlank() }.map { it.trim().lowercase(Locale.ROOT) }
    } catch (_: Exception) { emptyList() }

    private fun langToLocale(lang: String): Locale = when (lang) {
        "ta" -> Locale("ta", "IN")
        "te" -> Locale("te", "IN")
        "kn" -> Locale("kn", "IN")
        "hi" -> Locale("hi", "IN")
        else -> Locale.ENGLISH
    }

    // ────────────────────────────────────────────────────────────────
    // ANTI-BOT DETECTION ENGINE
    // ────────────────────────────────────────────────────────────────

    /**
     * Human-like click delay with anti-bot randomization.
     * - Base delay from user settings
     * - Gaussian jitter (not uniform — looks more human)
     * - Occasional micro-pauses to simulate human hesitation
     * - Periodic "idle" breaks every 5-12 clicks
     */
    private fun getHumanDelay(): Long {
        val base = getClickSpeed()
        val now = System.currentTimeMillis()

        // Anti-bot: periodic idle breaks (simulate human looking at screen)
        if (now < lastIdleUntil) {
            val remaining = lastIdleUntil - now
            log("🤖 Anti-bot: idle break ${remaining}ms remaining")
            return remaining + base
        }

        clickCountSinceIdle++

        // Every 5-12 clicks, take a 0.5-3 second break
        val idleThreshold = Random.nextInt(5, 13)
        if (clickCountSinceIdle >= idleThreshold) {
            clickCountSinceIdle = 0
            val idleMs = Random.nextLong(500L, 3000L)
            lastIdleUntil = now + idleMs
            log("🤖 Anti-bot: scheduling ${idleMs}ms idle break")
            return idleMs + base
        }

        // Gaussian jitter — more natural than uniform random
        // Using Box-Muller transform since kotlin.random.Random doesn't have nextGaussian()
        val u1 = Random.nextDouble(0.0001, 1.0)
        val u2 = Random.nextDouble(0.0001, 1.0)
        val gaussian = kotlin.math.sqrt(-2.0 * kotlin.math.ln(u1)) * kotlin.math.cos(2.0 * kotlin.math.PI * u2)
        val jitter = (gaussian * base * 0.25).toLong()
        val microHesitation = if (Random.nextInt(100) < 15) Random.nextLong(50L, 200L) else 0L

        return (base + jitter + microHesitation).coerceAtLeast(10L)
    }

    /**
     * Human-like tap with randomized position offset and gesture duration.
     * Bots always tap exact center — humans don't.
     */
    private fun humanTap(x: Float, y: Float) {
        // Random offset within 8px radius (simulates finger imprecision)
        val offsetX = x + Random.nextFloat() * 16f - 8f
        val offsetY = y + Random.nextFloat() * 16f - 8f

        // Variable gesture duration: 30-80ms (humans vary press duration)
        val duration = Random.nextLong(30L, 80L)

        // Slight curved path (not perfectly straight)
        val path = Path().apply {
            moveTo(offsetX, offsetY)
            val dx = Random.nextFloat() * 3f - 1.5f
            val dy = Random.nextFloat() * 3f - 1.5f
            lineTo(offsetX + dx, offsetY + dy)
        }

        val stroke = GestureDescription.StrokeDescription(path, 0L, duration)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCancelled(gesture: GestureDescription) {
                Log.w(TAG, "Gesture cancelled at ($offsetX,$offsetY)")
            }
        }, handler)
    }

    // ────────────────────────────────────────────────────────────────
    // HISTORY
    // ────────────────────────────────────────────────────────────────

    private fun loadHistory() {
        try {
            val saved = meClickerPrefs.getString("ride_history", null)
            if (!saved.isNullOrEmpty()) {
                val arr = JSONArray(saved)
                synchronized(rideHistory) {
                    while (rideHistory.length() > 0) rideHistory.remove(0)
                    for (i in 0 until arr.length()) rideHistory.put(arr.get(i))
                }
            }
        } catch (_: Exception) {}
    }

    private fun saveHistory() {
        try {
            meClickerPrefs.edit().putString("ride_history", rideHistory.toString()).apply()
        } catch (_: Exception) {}
    }

    private fun addRideToHistory(app: String, price: Double, pickup: Double, drop: Double,
                                  latencyMs: Long, tapX: Int, tapY: Int, blocked: Boolean = false) {
        val entry = JSONObject().apply {
            put("app", app)
            put("price", if (price > 0) price.toInt().toString() else "?")
            put("pickup", if (pickup > 0) String.format("%.1f", pickup) else "?")
            put("drop", if (drop > 0) String.format("%.1f", drop) else "?")
            put("latency", latencyMs)
            put("tapX", tapX); put("tapY", tapY)
            put("time", SimpleDateFormat("dd MMM yyyy, HH:mm:ss", Locale.getDefault()).format(Date()))
            put("timestamp", System.currentTimeMillis())
            put("blocked", blocked)
        }
        synchronized(rideHistory) {
            rideHistory.put(entry)
            while (rideHistory.length() > MAX_HISTORY) rideHistory.remove(0)
        }
        saveHistory()
    }

    fun clearHistory() {
        synchronized(rideHistory) { while (rideHistory.length() > 0) rideHistory.remove(0) }
        saveHistory()
    }

    // ────────────────────────────────────────────────────────────────
    // EVENT LOOP
    // ────────────────────────────────────────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val masterOn = getBoolPref("master_switch")
        isEngineOn = masterOn

        if (masterOn && !isForegroundRunning) { startForegroundService(); isForegroundRunning = true }
        else if (!masterOn && isForegroundRunning) { stopForeground(STOP_FOREGROUND_REMOVE); isForegroundRunning = false; return }
        if (!masterOn) return

        val now = System.currentTimeMillis()
        if (now - lastEventMs < THROTTLE_MS) return
        lastEventMs = now

        val allWindows = try { windows } catch (_: Exception) { null } ?: return
        for (win in allWindows) {
            val root = win.root ?: continue
            val type = win.type
            if (type == AccessibilityWindowInfo.TYPE_INPUT_METHOD) { recycleNode(root); continue }

            val pkg = try { root.packageName?.toString()?.lowercase(Locale.ROOT) ?: "" } catch (_: Exception) { "" }
            val tag = when {
                pkg.contains("ola") && pkg.contains("driver") -> "Ola"
                pkg.contains("uber") && pkg.contains("driver") -> "Uber"
                pkg.contains("rapido") || pkg.contains("captain") -> "Rapido"
                pkg.contains("namma") || pkg.contains("yatri") -> "Namma"
                type == AccessibilityWindowInfo.TYPE_SYSTEM -> "Popup"
                else -> pkg.take(20)
            }
            scanAndClick(root, now, tag)
            recycleNode(root)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // SCANNER — Blocklist + Filters
    // ────────────────────────────────────────────────────────────────

    private fun scanAndClick(root: AccessibilityNodeInfo, ts: Long, tag: String) {
        val priceFilterOn = isPriceFilterOn()
        val distFilterOn = isDistFilterOn()
        val blocklist = getBlocklist()

        val minPrice = if (priceFilterOn) getIntPref("min_price") else 0
        val maxPrice = if (priceFilterOn) getIntPref("max_price").let { if (it == 0) 99999 else it } else 99999
        val minPickup = if (distFilterOn) getFloatPref("min_pickup") else 0f
        val maxDrop = if (distFilterOn) getFloatPref("max_drop").let { if (it == 0f) 999f else it } else 999f

        // Collect ALL visible text for blocklist checking
        val allTexts = mutableListOf<String>()
        val numbers = mutableListOf<Double>()
        collectTextAndNumbers(root, allTexts, numbers)

        // ── BLOCKLIST CHECK ──
        if (blocklist.isNotEmpty()) {
            val allTextJoined = allTexts.joinToString(" ").lowercase(Locale.ROOT)
            val matchedBlock = blocklist.find { blocked -> allTextJoined.contains(blocked) }
            if (matchedBlock != null) {
                log("[$tag] 🚫 BLOCKED — '$matchedBlock' found in screen text")
                // Save as blocked ride in history
                val price = numbers.find { it in 10.0..9999.0 } ?: -1.0
                val pickup = numbers.find { it in 0.1..50.0 } ?: -1.0
                val drop = numbers.find { it in 0.1..200.0 && it != price } ?: -1.0
                addRideToHistory(tag, price, pickup, drop, 0, 0, 0, blocked = true)
                if (isVoiceOn()) {
                    announceBlocked(tag, matchedBlock)
                }
                return
            }
        }

        var price = numbers.find { it in 10.0..9999.0 } ?: -1.0
        var pickup = numbers.find { it in 0.1..50.0 } ?: -1.0
        var drop = numbers.find { it in 0.1..200.0 && it != price } ?: -1.0

        if (priceFilterOn) {
            if (minPrice > 0 && price > 0 && price < minPrice) { log("[$tag] ✗ Price ₹${price.toInt()} < min ₹$minPrice"); return }
            if (maxPrice > 0 && price > 0 && price > maxPrice) { log("[$tag] ✗ Price ₹${price.toInt()} > max ₹$maxPrice"); return }
        }
        if (distFilterOn) {
            if (minPickup > 0 && pickup > 0 && pickup < minPickup) { log("[$tag] ✗ Pickup ${pickup}km < min"); return }
            if (maxDrop > 0 && drop > 0 && drop > maxDrop) { log("[$tag] ✗ Drop ${drop}km > max"); return }
        }

        clickAccept(root, ts, tag, price, pickup, drop)
    }

    // ────────────────────────────────────────────────────────────────
    // CLICKER — Anti-bot humanized clicks
    // ────────────────────────────────────────────────────────────────

    private fun clickAccept(node: AccessibilityNodeInfo, ts: Long, tag: String,
                             price: Double, pickup: Double, drop: Double) {
        val text = try { node.text?.toString()?.trim() ?: "" } catch (_: Exception) { "" }
        val desc = try { node.contentDescription?.toString()?.trim() ?: "" } catch (_: Exception) { "" }
        val combined = "$text $desc".lowercase(Locale.ROOT)

        if (ACCEPT_KEYWORDS.any { kw -> combined.contains(kw.lowercase(Locale.ROOT)) }) {
            val key = "${node.hashCode()}_$ts"
            if (key in seenNodes) return
            seenNodes.add(key)
            if (seenNodes.size > 300) {
                val iter = seenNodes.iterator()
                repeat(50) { if (iter.hasNext()) { iter.next(); iter.remove() } }
            }

            val bounds = Rect()
            node.getBoundsInScreen(bounds)

            // Anti-bot: humanized delay
            val delay = getHumanDelay()

            val startMs = System.currentTimeMillis()

            if (bounds.width() > 0 && bounds.height() > 0) {
                val cx = bounds.centerX().toFloat()
                val cy = bounds.centerY().toFloat()
                handler.postDelayed({
                    // Anti-bot: humanized tap position
                    humanTap(cx, cy)
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
        meClickerPrefs.edit().putInt("accept_count", count).putLong("last_latency_ms", latencyMs).apply()
        log("[$tag] ✅ ACCEPTED ₹${if (price > 0) price.toInt() else "?"} latency=${latencyMs}ms total=$count")
        addRideToHistory(tag, price, pickup, drop, latencyMs, tapX, tapY)
        beep()
        if (isVoiceOn()) announceRide(tag, price, pickup, drop)
    }

    // ────────────────────────────────────────────────────────────────
    // VOICE
    // ────────────────────────────────────────────────────────────────

    private fun announceRide(tag: String, price: Double, pickup: Double, drop: Double) {
        if (!ttsReady) return
        val lang = getVoiceLang()
        val msg = buildVoiceMessage(tag, price, pickup, drop, lang, false)
        handler.postDelayed({
            try {
                tts?.setLanguage(langToLocale(lang))
                tts?.speak(msg, TextToSpeech.QUEUE_ADD, null, "ride_${System.currentTimeMillis()}")
            } catch (_: Exception) {}
        }, 200L)
    }

    private fun announceBlocked(tag: String, location: String) {
        if (!ttsReady) return
        val lang = getVoiceLang()
        val msg = when (lang) {
            "ta" -> "$tag ride block aayiduchu. Location $location."
            "hi" -> "$tag ride block ho gayi. Location $location."
            "te" -> "$tag ride block ayindi. Location $location."
            "kn" -> "$tag ride block aaytu. Location $location."
            else -> "$tag ride blocked. Location $location."
        }
        handler.postDelayed({
            try {
                tts?.setLanguage(langToLocale(lang))
                tts?.speak(msg, TextToSpeech.QUEUE_ADD, null, "block_${System.currentTimeMillis()}")
            } catch (_: Exception) {}
        }, 100L)
    }

    fun testVoice(lang: String) {
        if (!ttsReady) return
        val msg = buildVoiceMessage("Test", 150.0, 2.0, 5.0, lang, true)
        try {
            tts?.setLanguage(langToLocale(lang))
            tts?.speak(msg, TextToSpeech.QUEUE_FLUSH, null, "test_voice")
        } catch (_: Exception) {}
    }

    private fun buildVoiceMessage(tag: String, price: Double, pickup: Double, drop: Double,
                                   lang: String, isTest: Boolean): String {
        val parts = mutableListOf<String>()
        when (lang) {
            "ta" -> {
                parts.add(if (isTest) "Vanakkam! Dr.Clicker voice test" else "$tag ride accept aayiduchu")
                if (price > 0) parts.add("Price ${price.toInt()} rupees")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometre")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometre")
            }
            "hi" -> {
                parts.add(if (isTest) "Namaste! Dr.Clicker voice test" else "$tag ride accept ho gayi")
                if (price > 0) parts.add("Price ${price.toInt()} rupaye")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometre")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometre")
            }
            "te" -> {
                parts.add(if (isTest) "Namaskaram! Dr.Clicker voice test" else "$tag ride accept ayindi")
                if (price > 0) parts.add("Price ${price.toInt()} rupayalu")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometres")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometres")
            }
            "kn" -> {
                parts.add(if (isTest) "Namaskara! Dr.Clicker voice test" else "$tag ride accept aaytu")
                if (price > 0) parts.add("Price ${price.toInt()} rupayigalu")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometres")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometres")
            }
            else -> {
                parts.add(if (isTest) "Hello! Dr.Clicker voice test" else "$tag ride accepted")
                if (price > 0) parts.add("Price ${price.toInt()} rupees")
                if (pickup > 0) parts.add("Pickup ${String.format("%.1f", pickup)} kilometres")
                if (drop > 0) parts.add("Drop ${String.format("%.1f", drop)} kilometres")
            }
        }
        return parts.joinToString(", ")
    }

    // ────────────────────────────────────────────────────────────────
    // HELPERS
    // ────────────────────────────────────────────────────────────────

    /** Collect both text and numbers in a single tree walk (for blocklist + filters) */
    private fun collectTextAndNumbers(node: AccessibilityNodeInfo,
                                       texts: MutableList<String>, numbers: MutableList<Double>) {
        try {
            val t = node.text?.toString()?.trim() ?: ""
            if (t.isNotEmpty()) {
                texts.add(t)
                val n = toNumber(t)
                if (n > 0) numbers.add(n)
            }
            val d = node.contentDescription?.toString()?.trim() ?: ""
            if (d.isNotEmpty()) texts.add(d)
        } catch (_: Exception) {}
        val n = try { node.childCount } catch (_: Exception) { 0 }
        for (i in 0 until n) {
            val child = try { node.getChild(i) } catch (_: Exception) { null } ?: continue
            collectTextAndNumbers(child, texts, numbers)
            recycleNode(child)
        }
    }

    private fun toNumber(text: String): Double {
        return try {
            val clean = STRIP_NON_NUM.matcher(text).replaceAll("")
            if (clean.isNotEmpty() && NUMBER_RE.matcher(clean).matches()) clean.toDouble() else -1.0
        } catch (_: Exception) { -1.0 }
    }

    private fun recycleNode(node: AccessibilityNodeInfo) {
        if (Build.VERSION.SDK_INT < 33) try { node.recycle() } catch (_: Exception) {}
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

    private fun startForegroundService() {
        val mgr = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26 && mgr.getNotificationChannel(CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Dr.Clicker Engine", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) })
        }
        val pi = android.app.PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java), android.app.PendingIntent.FLAG_IMMUTABLE)
        val notif = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("⚡ Dr.Clicker v2.1")
            .setContentText("Anti-Bot Engine Active")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pi).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34)
            startForeground(NOTIF_ID, notif, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(NOTIF_ID, notif)
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DrClicker:WakeLock")
            wakeLock?.acquire(WAKELOCK_MS)
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
    }

    private fun log(msg: String) {
        Log.i(TAG, msg)
        try {
            val ts = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
            FileWriter(logFile, true).use { it.write("[$ts] $msg\n") }
        } catch (_: Exception) {}
    }
}
