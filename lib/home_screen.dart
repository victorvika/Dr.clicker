import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const HomeScreen({super.key, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _ch = MethodChannel('com.example.meclicker/settings');

  final _minPrice  = TextEditingController();
  final _maxPrice  = TextEditingController();
  final _minPickup = TextEditingController();
  final _maxDrop   = TextEditingController();

  bool _master       = false;
  bool _a11yOk       = false;
  bool _overlayOk    = false;
  bool _batteryOk    = false;
  bool _floatOn      = false;
  int  _accepts      = 0;
  int  _latencyMs    = 0;
  Timer? _ticker;

  // ── NEW FEATURES ──
  double _clickSpeedMs  = 50.0;   // 10ms to 500ms
  bool   _priceFilterOn = false;  // Price filter ON/OFF
  bool   _distFilterOn  = false;  // Distance filter ON/OFF
  bool   _voiceOn       = true;   // Voice announcement ON/OFF
  String _voiceLang     = 'en';   // Voice language: en, ta, te, kn, hi

  static const _yellow  = Color(0xFFFFD600);
  static const _green   = Color(0xFF00E676);
  static const _red     = Color(0xFFEF5350);
  static const _blue    = Color(0xFF00B0FF);
  static const _orange  = Color(0xFFFF9100);
  static const _purple  = Color(0xFFBB86FC);
  static const _card    = Color(0xFF1A1A1A);
  static const _border  = Color(0xFF2A2A2A);
  static const _bg      = Color(0xFF0D0D0D);

  static const _langs = {
    'en': 'English',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'hi': 'Hindi (हिन्दी)',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _refreshAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    for (final c in [_minPrice, _maxPrice, _minPickup, _maxDrop]) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refreshAll();
  }

  void _loadAll() {
    final p = widget.prefs;
    setState(() {
      _master        = p.getBool('master_switch') ?? false;
      _minPrice.text  = _fmt(p.getInt('min_price'));
      _maxPrice.text  = _fmt(p.getInt('max_price'));
      _minPickup.text = _fmtF(p.getDouble('min_pickup'));
      _maxDrop.text   = _fmtF(p.getDouble('max_drop'));
      _clickSpeedMs   = (p.getDouble('click_speed_ms') ?? 50.0);
      _priceFilterOn  = p.getBool('price_filter_on') ?? false;
      _distFilterOn   = p.getBool('dist_filter_on') ?? false;
      _voiceOn        = p.getBool('voice_on') ?? true;
      _voiceLang      = p.getString('voice_lang') ?? 'en';
    });
    _refreshAll();
  }

  String _fmt(int? v)     => (v == null || v == 0)   ? '' : v.toString();
  String _fmtF(double? v) => (v == null || v == 0.0) ? '' : v.toString();

  void _save() {
    final p = widget.prefs;
    p.setInt('min_price',     int.tryParse(_minPrice.text.trim())     ?? 0);
    p.setInt('max_price',     int.tryParse(_maxPrice.text.trim())     ?? 0);
    p.setDouble('min_pickup', double.tryParse(_minPickup.text.trim()) ?? 0.0);
    p.setDouble('max_drop',   double.tryParse(_maxDrop.text.trim())   ?? 0.0);
    p.setBool('master_switch',    _master);
    p.setDouble('click_speed_ms', _clickSpeedMs);
    p.setBool('price_filter_on',  _priceFilterOn);
    p.setBool('dist_filter_on',   _distFilterOn);
    p.setBool('voice_on',         _voiceOn);
    p.setString('voice_lang',     _voiceLang);
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _checkA11y(),
      _checkOverlay(),
      _checkBattery(),
      _checkFloat(),
      _refreshStats(),
    ]);
  }

  Future<void> _refreshStats() async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('getStats');
      if (mounted && r != null) setState(() {
        _accepts   = (r['acceptCount']   as int?) ?? 0;
        _latencyMs = ((r['lastLatencyMs'] as int?) ?? 0).toInt();
      });
    } catch (_) {}
  }

  Future<void> _checkA11y() async {
    try {
      final ok = await _ch.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      if (mounted) setState(() => _a11yOk = ok);
    } catch (_) {}
  }

  Future<void> _checkOverlay() async {
    try {
      final ok = await _ch.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
      if (mounted) setState(() => _overlayOk = ok);
    } catch (_) {}
  }

  Future<void> _checkBattery() async {
    try {
      final ok = await _ch.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
      if (mounted) setState(() => _batteryOk = ok);
    } catch (_) {}
  }

  Future<void> _checkFloat() async {
    try {
      final ok = await _ch.invokeMethod<bool>('isFloatingPanelRunning') ?? false;
      if (mounted) setState(() => _floatOn = ok);
    } catch (_) {}
  }

  Future<void> _toggle(bool val) async {
    if (val && !_a11yOk) {
      _snack('Pehle Accessibility mein Dr.Clicker enable karo!');
      await _ch.invokeMethod('openAccessibilitySettings');
      return;
    }
    if (val && !_overlayOk) {
      _snack('Overlay permission do — floating panel ke liye zaroori hai');
      await _ch.invokeMethod('requestOverlayPermission');
      return;
    }
    setState(() => _master = val);
    _save();
    _snack(val ? '⚡ Engine ON — Screen monitor ho raha hai!' : '🔴 Engine OFF');
  }

  Future<void> _toggleFloat(bool val) async {
    if (val && !_overlayOk) {
      _snack('Overlay permission zaroori hai — Tap karo "Overlay Grant"');
      await _ch.invokeMethod('requestOverlayPermission');
      return;
    }
    if (val) {
      final ok = await _ch.invokeMethod<bool>('startFloatingPanel') ?? false;
      setState(() => _floatOn = ok);
      if (!ok) _snack('Overlay permission nahi mili');
      else _snack('🟢 Floating panel chalu hua!');
    } else {
      await _ch.invokeMethod('stopFloatingPanel');
      setState(() => _floatOn = false);
      _snack('Floating panel band hua');
    }
  }

  Future<void> _reset() async {
    await _ch.invokeMethod('resetStats');
    setState(() { _accepts = 0; _latencyMs = 0; });
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(
        content: Text(m),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF1A1A1A),
      ));

  @override
  Widget build(BuildContext context) {
    final active = _master && _a11yOk;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(active),
              const SizedBox(height: 16),

              // Permission Steps
              _permSection(active),
              const SizedBox(height: 14),

              // Engine card
              _engineCard(),
              const SizedBox(height: 12),

              // Floating panel card
              _floatCard(),
              const SizedBox(height: 12),

              // ── NEW: Voice Announcement card ──
              _voiceCard(),
              const SizedBox(height: 14),

              // ── NEW: Click Speed card ──
              _clickSpeedCard(),
              const SizedBox(height: 14),

              // ── PRICE FILTER with ON/OFF toggle ──
              _filterCardWithToggle(
                title: 'PRICE FILTER',
                subtitle: 'Rupees (₹) — 0 = koi limit nahi',
                icon: Icons.currency_rupee,
                isOn: _priceFilterOn,
                onToggle: (v) { setState(() => _priceFilterOn = v); _save(); },
                enabled: _priceFilterOn,
                left:  _field(_minPrice,  'Min ₹',   '0'),
                right: _field(_maxPrice,  'Max ₹',   '9999'),
              ),
              const SizedBox(height: 12),

              // ── DISTANCE FILTER with ON/OFF toggle ──
              _filterCardWithToggle(
                title: 'DISTANCE FILTER',
                subtitle: 'Kilometres — 0 = koi limit nahi',
                icon: Icons.map_outlined,
                isOn: _distFilterOn,
                onToggle: (v) { setState(() => _distFilterOn = v); _save(); },
                enabled: _distFilterOn,
                left:  _field(_minPickup, 'Min KM', '0'),
                right: _field(_maxDrop,   'Max KM', '999'),
              ),
              const SizedBox(height: 14),

              // Stats
              _statsRow(active),
              const SizedBox(height: 14),

              // ── NEW: History button ──
              _historyBtn(),
              const SizedBox(height: 14),

              // Save
              _saveBtn(),
              const SizedBox(height: 10),
              _resetBtn(),
              const SizedBox(height: 24),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // HEADER
  // ────────────────────────────────────────────────────────

  Widget _header(bool active) {
    return Row(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: _yellow,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _yellow.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.bolt, color: Colors.black, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dr.Clicker',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Auto-Accept • Rapido & Ola • 100% Free',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _green.withOpacity(0.12) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _green.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: active ? _green : Colors.grey)),
              const SizedBox(width: 5),
              Text(active ? 'ON' : 'OFF',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: active ? _green : Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // PERMISSIONS
  // ────────────────────────────────────────────────────────

  Widget _permSection(bool active) {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.security, color: _yellow, size: 15),
            const SizedBox(width: 6),
            const Text('PERMISSIONS — YEH TEEN STEP KARO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: _yellow, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 12),
          _permRow(
            step: '1', label: 'Accessibility Enable Karo', ok: _a11yOk,
            onTap: () => _ch.invokeMethod('openAccessibilitySettings'), color: _yellow,
          ),
          const SizedBox(height: 8),
          _permRow(
            step: '2', label: 'Overlay Permission Do', ok: _overlayOk,
            onTap: () => _ch.invokeMethod('requestOverlayPermission'), color: _blue,
          ),
          const SizedBox(height: 8),
          _permRow(
            step: '3', label: 'Battery Optimization Hatao', ok: _batteryOk,
            onTap: () => _ch.invokeMethod('requestIgnoreBatteryOptimization'), color: _green,
          ),
        ],
      ),
    );
  }

  Widget _permRow({
    required String step, required String label,
    required bool ok, required VoidCallback onTap, required Color color,
  }) {
    return GestureDetector(
      onTap: ok ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ok ? color.withOpacity(0.08) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ok ? color.withOpacity(0.4) : const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? color.withOpacity(0.2) : const Color(0xFF222222),
              ),
              child: Center(
                child: ok
                    ? Icon(Icons.check, color: color, size: 13)
                    : Text(step, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: ok ? color : Colors.white, fontSize: 13,
                      fontWeight: ok ? FontWeight.w500 : FontWeight.w600)),
            ),
            if (!ok)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text('TAP', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // ENGINE
  // ────────────────────────────────────────────────────────

  Widget _engineCard() {
    return _box(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _master ? _yellow.withOpacity(0.15) : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _master ? _yellow.withOpacity(0.4) : const Color(0xFF333333)),
            ),
            child: Icon(Icons.bolt, color: _master ? _yellow : Colors.grey, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Engine Activation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(_master && _a11yOk
                    ? '⚡ Screen monitor ho raha hai — auto-click chalega'
                    : 'Ride aayegi toh auto-accept karega',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _master, onChanged: _toggle,
              activeColor: Colors.black, activeTrackColor: _yellow,
              inactiveThumbColor: Colors.grey[600], inactiveTrackColor: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // FLOATING PANEL
  // ────────────────────────────────────────────────────────

  Widget _floatCard() {
    return _box(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _floatOn ? _blue.withOpacity(0.15) : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _floatOn ? _blue.withOpacity(0.4) : const Color(0xFF333333)),
            ),
            child: Icon(Icons.picture_in_picture_alt_rounded,
                color: _floatOn ? _blue : Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Floating Panel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(_floatOn
                    ? '🟢 Screen pe dikhta hai — drag kar sako'
                    : 'Rapido/Ola ke upar status panel',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _floatOn, onChanged: _toggleFloat,
              activeColor: Colors.black, activeTrackColor: _blue,
              inactiveThumbColor: Colors.grey[600], inactiveTrackColor: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // ── NEW: VOICE ANNOUNCEMENT CARD ──
  // ────────────────────────────────────────────────────────

  Widget _voiceCard() {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _voiceOn ? _purple.withOpacity(0.15) : const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _voiceOn ? _purple.withOpacity(0.4) : const Color(0xFF333333)),
                ),
                child: Icon(Icons.volume_up_rounded,
                    color: _voiceOn ? _purple : Colors.grey, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Voice Announcement',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(_voiceOn
                        ? '🔊 Ride accept hone pe bolega — price, distance, drop'
                        : 'Voice off — silent mode',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _voiceOn,
                  onChanged: (v) {
                    setState(() => _voiceOn = v);
                    _save();
                    _snack(v ? '🔊 Voice announcement ON' : '🔇 Voice OFF — silent mode');
                  },
                  activeColor: Colors.black, activeTrackColor: _purple,
                  inactiveThumbColor: Colors.grey[600], inactiveTrackColor: Colors.grey[800],
                ),
              ),
            ],
          ),
          if (_voiceOn) ...[
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.language, color: _purple, size: 14),
              const SizedBox(width: 6),
              const Text('VOICE LANGUAGE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      color: _purple, letterSpacing: 1.0)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _purple.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _voiceLang,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A1A),
                  icon: const Icon(Icons.arrow_drop_down, color: _purple),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: _langs.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))
                  ).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _voiceLang = v);
                      _save();
                      _snack('🗣️ Voice language: ${_langs[v]}');
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Test voice button
            SizedBox(
              width: double.infinity, height: 38,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Test Voice', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  side: BorderSide(color: _purple.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await _ch.invokeMethod('testVoice', {'lang': _voiceLang});
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // ── NEW: CLICK SPEED CARD ──
  // ────────────────────────────────────────────────────────

  Widget _clickSpeedCard() {
    final speed = _clickSpeedMs.round();
    final speedLabel = speed <= 30 ? '⚡ Ultra Fast' :
                       speed <= 80 ? '🏃 Fast' :
                       speed <= 200 ? '🚶 Normal' : '🐢 Slow';
    final speedColor = speed <= 30 ? _red :
                       speed <= 80 ? _yellow :
                       speed <= 200 ? _green : _blue;

    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.speed_rounded, color: speedColor, size: 16),
            const SizedBox(width: 6),
            const Text('CLICK SPEED',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: _yellow, letterSpacing: 1.0)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: speedColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: speedColor.withOpacity(0.4)),
              ),
              child: Text(speedLabel,
                  style: TextStyle(color: speedColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Tap delay: ${speed}ms — lower = faster click',
              style: TextStyle(fontSize: 10, color: Colors.grey[700])),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('10ms', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: speedColor,
                    inactiveTrackColor: const Color(0xFF333333),
                    thumbColor: speedColor,
                    overlayColor: speedColor.withOpacity(0.15),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _clickSpeedMs,
                    min: 10, max: 500, divisions: 49,
                    onChanged: (v) { setState(() => _clickSpeedMs = v); },
                    onChangeEnd: (v) { _save(); _snack('⚡ Click speed: ${v.round()}ms'); },
                  ),
                ),
              ),
              Text('500ms', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          // Quick presets
          Row(
            children: [
              _speedPreset('⚡ Ultra', 15, _red),
              const SizedBox(width: 8),
              _speedPreset('🏃 Fast', 50, _yellow),
              const SizedBox(width: 8),
              _speedPreset('🚶 Normal', 150, _green),
              const SizedBox(width: 8),
              _speedPreset('🐢 Slow', 350, _blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speedPreset(String label, int ms, Color color) {
    final selected = (_clickSpeedMs - ms).abs() < 20;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _clickSpeedMs = ms.toDouble());
          _save();
          _snack('⚡ Click speed: ${ms}ms');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? color.withOpacity(0.6) : const Color(0xFF333333),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                  color: selected ? color : Colors.grey[600])),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // FILTER CARDS WITH ON/OFF TOGGLE
  // ────────────────────────────────────────────────────────

  Widget _filterCardWithToggle({
    required String title, required String subtitle,
    required IconData icon, required bool isOn,
    required ValueChanged<bool> onToggle, required bool enabled,
    required Widget left, required Widget right,
  }) {
    final color = enabled ? _yellow : Colors.grey;
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      color: color, letterSpacing: 1.0)),
            ),
            // ON/OFF Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: enabled ? _green.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enabled ? _green.withOpacity(0.4) : Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(enabled ? 'ON' : 'OFF',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                          color: enabled ? _green : Colors.grey[600])),
                  Transform.scale(
                    scale: 0.55,
                    child: Switch(
                      value: isOn,
                      onChanged: onToggle,
                      activeColor: Colors.black,
                      activeTrackColor: _green,
                      inactiveThumbColor: Colors.grey[600],
                      inactiveTrackColor: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(enabled ? subtitle : 'Filter OFF — sab rides accept honge',
              style: TextStyle(fontSize: 10, color: Colors.grey[700])),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1.0 : 0.35,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Row(children: [
                Expanded(child: left),
                const SizedBox(width: 10),
                Expanded(child: right),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // STATS
  // ────────────────────────────────────────────────────────

  Widget _statsRow(bool active) {
    return Row(
      children: [
        Expanded(child: _statBox(
          value: _accepts.toString(), label: 'Rides Accepted',
          icon: Icons.check_circle_outline_rounded,
          color: _accepts > 0 ? _yellow : Colors.grey,
        )),
        const SizedBox(width: 12),
        Expanded(child: _statBox(
          value: _latencyMs > 0 ? '${_latencyMs}ms' : '--',
          label: 'Last Click Speed',
          icon: Icons.timer_outlined,
          color: _latencyMs > 0 ? _green : Colors.grey,
        )),
      ],
    );
  }

  Widget _statBox({required String value, required String label,
      required IconData icon, required Color color}) {
    return _box(
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────
  // ── NEW: HISTORY BUTTON ──
  // ────────────────────────────────────────────────────────

  Widget _historyBtn() {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.history_rounded, size: 20),
        label: const Text('Accepted Orders History',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: _orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: _orange.withOpacity(0.3)),
          ),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => HistoryScreen(prefs: widget.prefs)));
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // SAVE / RESET / FOOTER
  // ────────────────────────────────────────────────────────

  Widget _saveBtn() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save_alt_rounded, size: 19),
        label: const Text('Save Settings',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _yellow, foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          elevation: 4, shadowColor: _yellow.withOpacity(0.4),
        ),
        onPressed: () { _save(); _snack('✅ Settings save ho gayi!'); },
      ),
    );
  }

  Widget _resetBtn() {
    return SizedBox(
      width: double.infinity, height: 44,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 17),
        label: const Text('Reset Counter', style: TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[500],
          side: BorderSide(color: Colors.grey[800]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        onPressed: _reset,
      ),
    );
  }

  Widget _footer() {
    return Center(
      child: Text(
        '⚡ Dr.Clicker v2.0 • 100% Free • Offline • No Login',
        style: TextStyle(fontSize: 10, color: Colors.grey[800]),
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: _yellow,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        hintStyle: TextStyle(color: Colors.grey[800], fontSize: 12),
        filled: true, fillColor: const Color(0xFF111111),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _yellow, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
