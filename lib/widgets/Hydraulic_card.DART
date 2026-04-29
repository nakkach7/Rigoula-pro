// lib/widgets/hydraulic_card.dart
// Dashboard du système hydraulique central (réservoir + pompe)

import 'package:flutter/material.dart';
import '../models/hydraulic_data.dart';

class HydraulicCard extends StatelessWidget {
  final HydraulicData data;
  final VoidCallback onPumpToggle;
  final VoidCallback onModeToggle;
  final bool pumpLoading;

  const HydraulicCard({
    super.key,
    required this.data,
    required this.onPumpToggle,
    required this.onModeToggle,
    this.pumpLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = data.isAlert;

    return Card(
      elevation: isAlert ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isAlert
            ? BorderSide(color: Colors.red.shade400, width: 2)
            : BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isAlert
                ? [Colors.red.shade50, Colors.white]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('💧', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Système Hydraulique',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Pompe centrale · Réservoir',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Mode badge
                GestureDetector(
                  onTap: onModeToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: data.mode == HydraulicMode.auto
                          ? Colors.blue.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      data.mode == HydraulicMode.auto ? '🤖 AUTO' : '🕹 MANUEL',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: data.mode == HydraulicMode.auto
                            ? Colors.blue.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 14),

              // ── Réservoir ────────────────────────────────────────────
              _ReservoirIndicator(data: data),

              const SizedBox(height: 14),

              // ── Statut ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isAlert ? Colors.red.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAlert ? Colors.red.shade300 : Colors.grey.shade200),
                ),
                child: Row(children: [
                  Text(data.fillEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.fillLabel,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isAlert ? Colors.red.shade700 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (!data.canRun)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('BLOQUÉE',
                          style: TextStyle(fontSize: 9, color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Bouton pompe ─────────────────────────────────────────
              _PumpButton(
                isOn:      data.pumpState == PumpState.on,
                isAuto:    data.mode == HydraulicMode.auto,
                canRun:    data.canRun,
                loading:   pumpLoading,
                onTap:     onPumpToggle,
              ),

              // ── Capteurs niveau ───────────────────────────────────────
              const SizedBox(height: 10),
              Row(children: [
                _LevelDot(label: 'Niveau bas',  active: data.levelLow,  color: Colors.red),
                const SizedBox(width: 12),
                _LevelDot(label: 'Niveau haut', active: data.levelHigh, color: Colors.green),
                const Spacer(),
                Text(data.time,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Indicateur visuel réservoir ────────────────────────────────────────────────
class _ReservoirIndicator extends StatelessWidget {
  final HydraulicData data;
  const _ReservoirIndicator({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = (data.fillPercent / 100).clamp(0.0, 1.0);
    final color = pct < 0.2 ? Colors.red
        : pct < 0.5 ? Colors.orange : Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Niveau réservoir',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('${data.fillPercent.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 14,
          ),
        ),
      ],
    );
  }
}

// ── Bouton pompe ───────────────────────────────────────────────────────────────
class _PumpButton extends StatelessWidget {
  final bool isOn, isAuto, canRun, loading;
  final VoidCallback onTap;
  const _PumpButton({
    required this.isOn, required this.isAuto,
    required this.canRun, required this.loading, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isAuto || loading || (!canRun && !isOn);
    final color = !canRun ? Colors.grey
        : isOn ? Colors.red : Colors.green;

    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withOpacity(0.8), color,
            ]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Icon(
                  isAuto ? Icons.smart_toy
                      : isOn ? Icons.power_settings_new : Icons.play_arrow,
                  color: Colors.white, size: 18,
                ),
              const SizedBox(width: 8),
              Text(
                loading ? 'EN COURS...'
                    : isAuto ? 'GÉRÉ AUTOMATIQUEMENT'
                    : isOn ? 'POMPE CENTRALE ON — ARRÊTER'
                    : 'DÉMARRER POMPE CENTRALE',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Indicateur niveau ──────────────────────────────────────────────────────────
class _LevelDot extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  const _LevelDot({required this.label, required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: active ? color : Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }
}