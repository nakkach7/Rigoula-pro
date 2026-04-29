"""
Rigoula Smart Farming — Backend v2.0
CTO Architecture: State machine hydraulique + multi-serre + safety controller
"""

import time
import json
import os
import logging
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

from firebase_admin import credentials, initialize_app, db, messaging

# ═══════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"
DATABASE_URL = "https://rigoula-smart-default-rtdb.firebaseio.com"
FCM_TOPIC = "rigoula_alerts"

CHECK_INTERVAL = 10           # secondes entre cycles
ALERT_COOLDOWN = 300          # anti-spam alertes (5 min)
PUMP_WATCHDOG_TIMEOUT = 1800  # pompe centrale max ON sans confirmation (30 min)
EV_WATCHDOG_TIMEOUT = 600     # électrovanne max OPEN sans confirmation (10 min)

SERRES = ["tomate", "tomate_cerise"]

# ═══════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("rigoula")

# ═══════════════════════════════════════════════════════
# FIREBASE INIT
# ═══════════════════════════════════════════════════════
firebase_key = os.environ.get("FIREBASE_KEY")
cred = credentials.Certificate(
    json.loads(firebase_key) if firebase_key else SERVICE_ACCOUNT_FILE
)
initialize_app(cred, {"databaseURL": DATABASE_URL})
log.info("✅ Firebase connecté")

# ═══════════════════════════════════════════════════════
# ENUMS — états machine
# ═══════════════════════════════════════════════════════
class PumpState(Enum):
    OFF = "OFF"
    ON  = "ON"

class EVState(Enum):
    CLOSED = "CLOSED"
    OPEN   = "OPEN"

class Mode(Enum):
    AUTO   = "AUTO"
    MANUEL = "MANUEL"

class FillState(Enum):
    UNKNOWN  = 0
    LOW      = 1   # niveau bas actif → urgent
    FILLING  = 2   # pompe en cours
    FULL     = 3   # niveau haut atteint
    NORMAL   = 4   # entre les deux

# ═══════════════════════════════════════════════════════
# FIREBASE REFERENCES
# ═══════════════════════════════════════════════════════
def ref(path: str):
    return db.reference(path)

def serre_capteurs(sid): return ref(f"/serres/{sid}/capteurs")
def serre_cmd(sid):      return ref(f"/serres/{sid}/cmd")
def serre_config(sid):   return ref(f"/serres/{sid}/config")
def serre_alert(sid):    return ref(f"/serres/{sid}/last_alert")
def serre_history(sid):  return ref(f"/serres/{sid}/historique")

reservoir_ref   = ref("/hydraulique/reservoir")
pump_ref        = ref("/hydraulique/pompe")
hydraulic_cfg   = ref("/hydraulique/config")

# ═══════════════════════════════════════════════════════
# NORMALIZATION — compatibilité v1 → v2
# ═══════════════════════════════════════════════════════
def normalize_serre_data(raw: dict, serre_id: str) -> dict:
    """
    Normalise les champs Firebase peu importe la version ESP32.
    Priorité : nouveau champ > ancien champ > défaut.
    """
    def fget(key, alt=None, default=0.0):
        v = raw.get(key) or raw.get(alt)
        if v is None:
            return default
        try:
            return float(v)
        except (TypeError, ValueError):
            return default

    def sget(key, alt=None, default=""):
        return str(raw.get(key) or raw.get(alt) or default)

    # soil : "soil_percent" (v2) > "soil" (v1)
    soil = fget("soil_percent", "soil", 0.0)

    # ev : "ev" (v2) > "ev1" (v1), normalise ON/OFF → OPEN/CLOSED
    ev_raw = sget("ev", "ev1", "CLOSED")
    ev = "OPEN" if ev_raw in ("ON", "OPEN") else "CLOSED"

    # pump state
    pump = sget("pump", "pompe", "OFF")

    # time : string ou unix timestamp → string
    t = raw.get("time", "--:--")
    if isinstance(t, (int, float)):
        import datetime
        t = datetime.datetime.fromtimestamp(t).strftime("%H:%M:%S")

    return {
        "temperature":   fget("temperature"),
        "humidity":      fget("humidity"),
        "soil_percent":  max(0.0, min(100.0, soil)),
        "soil_raw":      int(fget("soil_raw", default=0)),
        "pump":          pump,
        "ev":            ev,
        "mode":          sget("mode", default="AUTO"),
        "time":          str(t),
        # capteurs niveau (certains ESP32 les envoient)
        "level_low":     bool(raw.get("low_level") or raw.get("level_low", False)),
        "level_high":    bool(raw.get("high_level") or raw.get("level_high", False)),
    }

