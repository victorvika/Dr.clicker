import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const HistoryScreen({super.key, required this.prefs});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _ch = MethodChannel('com.example.meclicker/settings');

  static const _yellow = Color(0xFFFFD600);
  static const _green  = Color(0xFF00E676);
  static const _red    = Color(0xFFEF5350);
  static const _blue   = Color(0xFF00B0FF);
  static const _orange = Color(0xFFFF9100);
  static const _card   = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _bg     = Color(0xFF0D0D0D);

  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final result = await _ch.invokeMethod<String>('getHistory');
      if (result != null && result.isNotEmpty) {
        final decoded = jsonDecode(result) as List;
        setState(() {
          _history = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      } else {
        // Try from local prefs
        final local = widget.prefs.getString('ride_history');
        if (local != null && local.isNotEmpty) {
          final decoded = jsonDecode(local) as List;
          setState(() {
            _history = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      // Fallback to local prefs
      try {
        final local = widget.prefs.getString('ride_history');
        if (local != null && local.isNotEmpty) {
          final decoded = jsonDecode(local) as List;
          setState(() {
            _history = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } catch (_) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
        content: const Text('Sab accepted orders delete ho jayenge. Sure ho?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _ch.invokeMethod('clearHistory');
      widget.prefs.remove('ride_history');
      setState(() => _history = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ History cleared'),
            backgroundColor: _card),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Order History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 22),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _yellow))
          : _history.isEmpty
              ? _emptyState()
              : _historyList(),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _yellow.withOpacity(0.08),
              border: Border.all(color: _yellow.withOpacity(0.2)),
            ),
            child: Icon(Icons.history_toggle_off_rounded,
                color: _yellow.withOpacity(0.5), size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No Orders Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Engine ON karo aur rides accept hone do.\nYahaan sab dikhega!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }

  Widget _historyList() {
    // Summary stats
    final totalRides = _history.length;
    final rapidoCount = _history.where((r) => (r['app'] ?? '').toLowerCase().contains('rapido')).length;
    final olaCount = _history.where((r) => (r['app'] ?? '').toLowerCase().contains('ola')).length;
    final otherCount = totalRides - rapidoCount - olaCount;

    return Column(
      children: [
        // Summary bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              _summaryChip('Total', totalRides.toString(), _yellow),
              const SizedBox(width: 8),
              _summaryChip('Rapido', rapidoCount.toString(), _green),
              const SizedBox(width: 8),
              _summaryChip('Ola', olaCount.toString(), _blue),
              if (otherCount > 0) ...[
                const SizedBox(width: 8),
                _summaryChip('Other', otherCount.toString(), Colors.grey),
              ],
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _history.length,
            itemBuilder: (ctx, i) {
              final ride = _history[_history.length - 1 - i]; // newest first
              return _rideCard(ride, i);
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _rideCard(Map<String, dynamic> ride, int index) {
    final app = (ride['app'] ?? 'Unknown').toString();
    final price = ride['price']?.toString() ?? '?';
    final pickup = ride['pickup']?.toString() ?? '?';
    final drop = ride['drop']?.toString() ?? '?';
    final timestamp = ride['time']?.toString() ?? '';
    final latency = ride['latency']?.toString() ?? '?';
    final tapX = ride['tapX']?.toString() ?? '';
    final tapY = ride['tapY']?.toString() ?? '';

    final isRapido = app.toLowerCase().contains('rapido');
    final isOla = app.toLowerCase().contains('ola');
    final appColor = isRapido ? _green : isOla ? _blue : _orange;
    final appIcon = isRapido ? Icons.electric_bike_rounded :
                    isOla ? Icons.local_taxi_rounded : Icons.directions_car_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: appColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appColor.withOpacity(0.3)),
                ),
                child: Icon(appIcon, color: appColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: appColor)),
                    Text(timestamp, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _green.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: _green, size: 12),
                    SizedBox(width: 4),
                    Text('Accepted', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoPill(Icons.currency_rupee, '₹$price', _yellow),
              const SizedBox(width: 8),
              _infoPill(Icons.near_me_outlined, '${pickup}km', _blue),
              const SizedBox(width: 8),
              _infoPill(Icons.location_on_outlined, '${drop}km', _orange),
              const SizedBox(width: 8),
              _infoPill(Icons.timer_outlined, '${latency}ms', _green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
