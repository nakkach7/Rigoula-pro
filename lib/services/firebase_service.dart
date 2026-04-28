import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

// ─── Serre IDs (Firebase path keys) ───────────────────────────────────────
class SerreId {
  static const String tomate = 'tomate';
  static const String tomate_cerise = 'tomate_cerise';

  static List<String> get all => [tomate, tomate_cerise];
}

class FirebaseService {
  // Each serre has its own sensor reference under /serres/<id>/capteurs
  static DatabaseReference _sensorRef(String serreId) =>
      FirebaseDatabase.instance.ref("serres/$serreId/capteurs");

  static DatabaseReference _pumpRef(String serreId) =>
      FirebaseDatabase.instance.ref("serres/$serreId/pompe/status");

  static DatabaseReference _modeRef(String serreId) =>
      FirebaseDatabase.instance.ref("serres/$serreId/pompe/mode");

  static DatabaseReference _configRef(String serreId) =>
      FirebaseDatabase.instance.ref("serres/$serreId/config");

  static DatabaseReference _historyRef(String serreId) =>
      FirebaseDatabase.instance.ref("serres/$serreId/historique");

  // ─── Initialize ──────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialisé');
    } catch (e) {
      debugPrint('⚠️ Firebase déjà initialisé: $e');
    }
  }

  // ─── Sensor stream (per serre) ───────────────────────────────────────────
  static Stream<DatabaseEvent> getSensorDataStream(String serreId) {
    return _sensorRef(serreId).onValue;
  }

  static Map<String, dynamic>? parseSensorData(DataSnapshot snapshot) {
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return null;
    return {
      'temperature': (data['temperature'] as num?)?.toDouble() ?? 0.0,
      'humidity': (data['humidity'] as num?)?.toDouble() ?? 0.0,
      'soil_percent': (data['soil_percent'] as num?)?.toDouble() ?? 0.0,
      'soil_raw': (data['soil_raw'] as num?)?.toInt() ?? 0,
      'time': data['time']?.toString() ?? "--:--",
      'pump': data['pump']?.toString() ?? "OFF",
      'mode': data['mode']?.toString() ?? "AUTO",
    };
  }

  // ─── Pump control (per serre) ─────────────────────────────────────────────
  static Future<bool> setPumpCommand(String serreId, bool activate) async {
    try {
      await _pumpRef(serreId).set(activate ? "ON" : "OFF");
      return true;
    } catch (e) {
      debugPrint('❌ Erreur setPumpCommand ($serreId): $e');
      return false;
    }
  }

  // ─── Mode control (per serre) ─────────────────────────────────────────────
  static Future<bool> setMode(String serreId, String mode) async {
    try {
      await _modeRef(serreId).set(mode);
      debugPrint('⚙️ Mode $serreId: $mode');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur setMode ($serreId): $e');
      return false;
    }
  }

  // ─── Config: load thresholds from Firebase /serres/<id>/config ───────────
  static Future<Map<String, double>?> loadConfig(String serreId) async {
    try {
      final snapshot = await _configRef(serreId).get();
      if (!snapshot.exists) return null;
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return {
        'temp_min': (data['temp_min'] as num?)?.toDouble() ?? 15.0,
        'temp_max': (data['temp_max'] as num?)?.toDouble() ?? 35.0,
        'hum_min': (data['hum_min'] as num?)?.toDouble() ?? 30.0,
        'hum_max': (data['hum_max'] as num?)?.toDouble() ?? 80.0,
        'soil_min': (data['soil_min'] as num?)?.toDouble() ?? 30.0,
        'soil_max': (data['soil_max'] as num?)?.toDouble() ?? 70.0,
      };
    } catch (e) {
      debugPrint('❌ Erreur loadConfig ($serreId): $e');
      return null;
    }
  }

  // ─── Config: save thresholds to Firebase /serres/<id>/config ─────────────
  static Future<void> saveConfig(String serreId, Map<String, double> config) async {
    try {
      await _configRef(serreId).set(config);
      debugPrint('✅ Config sauvegardée pour $serreId');
    } catch (e) {
      debugPrint('❌ Erreur saveConfig ($serreId): $e');
    }
  }

  // ─── History: save daily min/max per serre ───────────────────────────────
  static Future<void> saveToHistory(String serreId, Map<String, dynamic> data) async {
    try {
      final today = DateTime.now();
      final dateKey =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final ref = _historyRef(serreId).child(dateKey);
      final snapshot = await ref.get();

      double temp = (data['temperature'] as num).toDouble();
      double hum = (data['humidity'] as num).toDouble();
      double soil = (data['soil_percent'] as num).toDouble();

      if (!snapshot.exists) {
        await ref.set({
          'temp_max': temp,
          'temp_min': temp,
          'hum_max': hum,
          'hum_min': hum,
          'soil_max': soil,
          'soil_min': soil,
          'pompe_count': 0,
        });
      } else {
        final existing = Map<dynamic, dynamic>.from(snapshot.value as Map);
        await ref.update({
          'temp_max': temp > (existing['temp_max'] as num) ? temp : existing['temp_max'],
          'temp_min': temp < (existing['temp_min'] as num) ? temp : existing['temp_min'],
          'hum_max': hum > (existing['hum_max'] as num) ? hum : existing['hum_max'],
          'hum_min': hum < (existing['hum_min'] as num) ? hum : existing['hum_min'],
          'soil_max': soil > (existing['soil_max'] as num) ? soil : existing['soil_max'],
          'soil_min': soil < (existing['soil_min'] as num) ? soil : existing['soil_min'],
        });
      }
      debugPrint('📅 Historique [$serreId] mis à jour: $dateKey');
    } catch (e) {
      debugPrint('❌ Erreur saveToHistory ($serreId): $e');
    }
  }

  // ─── History: increment pump count per serre ─────────────────────────────
  static Future<void> incrementPompeCount(String serreId) async {
    try {
      final today = DateTime.now();
      final dateKey =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final ref = _historyRef(serreId).child("$dateKey/pompe_count");
      final snapshot = await ref.get();
      final current = snapshot.exists ? (snapshot.value as num).toInt() : 0;
      await ref.set(current + 1);
      debugPrint('💧 Pompe count [$serreId]: ${current + 1}');
    } catch (e) {
      debugPrint('❌ Erreur incrementPompeCount ($serreId): $e');
    }
  }

  // ─── History: stream per serre ───────────────────────────────────────────
  static Stream<DatabaseEvent> getHistoryStream(String serreId) {
    return _historyRef(serreId).onValue;
  }

  // ─── Test connection ──────────────────────────────────────────────────────
  static Future<void> testConnection() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref("serres").get();
      debugPrint(snapshot.exists
          ? '✅ Firebase OK — serres trouvées'
          : '⚠️ Firebase OK — /serres vide');
    } catch (e) {
      debugPrint('❌ Erreur connexion: $e');
    }
  }
}