def normalize_reservoir(raw: dict) -> dict:
    if not raw:
        return {"level_low": False, "level_high": False, "fill_percent": 50.0}
    return {
        "level_low":    bool(raw.get("level_low", raw.get("low_level", False))),
        "level_high":   bool(raw.get("level_high", raw.get("high_level", False))),
        "fill_percent": float(raw.get("fill_percent", 50.0)),
    }

# ═══════════════════════════════════════════════════════
# HYDRAULIC STATE MACHINE
# ═══════════════════════════════════════════════════════
@dataclass
class HydraulicState:
    pump_state: PumpState = PumpState.OFF
    mode: Mode            = Mode.AUTO
    fill_state: FillState = FillState.NORMAL
    can_run: bool         = True
    pump_on_since: float  = 0.0   # timestamp quand pompe allumée
    last_fill_time: float = 0.0   # timestamp dernier remplissage terminé

hydraulic = HydraulicState()

def compute_fill_state(res: dict) -> FillState:
    low  = res["level_low"]
    high = res["level_high"]
    if low and not high:
        return FillState.LOW
    if high:
        return FillState.FULL
    if hydraulic.pump_state == PumpState.ON:
        return FillState.FILLING
    return FillState.NORMAL

def hydraulic_safety_check() -> tuple[bool, str]:
    """
    Retourne (can_run, reason).
    Bloque la pompe si conditions dangereuses.
    """
    now = time.time()

    # Watchdog : pompe ON trop longtemps sans niveau haut
    if (hydraulic.pump_state == PumpState.ON and
            hydraulic.pump_on_since > 0 and
            (now - hydraulic.pump_on_since) > PUMP_WATCHDOG_TIMEOUT):
        return False, "watchdog_timeout"

    return True, "ok"

def process_hydraulic(res_data: dict, pump_data: dict) -> list:
    """
    Machine d'état hydraulique. Retourne liste d'alertes FCM.
    """
    alerts = []
    res = normalize_reservoir(res_data or {})

    # Lecture mode + commande depuis Firebase
    mode_str  = str((pump_data or {}).get("mode", "AUTO")).upper()
    cmd_str   = str((pump_data or {}).get("cmd", "OFF")).upper()
    state_str = str((pump_data or {}).get("state", "OFF")).upper()

    hydraulic.mode = Mode.AUTO if mode_str == "AUTO" else Mode.MANUEL

    prev_fill = hydraulic.fill_state
    hydraulic.fill_state = compute_fill_state(res)

    can_run, reason = hydraulic_safety_check()
    hydraulic.can_run = can_run

    now = time.time()

    if hydraulic.mode == Mode.AUTO:
        # Décision automatique
        if not can_run:
            if hydraulic.pump_state == PumpState.ON:
                _set_hydraulic_pump(PumpState.OFF)
                alerts.append(("pump_watchdog",
                    f"⚠️ Pompe centrale arrêtée (sécurité watchdog {reason})"))

        elif hydraulic.fill_state == FillState.LOW:
            if hydraulic.pump_state == PumpState.OFF:
                _set_hydraulic_pump(PumpState.ON)
                alerts.append(("reservoir_low",
                    "🔴 Réservoir bas — remplissage automatique démarré"))

        elif hydraulic.fill_state == FillState.FULL:
            if hydraulic.pump_state == PumpState.ON:
                _set_hydraulic_pump(PumpState.OFF)
                hydraulic.last_fill_time = now
                alerts.append(("reservoir_full",
                    "✅ Réservoir plein — pompe arrêtée"))

    else:
        # Mode MANUEL : exécuter la commande Flutter
        target = PumpState.ON if cmd_str == "ON" else PumpState.OFF
        if not can_run and target == PumpState.ON:
            log.warning("⚠️ Commande manuelle pompe bloquée (sécurité)")
        elif hydraulic.pump_state != target:
            _set_hydraulic_pump(target)

    # Écriture état consolidé dans Firebase
    try:
        pump_ref.update({
            "state":    hydraulic.pump_state.value,
            "can_run":  hydraulic.can_run,
            "fill_state": hydraulic.fill_state.value,
            "mode":     hydraulic.mode.value,
        })
        reservoir_ref.update({
            "level_low":    res["level_low"],
            "level_high":   res["level_high"],
            "fill_percent": res["fill_percent"],
        })
    except Exception as e:
        log.error(f"❌ Erreur écriture hydraulique: {e}")

    # Log état
    log.info(
        f"  [HYDRAULIQUE] mode={hydraulic.mode.value} "
        f"pump={hydraulic.pump_state.value} "
        f"fill={hydraulic.fill_state.name} "
        f"can_run={hydraulic.can_run}"
    )
    return alerts

