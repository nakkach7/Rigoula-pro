// lib/widgets/anomaly_banner.dart
//
// Displayed at the top of a serre card when an AlertPayload targets that serre.
// Automatically dismissed after [autoDismissSeconds] seconds, or manually
// via the × button.

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alert_payload.dart';

class AnomalyBanner extends StatefulWidget {
  final AlertPayload payload;
  final VoidCallback onDismiss;
  final int autoDismissSeconds;

  const AnomalyBanner({
    super.key,
    required this.payload,
    required this.onDismiss,
    this.autoDismissSeconds = 30,
  });

  @override
  State<AnomalyBanner> createState() => _AnomalyBannerState();
}

class _AnomalyBannerState extends State<AnomalyBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    // Auto-dismiss
    _timer = Timer(Duration(seconds: widget.autoDismissSeconds), _dismiss);
  }

  void _dismiss() {
    _animController.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;

    return SizeTransition(
      sizeFactor: _slideAnim,
      axisAlignment: -1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pulsing icon ────────────────────────────────────────────
              _PulseIcon(icon: p.alertIcon),
              const SizedBox(width: 10),

              // ── Text content ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.alertLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                    if (p.timestamp > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(p.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Dismiss button ──────────────────────────────────────────
              GestureDetector(
                onTap: _dismiss,
                child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int unixSeconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Détecté à $h:$m';
  }
}

// ─── Small pulsing emoji widget ───────────────────────────────────────────────
class _PulseIcon extends StatefulWidget {
  final String icon;
  const _PulseIcon({required this.icon});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: Text(widget.icon, style: const TextStyle(fontSize: 24)),
    );
  }
}