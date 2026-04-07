import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final DatabaseReference _db =
      FirebaseDatabase.instance.ref("capteurs/dernier");

  static final DatabaseReference _pumpRef =
  FirebaseDatabase.instance.ref("capteurs/commandes/pompe");
  static final DatabaseReference _modeRef =
  FirebaseDatabase.instance.ref("capteurs/commandes/mode");

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

  static Stream<DatabaseEvent> getSensorDataStream() {
    return _db.onValue;
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

// ✅ Badel "ON"/"OFF" bech yewafaq Arduino
  static Future<bool> setPumpCommand(bool activate) async {
    try {
      await _pumpRef.set(activate ? "ON" : "OFF");
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> setMode(String mode) async {
    try {
      await _modeRef.set(mode);
      debugPrint('⚙️ Mode: $mode');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur mode: $e');
      return false;
    }
  }

  // ─── Sauvegarde historique (max/min par jour) ───
  static Future<void> saveToHistory(Map<String, dynamic> data) async {
    try {
      final today = DateTime.now();
      final dateKey =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final ref = FirebaseDatabase.instance.ref("historique/$dateKey");
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
      debugPrint('📅 Historique mis à jour: $dateKey');
    } catch (e) {
      debugPrint('❌ Erreur saveToHistory: $e');
    }
  }

  // ─── Incrémenter le compteur d'activations pompe ───
  static Future<void> incrementPompeCount() async {
    try {
      final today = DateTime.now();
      final dateKey =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final ref =
          FirebaseDatabase.instance.ref("historique/$dateKey/pompe_count");
      final snapshot = await ref.get();
      final current = snapshot.exists ? (snapshot.value as num).toInt() : 0;
      await ref.set(current + 1);
      debugPrint('💧 Pompe count: ${current + 1}');
    } catch (e) {
      debugPrint('❌ Erreur incrementPompeCount: $e');
    }
  }

  static Future<void> testConnection() async {
    try {
      final snapshot = await _db.get();
      if (snapshot.exists) {
        debugPrint('✅ Firebase OK: ${snapshot.value}');
      } else {
        debugPrint('⚠️ Firebase OK - pas de données dans capteurs/dernier');
      }
    } catch (e) {
      debugPrint('❌ Erreur connexion: $e');
    }
  }
}