def _set_hydraulic_pump(state: PumpState):
    now = time.time()
    if state == PumpState.ON:
        hydraulic.pump_on_since = now
    else:
        hydraulic.pump_on_since = 0.0
    hydraulic.pump_state = state
    try:
        pump_ref.update({"state": state.value, "last_change": int(now)})
        log.info(f"🔧 Pompe centrale → {state.value}")
    except Exception as e:
        log.error(f"❌ Erreur set pump: {e}")

# ═══════════════════════════════════════════════════════
# SERRE STATE MACHINE
# ═══════════════════════════════════════════════════════
@dataclass
class SerreState:
    serre_id: str
    ev_state: EVState    = EVState.CLOSED
    ev_open_since: float = 0.0
    mode: Mode           = Mode.AUTO

serre_states: dict[str, SerreState] = {
    sid: SerreState(serre_id=sid) for sid in SERRES
}

def process_serre(serre_id: str, raw_capteurs: dict, config: dict) -> list:
    """
    Machine d'état par serre. Retourne liste d'alertes.
    """
    if not raw_capteurs:
        return []

    alerts = []
    data   = normalize_serre_data(raw_capteurs, serre_id)
    state  = serre_states[serre_id]
    now    = time.time()

    cfg = config or {}
    temp_min  = float(cfg.get("temp_min", 15.0))
    temp_max  = float(cfg.get("temp_max", 35.0))
    hum_min   = float(cfg.get("hum_min", 30.0))
    hum_max   = float(cfg.get("hum_max", 80.0))
    soil_min  = float(cfg.get("soil_min", 30.0))
    soil_max  = float(cfg.get("soil_max", 70.0))

    temp  = data["temperature"]
    hum   = data["humidity"]
    soil  = data["soil_percent"]

    label = serre_id.replace("_", " ").title()

    log.info(
        f"  [{serre_id}] 🌡️{temp:.1f}°C({temp_min}-{temp_max}) "
        f"💧{hum:.1f}%({hum_min}-{hum_max}) "
        f"🌱{soil:.1f}%({soil_min}-{soil_max}) "
        f"mode={data['mode']}"
    )

    # ── Lecture mode + commande EV ───────────────────────────────────────
    cmd_data = {}
    try:
        cmd_data = serre_cmd(serre_id).get() or {}
    except Exception:
        pass

    mode_str = str(cmd_data.get("mode") or data["mode"] or "AUTO").upper()
    state.mode = Mode.AUTO if mode_str == "AUTO" else Mode.MANUEL

    # ── EV watchdog ─────────────────────────────────────────────────────
    if (state.ev_state == EVState.OPEN and
            state.ev_open_since > 0 and
            (now - state.ev_open_since) > EV_WATCHDOG_TIMEOUT):
        _set_ev(serre_id, EVState.CLOSED, state)
        alerts.append(("ev_watchdog",
            f"⚠️ {label} — électrovanne fermée (sécurité timeout)"))

    # ── Disponibilité hydraulique ────────────────────────────────────────
    hydraulic_ok = (
        hydraulic.can_run or
        hydraulic.fill_state in (FillState.FULL, FillState.NORMAL)
    )

    # ── Logique EV AUTO ──────────────────────────────────────────────────
    if state.mode == Mode.AUTO:
        if soil < soil_min and hydraulic_ok and state.ev_state == EVState.CLOSED:
            _set_ev(serre_id, EVState.OPEN, state)
            alerts.append(("soil_low",
                f"🏜️ {label} — sol sec {soil:.1f}% → irrigation ouverte"))
        elif (soil > soil_max or not hydraulic_ok) and state.ev_state == EVState.OPEN:
            _set_ev(serre_id, EVState.CLOSED, state)
            reason = "sol humide" if soil > soil_max else "hydraulique indisponible"
            alerts.append(("soil_high",
                f"🌊 {label} — {reason} → irrigation fermée"))

    else:
        # MANUEL : exécuter commande Flutter
        ev_cmd = str(cmd_data.get("ev", "CLOSED")).upper()
        target = EVState.OPEN if ev_cmd in ("OPEN", "ON") else EVState.CLOSED
        if state.ev_state != target:
            _set_ev(serre_id, target, state)

    # ── Alertes capteurs ─────────────────────────────────────────────────
    if temp < temp_min:
        alerts.append(("temp_low",
            f"🥶 {label} — température basse {temp:.1f}°C (min {temp_min}°C)"))
    elif temp > temp_max:
        alerts.append(("temp_high",
            f"🔥 {label} — température élevée {temp:.1f}°C (max {temp_max}°C)"))

    if hum < hum_min:
        alerts.append(("humidity_low",
            f"💨 {label} — humidité basse {hum:.1f}% (min {hum_min}%)"))
    elif hum > hum_max:
        alerts.append(("humidity_high",
            f"💧 {label} — humidité élevée {hum:.1f}% (max {hum_max}%)"))

    # ── Écriture état normalisé dans Firebase ────────────────────────────
    try:
        serre_capteurs(serre_id).update({
            "soil_percent": round(soil, 2),
            "ev": state.ev_state.value,
            "time": data["time"],
        })
    except Exception as e:
        log.error(f"❌ Erreur écriture capteurs [{serre_id}]: {e}")

    # ── Historique quotidien ─────────────────────────────────────────────
    _update_history(serre_id, temp, hum, soil)

    return alerts

