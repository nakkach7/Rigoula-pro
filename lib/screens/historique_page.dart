import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/history_data.dart';

class HistoriquePage extends StatefulWidget {
  const HistoriquePage({super.key});

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  List<DayHistory> _history = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncFromFirebase();
  }

  Future<void> _syncFromFirebase() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('🔄 Début sync historique...');
      final ref = FirebaseDatabase.instance.ref("historique");

      ref.onValue.first
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw Exception('Timeout - pas de réponse Firebase'),
      )
          .then((event) {
        debugPrint('📦 Snapshot reçu: exists=${event.snapshot.exists}');
        debugPrint('📦 Valeur: ${event.snapshot.value}');

        if (!event.snapshot.exists) {
          setState(() {
            _history = [];
            _loading = false;
          });
          return;
        }

        final data =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<DayHistory> result = [];
        data.forEach((date, value) {
          if (value is Map) {
            result.add(DayHistory.fromMap(
                date, Map<dynamic, dynamic>.from(value)));
          }
        });

        result.sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          _history = result.take(7).toList();
          _loading = false;
        });
        debugPrint('✅ Historique chargé: ${_history.length} jours');
      }).catchError((e) {
        debugPrint('❌ Erreur: $e');
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      });
    } catch (e) {
      debugPrint('❌ Erreur sync: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Historique",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _syncFromFirebase,
            tooltip: 'Synchroniser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text("Erreur : $_error",
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _syncFromFirebase,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Réessayer"),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text("Aucun historique disponible",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _syncFromFirebase,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _history.length,
                        itemBuilder: (context, i) =>
                            _DayCard(day: _history[i]),
                      ),
                    ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final DayHistory day;
  const _DayCard({required this.day});

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── En-tête date ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(d.date,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(_expanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Pompe count ───
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.water, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  d.pompeCount == 0
                      ? "Pompe non activée"
                      : "Pompe activée ${d.pompeCount} fois",
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),

            // ─── Détails min/max ───
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildMinMax("Température", d.tempMin, d.tempMax,
                  "°C", Colors.orange),
              const SizedBox(height: 8),
              _buildMinMax(
                  "Humidité air", d.humMin, d.humMax, "%", Colors.blue),
              const SizedBox(height: 8),
              _buildMinMax("Humidité sol", d.soilMin, d.soilMax,
                  "%", Colors.brown),
            ] else ...[
              const SizedBox(height: 8),
              // Aperçu compact quand fermé
              Row(children: [
                _miniChip(
                    "${d.tempMin.toStringAsFixed(0)}-${d.tempMax.toStringAsFixed(0)}°C",
                    Colors.orange),
                const SizedBox(width: 6),
                _miniChip(
                    "${d.humMin.toStringAsFixed(0)}-${d.humMax.toStringAsFixed(0)}%",
                    Colors.blue),
                const SizedBox(width: 6),
                _miniChip(
                    "${d.soilMin.toStringAsFixed(0)}-${d.soilMax.toStringAsFixed(0)}%",
                    Colors.brown),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMinMax(String label, double min, double max,
      String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600)),
          Row(children: [
            _pill(
                "Min ${min.toStringAsFixed(1)}$unit",
                color.withOpacity(0.15),
                color),
            const SizedBox(width: 6),
            _pill("Max ${max.toStringAsFixed(1)}$unit", color,
                Colors.white),
          ]),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}