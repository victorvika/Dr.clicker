import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_screen.dart';
import 'strings.dart';

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
  final _blockInput = TextEditingController();

  bool _master       = false;
  bool _a11yOk       = false;
  bool _overlayOk    = false;
  bool _batteryOk    = false;
  bool _floatOn      = false;
  int  _accepts      = 0;
  int  _latencyMs    = 0;
  Timer? _ticker;

  double _clickSpeedMs  = 50.0;
  bool   _priceFilterOn = false;
  bool   _distFilterOn  = false;
  bool   _voiceOn       = true;
  String _voiceLang     = 'en';
  String _appLang       = 'en';
  List<String> _blocklist = [];

  // ── FOREST GREEN PALETTE ──
  static const _fg      = Color(0xFF2E7D32);  // Forest Green primary
  static const _fgLight = Color(0xFF66BB6A);  // Light green accent
  static const _fgDark  = Color(0xFF1B5E20);  // Deep forest
  static const _fgMuted = Color(0xFF388E3C);  // Muted green
  static const _accent  = Color(0xFFA5D6A7);  // Soft mint accent
  static const _card    = Color(0xFF141E14);  // Dark green card
  static const _cardAlt = Color(0xFF0F1A0F);  // Slightly lighter
  static const _border  = Color(0xFF1E3A1E);  // Subtle green border
  static const _bg      = Color(0xFF0A120A);  // Very dark green bg
  static const _txt     = Color(0xFFE8F5E9);  // Near-white green tint
  static const _txtDim  = Color(0xFF81C784);  // Dim green text
  static const _txtMute = Color(0xFF4A6B4A);  // Muted text

  static const _warn    = Color(0xFFFFB74D);  // Warm amber for warnings
  static const _danger  = Color(0xFFEF5350);  // Red for danger
  static const _info    = Color(0xFF4FC3F7);  // Info blue

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
    for (final c in [_minPrice, _maxPrice, _minPickup, _maxDrop, _blockInput]) c.dispose();
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
      _appLang        = p.getString('app_lang') ?? 'en';
      S.setLang(_appLang);

      // Load blocklist
      final blockStr = p.getString('blocklist') ?? '';
      _blocklist = blockStr.isEmpty ? [] : blockStr.split('|||').where((s) => s.isNotEmpty).toList();
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
    p.setString('app_lang',       _appLang);
    p.setString('blocklist',      _blocklist.join('|||'));
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _checkA11y(), _checkOverlay(), _checkBattery(),
      _checkFloat(), _refreshStats(),
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
    try { final ok = await _ch.invokeMethod<bool>('isAccessibilityEnabled') ?? false; if (mounted) setState(() => _a11yOk = ok); } catch (_) {}
  }
  Future<void> _checkOverlay() async {
    try { final ok = await _ch.invokeMethod<bool>('isOverlayPermissionGranted') ?? false; if (mounted) setState(() => _overlayOk = ok); } catch (_) {}
  }
  Future<void> _checkBattery() async {
    try { final ok = await _ch.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false; if (mounted) setState(() => _batteryOk = ok); } catch (_) {}
  }
  Future<void> _checkFloat() async {
    try { final ok = await _ch.invokeMethod<bool>('isFloatingPanelRunning') ?? false; if (mounted) setState(() => _floatOn = ok); } catch (_) {}
  }

  Future<void> _toggle(bool val) async {
    if (val && !_a11yOk) {
      _snack('Enable Accessibility first!');
      await _ch.invokeMethod('openAccessibilitySettings');
      return;
    }
    if (val && !_overlayOk) {
      _snack('Grant overlay permission first!');
      await _ch.invokeMethod('requestOverlayPermission');
      return;
    }
    setState(() => _master = val);
    _save();
    _snack(val ? '⚡ Engine ON' : '🔴 Engine OFF');
  }

  /// Save settings AND toggle engine in one tap
  Future<void> _saveAndToggle() async {
    _save();
    if (!_master) {
      // Want to start engine
      if (!_a11yOk) {
        _snack('Enable Accessibility first!');
        await _ch.invokeMethod('openAccessibilitySettings');
        return;
      }
      if (!_overlayOk) {
        _snack('Grant overlay permission first!');
        await _ch.invokeMethod('requestOverlayPermission');
        return;
      }
      setState(() => _master = true);
      _save();
      _snack('💾 Settings saved • ⚡ Engine started!');
    } else {
      // Want to stop engine
      setState(() => _master = false);
      _save();
      _snack('💾 Settings saved • 🔴 Engine stopped');
    }
  }

  Future<void> _toggleFloat(bool val) async {
    if (val && !_overlayOk) {
      _snack('Overlay permission required');
      await _ch.invokeMethod('requestOverlayPermission');
      return;
    }
    if (val) {
      final ok = await _ch.invokeMethod<bool>('startFloatingPanel') ?? false;
      setState(() => _floatOn = ok);
      _snack(ok ? '🟢 Floating panel on' : 'Overlay permission needed');
    } else {
      await _ch.invokeMethod('stopFloatingPanel');
      setState(() => _floatOn = false);
    }
  }

  void _addBlock() {
    final text = _blockInput.text.trim();
    if (text.isEmpty) return;
    if (_blocklist.any((b) => b.toLowerCase() == text.toLowerCase())) {
      _snack('Already in blocklist');
      return;
    }
    setState(() => _blocklist.add(text));
    _blockInput.clear();
    _save();
    _snack('🚫 "$text" added to blocklist');
  }

  void _removeBlock(int i) {
    final removed = _blocklist[i];
    setState(() => _blocklist.removeAt(i));
    _save();
    _snack('"$removed" removed');
  }

  Future<void> _reset() async {
    await _ch.invokeMethod('resetStats');
    setState(() { _accepts = 0; _latencyMs = 0; });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), duration: const Duration(seconds: 3),
        backgroundColor: _card, behavior: SnackBarBehavior.floating),
  );

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
              const SizedBox(height: 14),
              _appLangCard(),
              const SizedBox(height: 14),
              _permSection(),
              const SizedBox(height: 14),
              _engineCard(),
              const SizedBox(height: 10),
              _floatCard(),
              const SizedBox(height: 10),
              _voiceCard(),
              const SizedBox(height: 14),
              _clickSpeedCard(),
              const SizedBox(height: 14),
              _filterToggle(S.t('price_filter'), S.t('price_desc'), Icons.currency_rupee,
                  _priceFilterOn, (v) { setState(() => _priceFilterOn = v); _save(); },
                  _field(_minPrice, S.t('min_price'), '0'), _field(_maxPrice, S.t('max_price'), '9999')),
              const SizedBox(height: 10),
              _filterToggle(S.t('dist_filter'), S.t('dist_desc'), Icons.map_outlined,
                  _distFilterOn, (v) { setState(() => _distFilterOn = v); _save(); },
                  _field(_minPickup, S.t('min_km'), '0'), _field(_maxDrop, S.t('max_km'), '999')),
              const SizedBox(height: 14),
              _blocklistCard(),
              const SizedBox(height: 14),
              _statsRow(),
              const SizedBox(height: 14),
              _historyBtn(),
              const SizedBox(height: 14),
              _saveAndStartBtn(),
              const SizedBox(height: 10),
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

  // ═══════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════

  Widget _header(bool active) {
    return Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: _fg, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _fg.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: const Icon(Icons.bolt, color: Colors.white, size: 28),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.t('app_name'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _txt)),
        Text(S.t('app_subtitle'), style: const TextStyle(fontSize: 10, color: _txtMute)),
      ])),
      AnimatedContainer(duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _fg.withOpacity(0.15) : _cardAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? _fg.withOpacity(0.5) : _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
              shape: BoxShape.circle, color: active ? _fgLight : _txtMute)),
          const SizedBox(width: 5),
          Text(active ? S.t('status_on') : S.t('status_off'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: active ? _fgLight : _txtMute)),
        ]),
      ),
    ]);
  }

  Widget _appLangCard() {
    return _box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.language, color: _fgLight, size: 14),
        const SizedBox(width: 6),
        Text(S.t('app_lang'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _fgLight, letterSpacing: 0.8)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: S.languages.entries.map((e) {
        final sel = _appLang == e.key;
        return GestureDetector(
          onTap: () {
            setState(() { _appLang = e.key; S.setLang(e.key); });
            _save();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? _fg.withOpacity(0.2) : _cardAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? _fg.withOpacity(0.6) : _border),
            ),
            child: Text(e.value, style: TextStyle(
              fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.w500,
              color: sel ? _fgLight : _txtDim)),
          ),
        );
      }).toList()),
    ]));
  }

  Widget _permSection() {
    return _box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.shield_outlined, color: _fgLight, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(S.t('perm_title'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _fgLight, letterSpacing: 0.6))),
      ]),
      const SizedBox(height: 10),
      _permRow('1', S.t('perm_a11y'), _a11yOk, () => _ch.invokeMethod('openAccessibilitySettings')),
      const SizedBox(height: 6),
      _permRow('2', S.t('perm_overlay'), _overlayOk, () => _ch.invokeMethod('requestOverlayPermission')),
      const SizedBox(height: 6),
      _permRow('3', S.t('perm_battery'), _batteryOk, () => _ch.invokeMethod('requestIgnoreBatteryOptimization')),
    ]));
  }

  Widget _permRow(String step, String label, bool ok, VoidCallback onTap) {
    return GestureDetector(onTap: ok ? null : onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? _fg.withOpacity(0.06) : _cardAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? _fg.withOpacity(0.3) : _border)),
      child: Row(children: [
        Container(width: 20, height: 20, decoration: BoxDecoration(
          shape: BoxShape.circle, color: ok ? _fg.withOpacity(0.15) : _cardAlt),
          child: Center(child: ok
            ? const Icon(Icons.check, color: _fgLight, size: 12)
            : Text(step, style: const TextStyle(color: _fgLight, fontSize: 10, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: ok ? _fgLight : _txt, fontSize: 12, fontWeight: ok ? FontWeight.w400 : FontWeight.w500))),
        if (!ok) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: _fg.withOpacity(0.12), borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _fg.withOpacity(0.3))),
          child: Text(S.t('tap'), style: const TextStyle(color: _fgLight, fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  }

  Widget _engineCard() {
    return _box(child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(
        color: _master ? _fg.withOpacity(0.15) : _cardAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _master ? _fg.withOpacity(0.4) : _border)),
        child: Icon(Icons.bolt, color: _master ? _fgLight : _txtMute, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.t('engine_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txt)),
        Text(_master && _a11yOk ? S.t('engine_on_desc') : S.t('engine_off_desc'),
            style: const TextStyle(fontSize: 10, color: _txtMute)),
      ])),
      Transform.scale(scale: 0.8, child: Switch(value: _master, onChanged: _toggle,
        activeColor: Colors.white, activeTrackColor: _fg,
        inactiveThumbColor: _txtMute, inactiveTrackColor: _border)),
    ]));
  }

  Widget _floatCard() {
    return _box(child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(
        color: _floatOn ? _info.withOpacity(0.12) : _cardAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _floatOn ? _info.withOpacity(0.3) : _border)),
        child: Icon(Icons.picture_in_picture_alt_rounded, color: _floatOn ? _info : _txtMute, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.t('float_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txt)),
        Text(_floatOn ? S.t('float_on_desc') : S.t('float_off_desc'), style: const TextStyle(fontSize: 10, color: _txtMute)),
      ])),
      Transform.scale(scale: 0.8, child: Switch(value: _floatOn, onChanged: _toggleFloat,
        activeColor: Colors.white, activeTrackColor: _info,
        inactiveThumbColor: _txtMute, inactiveTrackColor: _border)),
    ]));
  }

  Widget _voiceCard() {
    return _box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(
          color: _voiceOn ? _accent.withOpacity(0.12) : _cardAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _voiceOn ? _accent.withOpacity(0.3) : _border)),
          child: Icon(Icons.volume_up_rounded, color: _voiceOn ? _accent : _txtMute, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(S.t('voice_title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txt)),
          Text(_voiceOn ? S.t('voice_on_desc') : S.t('voice_off_desc'), style: const TextStyle(fontSize: 10, color: _txtMute)),
        ])),
        Transform.scale(scale: 0.8, child: Switch(value: _voiceOn,
          onChanged: (v) { setState(() => _voiceOn = v); _save(); },
          activeColor: Colors.white, activeTrackColor: _fgMuted,
          inactiveThumbColor: _txtMute, inactiveTrackColor: _border)),
      ]),
      if (_voiceOn) ...[
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.translate, color: _accent, size: 13),
          const SizedBox(width: 5),
          Text(S.t('voice_lang'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _accent, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(
          color: _cardAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _voiceLang, isExpanded: true, dropdownColor: _card,
            icon: const Icon(Icons.arrow_drop_down, color: _fgLight),
            style: const TextStyle(color: _txt, fontSize: 13),
            items: S.languages.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) { if (v != null) { setState(() => _voiceLang = v); _save(); } },
          )),
        ),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 34, child: OutlinedButton.icon(
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: Text(S.t('test_voice'), style: const TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(foregroundColor: _accent,
            side: BorderSide(color: _accent.withOpacity(0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
          onPressed: () => _ch.invokeMethod('testVoice', {'lang': _voiceLang}),
        )),
      ],
    ]));
  }

  Widget _clickSpeedCard() {
    final speed = _clickSpeedMs.round();
    final lbl = speed <= 30 ? S.t('ultra_fast') : speed <= 80 ? S.t('fast') : speed <= 200 ? S.t('normal') : S.t('slow');
    final col = speed <= 30 ? _danger : speed <= 80 ? _fgLight : speed <= 200 ? _fgMuted : _info;

    return _box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.speed_rounded, color: col, size: 14),
        const SizedBox(width: 5),
        Text(S.t('speed_title'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _fgLight, letterSpacing: 0.8)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(5),
              border: Border.all(color: col.withOpacity(0.3))),
          child: Text(lbl, style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: 2),
      Text(S.t('speed_desc').replaceFirst('{0}', speed.toString()),
          style: const TextStyle(fontSize: 10, color: _txtMute)),
      const SizedBox(height: 4),
      Row(children: [
        Text('10ms', style: TextStyle(fontSize: 9, color: _txtMute)),
        Expanded(child: SliderTheme(data: SliderThemeData(
          activeTrackColor: col, inactiveTrackColor: _border,
          thumbColor: col, overlayColor: col.withOpacity(0.1),
          trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
          child: Slider(value: _clickSpeedMs, min: 10, max: 500, divisions: 49,
            onChanged: (v) => setState(() => _clickSpeedMs = v),
            onChangeEnd: (v) { _save(); }))),
        Text('500ms', style: TextStyle(fontSize: 9, color: _txtMute)),
      ]),
      Row(children: [
        _preset(S.t('ultra_fast'), 15, _danger),
        const SizedBox(width: 6),
        _preset(S.t('fast'), 50, _fgLight),
        const SizedBox(width: 6),
        _preset(S.t('normal'), 150, _fgMuted),
        const SizedBox(width: 6),
        _preset(S.t('slow'), 350, _info),
      ]),
    ]));
  }

  Widget _preset(String label, int ms, Color c) {
    final sel = (_clickSpeedMs - ms).abs() < 20;
    return Expanded(child: GestureDetector(onTap: () { setState(() => _clickSpeedMs = ms.toDouble()); _save(); },
      child: Container(padding: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(
        color: sel ? c.withOpacity(0.12) : _cardAlt, borderRadius: BorderRadius.circular(5),
        border: Border.all(color: sel ? c.withOpacity(0.5) : _border)),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sel ? c : _txtMute)))));
  }

  Widget _filterToggle(String title, String desc, IconData icon, bool isOn,
      ValueChanged<bool> onToggle, Widget left, Widget right) {
    return _box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: isOn ? _fgLight : _txtMute, size: 13),
        const SizedBox(width: 5),
        Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: isOn ? _fgLight : _txtMute, letterSpacing: 0.8))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isOn ? _fg.withOpacity(0.12) : _cardAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isOn ? _fg.withOpacity(0.3) : _border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(isOn ? 'ON' : 'OFF', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold,
                color: isOn ? _fgLight : _txtMute)),
            Transform.scale(scale: 0.5, child: Switch(value: isOn, onChanged: onToggle,
              activeColor: Colors.white, activeTrackColor: _fg,
              inactiveThumbColor: _txtMute, inactiveTrackColor: _border)),
          ])),
      ]),
      const SizedBox(height: 2),
      Text(isOn ? desc : S.t('filter_off_desc'), style: const TextStyle(fontSize: 10, color: _txtMute)),
      const SizedBox(height: 10),
      AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: isOn ? 1 : 0.3,
        child: IgnorePointer(ignoring: !isOn, child: Row(children: [
          Expanded(child: left), const SizedBox(width: 8), Expanded(child: right)]))),
    ]));
  }

  // ── BLOCKLIST ──
  Widget _blocklistCard() {
    return _box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.block, color: _warn, size: 14),
        const SizedBox(width: 5),
        Text(S.t('block_title'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _warn, letterSpacing: 0.8)),
        const Spacer(),
        if (_blocklist.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _warn.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _warn.withOpacity(0.3))),
          child: Text('${_blocklist.length}', style: const TextStyle(color: _warn, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: 2),
      Text(S.t('block_desc'), style: const TextStyle(fontSize: 10, color: _txtMute)),
      const SizedBox(height: 10),
      // Input row
      Row(children: [
        Expanded(child: TextField(controller: _blockInput,
          style: const TextStyle(color: _txt, fontSize: 13),
          cursorColor: _fgLight,
          decoration: InputDecoration(
            hintText: S.t('block_add_hint'),
            hintStyle: const TextStyle(color: _txtMute, fontSize: 12),
            filled: true, fillColor: _cardAlt,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _fg, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          onSubmitted: (_) => _addBlock(),
        )),
        const SizedBox(width: 8),
        GestureDetector(onTap: _addBlock, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: _warn.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _warn.withOpacity(0.4))),
          child: Text(S.t('block_add_btn'), style: const TextStyle(color: _warn, fontSize: 11, fontWeight: FontWeight.bold)),
        )),
      ]),
      const SizedBox(height: 10),
      // List
      if (_blocklist.isEmpty)
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(S.t('block_empty'), style: const TextStyle(fontSize: 11, color: _txtMute))))
      else
        Wrap(spacing: 6, runSpacing: 6, children: List.generate(_blocklist.length, (i) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _warn.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _warn.withOpacity(0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_off, color: _warn, size: 12),
              const SizedBox(width: 4),
              Text(_blocklist[i], style: const TextStyle(color: _txt, fontSize: 11)),
              const SizedBox(width: 6),
              GestureDetector(onTap: () => _removeBlock(i),
                child: const Icon(Icons.close, color: _danger, size: 14)),
            ]),
          );
        })),
    ]));
  }

  Widget _statsRow() {
    return Row(children: [
      Expanded(child: _statBox(_accepts.toString(), S.t('rides_accepted'),
          Icons.check_circle_outline_rounded, _accepts > 0 ? _fgLight : _txtMute)),
      const SizedBox(width: 10),
      Expanded(child: _statBox(_latencyMs > 0 ? '${_latencyMs}ms' : '--',
          S.t('last_speed'), Icons.timer_outlined, _latencyMs > 0 ? _fgLight : _txtMute)),
    ]);
  }

  Widget _statBox(String val, String label, IconData icon, Color c) {
    return _box(child: Column(children: [
      Icon(icon, color: c, size: 20),
      const SizedBox(height: 6),
      Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c)),
      const SizedBox(height: 3),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: _txtMute)),
    ]));
  }

  Widget _historyBtn() {
    return SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
      icon: const Icon(Icons.history_rounded, size: 18),
      label: Text(S.t('history_btn'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(backgroundColor: _card, foregroundColor: _fgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: _fg.withOpacity(0.25))), elevation: 0),
      onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => HistoryScreen(prefs: widget.prefs))),
    ));
  }

  Widget _saveAndStartBtn() {
    final active = _master && _a11yOk;
    return SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
      icon: Icon(active ? Icons.stop_circle_rounded : Icons.play_circle_filled_rounded, size: 22),
      label: Text(active ? S.t('save_and_stop') : S.t('save_and_start'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? _danger.withOpacity(0.85) : _fg,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3, shadowColor: _fg.withOpacity(0.3)),
      onPressed: _saveAndToggle,
    ));
  }

  Widget _saveBtn() {
    return SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
      icon: const Icon(Icons.save_alt_rounded, size: 16),
      label: Text(S.t('save_settings'), style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(foregroundColor: _fgLight,
        side: BorderSide(color: _fg.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: () { _save(); _snack('✅ ${S.t("save_settings")}!'); },
    ));
  }

  Widget _resetBtn() {
    return SizedBox(width: double.infinity, height: 38, child: TextButton.icon(
      icon: const Icon(Icons.refresh_rounded, size: 15),
      label: Text(S.t('reset_counter'), style: const TextStyle(fontSize: 12, color: _txtMute)),
      onPressed: _reset,
    ));
  }

  Widget _footer() => Center(child: Text(
    '⚡ Dr.Clicker v2.1 • 100% Free • Offline • Anti-Detection',
    style: TextStyle(fontSize: 9, color: _txtMute.withOpacity(0.5))));

  Widget _box({required Widget child}) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
      child: child);
  }

  Widget _field(TextEditingController ctrl, String label, String hint) {
    return TextField(controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(color: _txt, fontSize: 14), cursorColor: _fgLight,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: _txtMute, fontSize: 11),
        hintStyle: const TextStyle(color: _txtMute, fontSize: 11),
        filled: true, fillColor: _cardAlt,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _fg, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)));
  }
}