def _set_ev(serre_id: str, state_ev: EVState, serre_state: SerreState):
    now = time.time()
    serre_state.ev_state = state_ev
    if state_ev == EVState.OPEN:
        serre_state.ev_open_since = now
    else:
        serre_state.ev_open_since = 0.0
    try:
        serre_capteurs(serre_id).update({
            "ev": state_ev.value,
            "ev_last_change": int(now),
        })
        log.info(f"🔧 [{serre_id}] EV → {state_ev.value}")
    except Exception as e:
        log.error(f"❌ Erreur set EV [{serre_id}]: {e}")

def _update_history(serre_id: str, temp: float, hum: float, soil: float):
    try:
        import datetime
        today = datetime.date.today().isoformat()
        day_ref = serre_history(serre_id).child(today)
        snap = day_ref.get()
        if not snap:
            day_ref.set({
                "temp_min": temp, "temp_max": temp,
                "hum_min": hum,  "hum_max": hum,
                "soil_min": soil, "soil_max": soil,
                "ev_open_count": 0,
            })
        else:
            day_ref.update({
                "temp_min": min(snap.get("temp_min", temp), temp),
                "temp_max": max(snap.get("temp_max", temp), temp),
                "hum_min":  min(snap.get("hum_min", hum), hum),
                "hum_max":  max(snap.get("hum_max", hum), hum),
                "soil_min": min(snap.get("soil_min", soil), soil),
                "soil_max": max(snap.get("soil_max", soil), soil),
            })
    except Exception as e:
        log.error(f"❌ Erreur historique [{serre_id}]: {e}")

# ═══════════════════════════════════════════════════════
# ALERT MANAGER
# ═══════════════════════════════════════════════════════
last_alert_times: dict = {}   # key → (message, timestamp)

def should_send(key: str, message: str) -> bool:
    now = time.time()
    prev = last_alert_times.get(key)
    if prev and prev[0] == message and (now - prev[1]) < ALERT_COOLDOWN:
        remaining = int(ALERT_COOLDOWN - (now - prev[1]))
        log.debug(f"⏳ Anti-spam [{key}] ({remaining}s)")
        return False
    last_alert_times[key] = (message, now)
    return True

def send_fcm(serre_id: str, alert_type: str, title: str, body: str):
    try:
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            topic=FCM_TOPIC,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="max",
                    visibility="public",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default")
                )
            ),
            data={
                "serre":     serre_id,
                "type":      alert_type,
                "message":   body,
                "timestamp": str(int(time.time())),
            },
        )
        resp = messaging.send(msg)
        log.info(f"📲 FCM [{serre_id}] type={alert_type} → {resp}")
    except Exception as e:
        log.error(f"❌ FCM [{serre_id}]: {e}")

