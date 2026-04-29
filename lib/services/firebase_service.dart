// lib/services/firebase_service.dart  — v2
// Ajouts : hydraulique, commandes EV, normalisation, ThresholdConfig complet

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

class SerreId {
  static const String tomate         = 'tomate';
  static const String tomate_cerise  = 'tomate_cerise';
  static List<String> get all => [tomate, tomate_cerise];
}

class FirebaseService {
  // ── Refs serres ────────────────────────────────────────────────────────────
  static DatabaseReference _capteursRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/capteurs");
  static DatabaseReference _cmdRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/cmd");
  static DatabaseReference _configRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/config");
  static DatabaseReference _historyRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/historique");
  static DatabaseReference _lastAlertRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/last_alert");

  // ── Refs hydraulique ───────────────────────────────────────────────────────
  static DatabaseReference get _hydraulicReservoirRef =>
      FirebaseDatabase.instance.ref("hydraulique/reservoir");
  static DatabaseReference get _hydraulicPumpRef =>
      FirebaseDatabase.instance.ref("hydraulique/pompe");

  // ── Init ───────────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('✅ Firebase initialisé');
    } catch (e) {
      debugPrint('⚠️ Firebase déjà initialisé: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // SERRES
  // ══════════════════════════════════════════════════════════════════════

  static Stream<DatabaseEvent> getSensorDataStream(String id) =>
      _capteursRef(id).onValue;

  /// Normalise les champs pour rester compatible v1 et v2
  static Map<String, dynamic>? parseSensorData(DataSnapshot snapshot) {
    final raw = snapshot.value as Map<dynamic, dynamic>?;
    if (raw == null) return null;

    // soil : soil_percent (v2) > soil (v1)
    double soil = (raw['soil_percent'] as num?)?.toDouble() ??
        (raw['soil'] as num?)?.toDouble() ?? 0.0;

    // ev : v2 "OPEN"/"CLOSED", v1 "ON"/"OFF"
    String evRaw = raw['ev']?.toString() ?? raw['ev1']?.toString() ?? 'CLOSED';
    String ev = (evRaw == 'ON' || evRaw == 'OPEN') ? 'OPEN' : 'CLOSED';

    // time : string ou unix
    dynamic rawTime = raw['time'];
    String time = '--:--';
    if (rawTime is String) {
      time = rawTime;
    } else if (rawTime is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(rawTime * 1000);
      time = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
    }

    return {
      'temperature':  (raw['temperature'] as num?)?.toDouble() ?? 0.0,
      'humidity':     (raw['humidity']    as num?)?.toDouble() ?? 0.0,
      'soil_percent': soil.clamp(0.0, 100.0),
      'soil_raw':     (raw['soil_raw']    as num?)?.toInt()    ?? 0,
      'pump':         raw['pump']?.toString()  ?? 'OFF',
      'ev':           ev,
      'mode':         raw['mode']?.toString()  ?? 'AUTO',
      'time':         time,
    };
  }

  // ── Commandes ──────────────────────────────────────────────────────────────

  /// Écriture commande EV — nouveau chemin /cmd/ev
  static Future<bool> setEVCommand(String serreId, bool open) async {
    try {
      await _cmdRef(serreId).update({'ev': open ? 'OPEN' : 'CLOSED'});
      return true;
    } catch (e) {
      debugPrint('❌ setEVCommand ($serreId): $e');
      return false;
    }
  }

  /// Commande mode serre
  static Future<bool> setMode(String serreId, String mode) async {
    try {
      await _cmdRef(serreId).update({'mode': mode});
      return true;
    } catch (e) {
      debugPrint('❌ setMode ($serreId): $e');
      return false;
    }
  }

  /// Compatibilité v1 — commande pompe directe (certains ESP32 écoutent ça)
  static Future<bool> setPumpCommand(String serreId, bool activate) async {
    try {
      // Écriture double pour compatibilité
      await Future.wait([
        FirebaseDatabase.instance.ref("serres/$serreId/pompe/status")
            .set(activate ? "ON" : "OFF"),
        _capteursRef(serreId).update({'pump': activate ? 'ON' : 'OFF'}),
      ]);
      return true;
    } catch (e) {
      debugPrint('❌ setPumpCommand ($serreId): $e');
      return false;
    }
  }

  // ── Config ─────────────────────────────────────────────────────────────────

  static Future<Map<String, double>?> loadConfig(String serreId) async {
    try {
      final snap = await _configRef(serreId).get();
      if (!snap.exists) return null;
      final d = Map<dynamic, dynamic>.from(snap.value as Map);
      return {
        'temp_min': (d['temp_min'] as num?)?.toDouble() ?? 18.0,
        'temp_max': (d['temp_max'] as num?)?.toDouble() ?? 30.0,
        'hum_min':  (d['hum_min']  as num?)?.toDouble() ?? 40.0,
        'hum_max':  (d['hum_max']  as num?)?.toDouble() ?? 80.0,
        'soil_min': (d['soil_min'] as num?)?.toDouble() ?? 30.0,
        'soil_max': (d['soil_max'] as num?)?.toDouble() ?? 70.0,
      };
    } catch (e) {
      debugPrint('❌ loadConfig ($serreId): $e');
      return null;
    }
  }

  static Future<void> saveConfig(String serreId, Map<String, double> cfg) async {
    try {
      await _configRef(serreId).set(cfg);
      debugPrint('✅ Config sauvegardée [$serreId]');
    } catch (e) {
      debugPrint('❌ saveConfig ($serreId): $e');
    }
  }

  // ── Historique ─────────────────────────────────────────────────────────────

  static Stream<DatabaseEvent> getHistoryStream(String id) =>
      _historyRef(id).onValue;

  static Future<void> saveToHistory(String serreId, Map<String, dynamic> data) async {
    try {
      final today = DateTime.now();
      final key = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
      final dayRef = _historyRef(serreId).child(key);
      final snap   = await dayRef.get();
      double temp  = (data['temperature'] as num).toDouble();
      double hum   = (data['humidity']    as num).toDouble();
      double soil  = (data['soil_percent'] as num).toDouble();
      if (!snap.exists) {
        await dayRef.set({
          'temp_max': temp, 'temp_min': temp,
          'hum_max':  hum,  'hum_min':  hum,
          'soil_max': soil, 'soil_min': soil,
          'ev_open_count': 0,
        });
      } else {
        final ex = Map<dynamic, dynamic>.from(snap.value as Map);
        await dayRef.update({
          'temp_max': temp > (ex['temp_max'] as num) ? temp : ex['temp_max'],
          'temp_min': temp < (ex['temp_min'] as num) ? temp : ex['temp_min'],
          'hum_max':  hum  > (ex['hum_max']  as num) ? hum  : ex['hum_max'],
          'hum_min':  hum  < (ex['hum_min']  as num) ? hum  : ex['hum_min'],
          'soil_max': soil > (ex['soil_max'] as num) ? soil : ex['soil_max'],
          'soil_min': soil < (ex['soil_min'] as num) ? soil : ex['soil_min'],
        });
      }
    } catch (e) {
      debugPrint('❌ saveToHistory ($serreId): $e');
    }
  }

  static Future<void> incrementEVOpenCount(String serreId) async {
    try {
      final today = DateTime.now();
      final key   = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
      final r     = _historyRef(serreId).child("$key/ev_open_count");
      final snap  = await r.get();
      await r.set((snap.exists ? (snap.value as num).toInt() : 0) + 1);
    } catch (e) {
      debugPrint('❌ incrementEVOpenCount ($serreId): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HYDRAULIQUE
  // ══════════════════════════════════════════════════════════════════════

  static Stream<DatabaseEvent> getHydraulicReservoirStream() =>
      _hydraulicReservoirRef.onValue;

  static Stream<DatabaseEvent> getHydraulicPumpStream() =>
      _hydraulicPumpRef.onValue;

  /// Commande pompe centrale (Flutter → Firebase → Python → ESP32)
  static Future<bool> setHydraulicPumpCmd(bool on) async {
    try {
      await _hydraulicPumpRef.update({'cmd': on ? 'ON' : 'OFF'});
      return true;
    } catch (e) {
      debugPrint('❌ setHydraulicPumpCmd: $e');
      return false;
    }
  }

  /// Basculer mode AUTO/MANUEL pompe centrale
  static Future<bool> setHydraulicMode(String mode) async {
    try {
      await _hydraulicPumpRef.update({'mode': mode});
      return true;
    } catch (e) {
      debugPrint('❌ setHydraulicMode: $e');
      return false;
    }
  }

  // ── Test connexion ─────────────────────────────────────────────────────────
  static Future<void> testConnection() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("serres").get();
      debugPrint(snap.exists ? '✅ Firebase OK' : '⚠️ /serres vide');
    } catch (e) {
      debugPrint('❌ Connexion Firebase: $e');
    }
  }
}