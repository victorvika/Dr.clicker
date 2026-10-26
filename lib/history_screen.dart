import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';

class HistoryScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const HistoryScreen({super.key, required this.prefs});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _ch = MethodChannel('com.example.meclicker/settings');

  static const _fg      = Color(0xFF2E7D32);
  static const _fgLight = Color(0xFF66BB6A);
  static const _fgMuted = Color(0xFF388E3C);
  static const _accent  = Color(0xFFA5D6A7);
  static const _card    = Color(0xFF141E14);
  static const _cardAlt = Color(0xFF0F1A0F);
  static const _border  = Color(0xFF1E3A1E);
  static const _bg      = Color(0xFF0A120A);
  static const _txt     = Color(0xFFE8F5E9);
  static const _txtDim  = Color(0xFF81C784);
  static const _txtMute = Color(0xFF4A6B4A);
  static const _warn    = Color(0xFFFFB74D);
  static const _danger  = Color(0xFFEF5350);
  static const _info    = Color(0xFF4FC3F7);

  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadHistory(); }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final result = await _ch.invokeMethod<String>('getHistory');
      if (result != null && result.isNotEmpty && result != '[]') {
        final decoded = jsonDecode(result) as List;
        setState(() {
          _history = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      } else {
        final local = widget.prefs.getString('ride_history');
        if (local != null && local.isNotEmpty && local != '[]') {
          final decoded = jsonDecode(local) as List;
          setState(() {
            _history = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (_) {
      try {
        final local = widget.prefs.getString('ride_history');
        if (local != null && local.isNotEmpty && local != '[]') {
          final decoded = jsonDecode(local) as List;
          setState(() {
            _history = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
      } catch (_) {}
      setState(() => _loading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      title: Text(S.t('hist_clear'), style: const TextStyle(color: _txt)),
      content: Text(S.t('hist_clear_desc'), style: const TextStyle(color: _txtMute)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: Text(S.t('cancel'), style: const TextStyle(color: _txtMute))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text(S.t('delete_all'), style: const TextStyle(color: _danger))),
      ],
    ));
    if (confirm == true) {
      await _ch.invokeMethod('clearHistory');
      widget.prefs.remove('ride_history');
      setState(() => _history = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: _txt, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Text(S.t('hist_title'), style: const TextStyle(color: _txt, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [if (_history.isNotEmpty) IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: _danger, size: 20),
          onPressed: _clearHistory)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: _fg))
        : _history.isEmpty ? _emptyState() : _historyList(),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 70, height: 70, decoration: BoxDecoration(
      shape: BoxShape.circle, color: _fg.withOpacity(0.08), border: Border.all(color: _fg.withOpacity(0.2))),
      child: Icon(Icons.history_toggle_off_rounded, color: _fg.withOpacity(0.4), size: 36)),
    const SizedBox(height: 16),
    Text(S.t('hist_empty_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _txt)),
    const SizedBox(height: 6),
    Text(S.t('hist_empty_desc'), textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _txtMute, height: 1.5)),
  ]));

  Widget _historyList() {
    final total = _history.length;
    final rapido = _history.where((r) => (r['app'] ?? '').toLowerCase().contains('rapido')).length;
    final ola = _history.where((r) => (r['app'] ?? '').toLowerCase().contains('ola')).length;
    final blocked = _history.where((r) => r['blocked'] == true).length;
    final other = total - rapido - ola;

    return Column(children: [
      Container(margin: const EdgeInsets.fromLTRB(16, 8, 16, 10), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
        child: Row(children: [
          _chip(S.t('total'), total.toString(), _fgLight),
          const SizedBox(width: 6),
          _chip('Rapido', rapido.toString(), _fg),
          const SizedBox(width: 6),
          _chip('Ola', ola.toString(), _info),
          if (blocked > 0) ...[const SizedBox(width: 6), _chip(S.t('blocked'), blocked.toString(), _warn)],
        ])),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _history.length,
        itemBuilder: (ctx, i) {
          final ride = _history[_history.length - 1 - i];
          return _rideCard(ride);
        })),
    ]);
  }

  Widget _chip(String label, String count, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: c.withOpacity(0.06), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.2))),
      child: Column(children: [
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
        Text(label, style: TextStyle(fontSize: 8, color: _txtMute)),
      ])));
  }

  Widget _rideCard(Map<String, dynamic> ride) {
    final app = (ride['app'] ?? 'Unknown').toString();
    final price = ride['price']?.toString() ?? '?';
    final pickup = ride['pickup']?.toString() ?? '?';
    final drop = ride['drop']?.toString() ?? '?';
    final timestamp = ride['time']?.toString() ?? '';
    final latency = ride['latency']?.toString() ?? '?';
    final isBlocked = ride['blocked'] == true;
    final isRapido = app.toLowerCase().contains('rapido');
    final isOla = app.toLowerCase().contains('ola');
    final appColor = isBlocked ? _warn : isRapido ? _fg : isOla ? _info : _fgMuted;
    final appIcon = isRapido ? Icons.electric_bike_rounded :
                    isOla ? Icons.local_taxi_rounded : Icons.directions_car_rounded;

    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(
            color: appColor.withOpacity(0.12), borderRadius: BorderRadius.circular(7),
            border: Border.all(color: appColor.withOpacity(0.3))),
            child: Icon(appIcon, color: appColor, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appColor)),
            Text(timestamp, style: TextStyle(fontSize: 9, color: _txtMute)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isBlocked ? _warn : _fg).withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: (isBlocked ? _warn : _fg).withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isBlocked ? Icons.block : Icons.check_circle, color: isBlocked ? _warn : _fgLight, size: 10),
              const SizedBox(width: 3),
              Text(isBlocked ? S.t('blocked') : S.t('accepted'),
                  style: TextStyle(color: isBlocked ? _warn : _fgLight, fontSize: 9, fontWeight: FontWeight.bold)),
            ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _pill(Icons.currency_rupee, '₹$price', _fgLight),
          const SizedBox(width: 6),
          _pill(Icons.near_me_outlined, '${pickup}km', _info),
          const SizedBox(width: 6),
          _pill(Icons.location_on_outlined, '${drop}km', _accent),
          const SizedBox(width: 6),
          _pill(Icons.timer_outlined, '${latency}ms', _fgMuted),
        ]),
      ]));
  }

  Widget _pill(IconData icon, String text, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.withOpacity(0.15))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: c, size: 12),
        const SizedBox(width: 3),
        Flexible(child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
      ])));
  }
}
