import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

class SerreId {
  static const String tomate        = 'tomate';
  static const String tomate_cerise = 'tomate_cerise';
  static List<String> get all => [tomate, tomate_cerise];
}

class FirebaseService {
  static DatabaseReference _capteursRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/capteurs");
  static DatabaseReference _cmdRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/cmd");
  static DatabaseReference _configRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/config");
  static DatabaseReference _historyRef(String id) =>
      FirebaseDatabase.instance.ref("serres/$id/historique");

  static DatabaseReference get _hydraulicReservoirRef =>
      FirebaseDatabase.instance.ref("hydraulique/reservoir");
  static DatabaseReference get _hydraulicPumpRef =>
      FirebaseDatabase.instance.ref("hydraulique/pompe");
  static DatabaseReference get _logsRef =>
      FirebaseDatabase.instance.ref("logs");

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('✅ Firebase initialisé');
    } catch (e) {
      debugPrint('⚠️ Firebase déjà initialisé: $e');
    }
  }

  static Stream<DatabaseEvent> getSensorDataStream(String id) =>
      _capteursRef(id).onValue;

  static Map<String, dynamic>? parseSensorData(DataSnapshot snapshot) {
    final raw = snapshot.value as Map<dynamic, dynamic>?;
    if (raw == null) return null;

    double soil = (raw['soil_percent'] as num?)?.toDouble() ??
        (raw['soil'] as num?)?.toDouble() ?? 0.0;

    String evRaw = raw['ev']?.toString() ?? raw['ev1']?.toString() ?? 'CLOSED';
    String ev = (evRaw == 'ON' || evRaw == 'OPEN') ? 'OPEN' : 'CLOSED';

    dynamic rawTime = raw['time'];
    String time = '--:--';
    if (rawTime is String) {
      time = rawTime;
    } else if (rawTime is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(rawTime * 1000);
      time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }

    return {
      'temperature':  (raw['temperature'] as num?)?.toDouble() ?? 0.0,
      'humidity':     (raw['humidity']    as num?)?.toDouble() ?? 0.0,
      'soil_percent': soil.clamp(0.0, 100.0),
      'soil_raw':     (raw['soil_raw']    as num?)?.toInt() ?? 0,
      'pump':  raw['pump']?.toString() ?? 'OFF',
      'ev':    ev,
      'mode':  raw['mode']?.toString() ?? 'AUTO',
      'time':  time,
    };
  }

  static Future<bool> setEVCommand(String serreId, bool open) async {
    try {
      await _cmdRef(serreId).update({'ev': open ? 'OPEN' : 'CLOSED'});
      return true;
    } catch (e) {
      debugPrint('❌ setEVCommand ($serreId): $e');
      return false;
    }
  }

  static Future<bool> setMode(String serreId, String mode) async {
    try {
      await _cmdRef(serreId).update({'mode': mode});
      return true;
    } catch (e) {
      debugPrint('❌ setMode ($serreId): $e');
      return false;
    }
  }

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
    } catch (e) {
      debugPrint('❌ saveConfig ($serreId): $e');
    }
  }

  static Stream<DatabaseEvent> getHistoryStream(String id) =>
      _historyRef(id).onValue;

  static Future<void> saveToHistory(
      String serreId, Map<String, dynamic> data) async {
    try {
      final key = _todayKey();
      final dayRef = _historyRef(serreId).child(key);
      final snap = await dayRef.get();

      double temp = (data['temperature'] as num).toDouble();
      double hum  = (data['humidity']    as num).toDouble();
      double soil = (data['soil_percent'] as num).toDouble();

      if (!snap.exists) {
        await dayRef.set({
          'temp_max':     temp,
          'temp_min':     temp,
          'hum_max':      hum,
          'hum_min':      hum,
          'soil_max':     soil,
          'soil_min':     soil,
          'pump_count':   0,
          'pump_duration':0,
          'ev_count':     0,
          'ev_duration':  0,
        });
      } else {
        final ex = Map<dynamic, dynamic>.from(snap.value as Map);
        await dayRef.update({
          'temp_max': temp > (ex['temp_max'] as num? ?? temp) ? temp : ex['temp_max'],
          'temp_min': temp < (ex['temp_min'] as num? ?? temp) ? temp : ex['temp_min'],
          'hum_max':  hum  > (ex['hum_max']  as num? ?? hum)  ? hum  : ex['hum_max'],
          'hum_min':  hum  < (ex['hum_min']  as num? ?? hum)  ? hum  : ex['hum_min'],
          'soil_max': soil > (ex['soil_max'] as num? ?? soil) ? soil : ex['soil_max'],
          'soil_min': soil < (ex['soil_min'] as num? ?? soil) ? soil : ex['soil_min'],
        });
      }
    } catch (e) {
      debugPrint('❌ saveToHistory ($serreId): $e');
    }
  }

  static Future<void> incrementEVCount(String serreId) async {
    try {
      final ref = _historyRef(serreId).child("${_todayKey()}/ev_count");
      final snap = await ref.get();
      final current = snap.exists ? (snap.value as num).toInt() : 0;
      await ref.set(current + 1);
      debugPrint('📊 ev_count[$serreId] → ${current + 1}');
    } catch (e) {
      debugPrint('❌ incrementEVCount ($serreId): $e');
    }
  }
  static Future<void> incrementPumpCount() async {
  try {
    final ref = _historyRef(SerreId.tomate).child("${_todayKey()}/pump_count");
    final snap = await ref.get();
    final current = snap.exists ? (snap.value as num).toInt() : 0;
    await ref.set(current + 1);
    debugPrint('📊 pump_count → ${current + 1}');
  } catch (e) {
    debugPrint('❌ incrementPumpCount: $e');
  }
}

  static Future<void> incrementEVOpenCount(String serreId) =>
      incrementEVCount(serreId);

  static Stream<DatabaseEvent> getHydraulicReservoirStream() =>
      _hydraulicReservoirRef.onValue;

  static Stream<DatabaseEvent> getHydraulicPumpStream() =>
      _hydraulicPumpRef.onValue;

  static Future<bool> setHydraulicPumpCmd(bool on) async {
    try {
      final value = on ? 'ON' : 'OFF';

      await Future.wait([
        _cmdRef(SerreId.tomate).update({
          'mode': 'MANUEL',
          'pump': value,
        }),
        _hydraulicPumpRef.update({
          'cmd':   value,
          'state': value,
          'mode':  'MANUEL',
        }),
      ]);

      debugPrint('✅ setHydraulicPumpCmd → pump=$value (mode MANUEL forcé)');
      return true;
    } catch (e) {
      debugPrint('❌ setHydraulicPumpCmd: $e');
      return false;
    }
  }

  static Future<bool> setHydraulicMode(String mode) async {
    try {
      await Future.wait([
        _cmdRef(SerreId.tomate).update({'mode': mode}),
        _hydraulicPumpRef.update({'mode': mode}),
      ]);
      return true;
    } catch (e) {
      debugPrint('❌ setHydraulicMode: $e');
      return false;
    }
  }

  static Future<void> logAction({
    required String serreId,
    required String type,
    required String source,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final entry = <String, dynamic>{
        'serre':  serreId,
        'type':   type,
        'source': source,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      if (extra != null) entry.addAll(extra);
      await _logsRef.push().set(entry);
    } catch (e) {
      debugPrint('❌ logAction ($serreId / $type): $e');
    }
  }

  static Future<void> testConnection() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("serres").get();
      debugPrint(snap.exists ? '✅ Firebase OK' : '⚠️ /serres vide');
    } catch (e) {
      debugPrint('❌ Connexion Firebase: $e');
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}