def dispatch_alerts(serre_id: str, alerts: list):
    if not alerts:
        return
    primary_type, _ = alerts[0]
    label = serre_id.replace("_", " ").title()

    if len(alerts) == 1:
        title = f"⚠️ Alerte {label}"
        body  = alerts[0][1]
    else:
        title = f"⚠️ {label} — {len(alerts)} alertes"
        body  = " | ".join(msg for _, msg in alerts)

    key = f"{serre_id}_{primary_type}"
    if should_send(key, body):
        send_fcm(serre_id, primary_type, title, body)
        try:
            serre_alert(serre_id).set({
                "type":      primary_type,
                "alerts":    [m for _, m in alerts],
                "message":   body,
                "timestamp": int(time.time()),
            })
        except Exception as e:
            log.error(f"❌ Erreur save_alert [{serre_id}]: {e}")

def dispatch_hydraulic_alerts(alerts: list):
    if not alerts:
        return
    primary_type, _ = alerts[0]
    body = " | ".join(m for _, m in alerts)
    key  = f"hydraulique_{primary_type}"
    if should_send(key, body):
        send_fcm("hydraulique", primary_type, "💧 Système hydraulique", body)

# ═══════════════════════════════════════════════════════
# COMMAND LISTENERS (Flutter → ESP32 via Firebase)
# ═══════════════════════════════════════════════════════
def make_serre_mode_listener(serre_id):
    def handler(event):
        try:
            if event.data in ("AUTO", "MANUEL"):
                serre_capteurs(serre_id).update({"mode": event.data})
                log.info(f"🔧 [{serre_id}] mode cmd → {event.data}")
        except Exception as e:
            log.error(f"❌ listener mode [{serre_id}]: {e}")
    return handler

def make_serre_ev_listener(serre_id):
    def handler(event):
        try:
            val = str(event.data or "").upper()
            if val in ("OPEN", "CLOSED", "ON", "OFF"):
                ev_norm = "OPEN" if val in ("OPEN", "ON") else "CLOSED"
                serre_capteurs(serre_id).update({"ev": ev_norm})
                log.info(f"🔧 [{serre_id}] EV cmd → {ev_norm}")
        except Exception as e:
            log.error(f"❌ listener EV [{serre_id}]: {e}")
    return handler

def setup_listeners():
    for sid in SERRES:
        ref(f"/serres/{sid}/cmd/mode").listen(make_serre_mode_listener(sid))
        ref(f"/serres/{sid}/cmd/ev").listen(make_serre_ev_listener(sid))
        log.info(f"👂 Listeners [{sid}] actifs")

# ═══════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════
def main():
    log.info("🚀 Backend Rigoula v2.0 démarré")
    log.info(f"🏡 Serres: {SERRES}")
    log.info("-" * 50)

    setup_listeners()

    cycle = 0
    while True:
        cycle += 1
        log.info(f"\n📥 Cycle #{cycle} — {time.strftime('%H:%M:%S')}")

        try:
            # ── Hydraulique ──────────────────────────────────────────────
            res_data  = ref("/hydraulique/reservoir").get() or {}
            pump_data = ref("/hydraulique/pompe").get() or {}
            # Fallback : ancienne structure hydraulique/hydraulique
            if not res_data:
                old = ref("/hydraulique/hydraulique").get() or {}
                res_data = old
                pump_data = {"mode": old.get("mode","AUTO"), "state": old.get("pump","OFF")}

            hydraulic_alerts = process_hydraulic(res_data, pump_data)
            dispatch_hydraulic_alerts(hydraulic_alerts)

            # ── Serres ───────────────────────────────────────────────────
            for sid in SERRES:
                capteurs = serre_capteurs(sid).get()
                config   = serre_config(sid).get()

                if not capteurs:
                    log.warning(f"⚠️  [{sid}] Pas de données capteurs")
                    continue

                serre_alerts = process_serre(sid, capteurs, config)

                if serre_alerts:
                    dispatch_alerts(sid, serre_alerts)
                else:
                    log.info(f"✅ [{sid}] OK")

        except KeyboardInterrupt:
            log.info("\n🛑 Arrêt manuel")
            break
        except Exception as e:
            log.error(f"❌ Erreur cycle #{cycle}: {e}", exc_info=True)

        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()