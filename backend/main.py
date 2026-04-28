import time
from firebase_admin import credentials, initialize_app, db, messaging
import os
import json

# =========================
# CONFIGURATION
# =========================
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"
DATABASE_URL = "https://rigoula-smart-default-rtdb.firebaseio.com"
TOPIC_NAME = "rigoula_alerts"
CHECK_INTERVAL_SECONDS = 10
NOTIFICATION_COOLDOWN = 300
SERRES = ["tomate", "tomate_cerise"]

# =========================
# FIREBASE INIT
# =========================
firebase_key = os.environ.get("FIREBASE_KEY")
if firebase_key:
    cred = credentials.Certificate(json.loads(firebase_key))
else:
    cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
initialize_app(cred, {'databaseURL': DATABASE_URL})

print("✅ Backend Python Rigoula démarré (multi-serre + FCM data payload)")
print(f"🏡 Serres: {SERRES}")
print("-" * 50)

last_sent = {s: {"message": None, "time": 0} for s in SERRES}

# =========================
# FIREBASE REFERENCES
# =========================
def sensor_ref(serre_id): return db.reference(f"/serres/{serre_id}/capteurs")
def config_ref(serre_id):  return db.reference(f"/serres/{serre_id}/config")
def pump_cmd_ref(serre_id):return db.reference(f"/serres/{serre_id}/pompe/status")
def mode_cmd_ref(serre_id):return db.reference(f"/serres/{serre_id}/pompe/mode")

# =========================
# FCM — STRUCTURED DATA PAYLOAD
# IMPORTANT: "data" fields are always strings (FCM requirement).
# Flutter reads message.data['serre'], message.data['type'], etc.
# We also send a notification block so the system tray banner appears.
# =========================
def send_push_notification(serre_id: str, alert_type: str, title: str, body: str):
    """
    Sends an FCM message with both a visible notification AND a data payload.

    Data payload keys (all strings):
      serre     — "tomate" | "tomate_cerise"
      type      — "temp_high" | "temp_low" | "humidity_high" | "humidity_low"
                  | "soil_high" | "soil_low"
      message   — human-readable description
      timestamp — unix seconds as string
    """
    try:
        message = messaging.Message(
            # System-tray banner (shown by OS when app is background/terminated)
            notification=messaging.Notification(title=title, body=body),
            topic=TOPIC_NAME,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="max",
                    visibility="public",
                    # click_action tells Flutter to call getInitialMessage()
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                ),
            ),
            # DATA PAYLOAD — drives navigation & highlighting in Flutter
            data={
                "serre":     serre_id,
                "type":      alert_type,           # machine-readable type
                "message":   body,                 # human-readable text
                "timestamp": str(int(time.time())),
            },
        )
        response = messaging.send(message)
        print(f"📲 FCM [{serre_id}] type={alert_type} → {response}")
    except Exception as e:
        print(f"❌ Erreur FCM [{serre_id}]: {e}")


# =========================
# ALERT ANALYSIS
# Returns list of (alert_type, human_message) tuples
# =========================
def analyze_alerts(serre_id: str, sensor_data: dict, config: dict) -> list:
    alerts = []
    if not sensor_data or not config:
        return alerts
    try:
        temperature  = float(sensor_data.get("temperature", 0))
        humidity     = float(sensor_data.get("humidity", 0))
        soil_percent = float(sensor_data.get("soil_percent", 0))

        temp_min = float(config.get("temp_min", 0))
        temp_max = float(config.get("temp_max", 100))
        hum_min  = float(config.get("hum_min", 0))
        hum_max  = float(config.get("hum_max", 100))
        soil_min = float(config.get("soil_min", 0))
        soil_max = float(config.get("soil_max", 100))

        print(f"  [{serre_id}] 🌡️{temperature}°C ({temp_min}-{temp_max}) "
              f"💧{humidity}% ({hum_min}-{hum_max}) "
              f"🌱{soil_percent}% ({soil_min}-{soil_max})")

        if temperature < temp_min:
            alerts.append(("temp_low",
                f"🥶 Température trop basse : {temperature:.1f}°C (min: {temp_min}°C)"))
        elif temperature > temp_max:
            alerts.append(("temp_high",
                f"🔥 Température trop élevée : {temperature:.1f}°C (max: {temp_max}°C)"))

        if humidity < hum_min:
            alerts.append(("humidity_low",
                f"💨 Humidité trop basse : {humidity:.1f}% (min: {hum_min}%)"))
        elif humidity > hum_max:
            alerts.append(("humidity_high",
                f"💧 Humidité trop élevée : {humidity:.1f}% (max: {hum_max}%)"))

        if soil_percent < soil_min:
            alerts.append(("soil_low",
                f"🏜️ Sol trop sec : {soil_percent:.1f}% (min: {soil_min}%)"))
        elif soil_percent > soil_max:
            alerts.append(("soil_high",
                f"🌊 Sol trop humide : {soil_percent:.1f}% (max: {soil_max}%)"))

    except Exception as e:
        print(f"❌ Erreur analyse [{serre_id}]: {e}")
    return alerts


# =========================
# ANTI-SPAM
# =========================
def should_send(serre_id: str, message: str) -> bool:
    current_time = time.time()
    state = last_sent[serre_id]
    if (message == state["message"] and
            (current_time - state["time"]) < NOTIFICATION_COOLDOWN):
        remaining = int(NOTIFICATION_COOLDOWN - (current_time - state["time"]))
        print(f"⏳ [{serre_id}] Anti-spam ({remaining}s restantes)")
        return False
    state["message"] = message
    state["time"] = current_time
    return True


def save_last_alert(serre_id: str, alert_type: str, alerts: list):
    """Writes /serres/{id}/last_alert so Flutter can read it as a fallback."""
    try:
        db.reference(f"/serres/{serre_id}/last_alert").set({
            "type":      alert_type,
            "alerts":    [msg for _, msg in alerts],
            "message":   " | ".join(msg for _, msg in alerts),
            "timestamp": int(time.time()),
        })
    except Exception as e:
        print(f"❌ Erreur save_last_alert [{serre_id}]: {e}")


# =========================
# COMMAND LISTENERS (per serre)
# =========================
def make_pump_listener(serre_id):
    def handler(event):
        try:
            if event.data in ["ON", "OFF"]:
                sensor_ref(serre_id).update({"pump": event.data})
                print(f"🔧 [{serre_id}] Pompe → {event.data}")
        except Exception as e:
            print(f"❌ commande pompe [{serre_id}]: {e}")
    return handler

def make_mode_listener(serre_id):
    def handler(event):
        try:
            if event.data in ["AUTO", "MANUEL"]:
                sensor_ref(serre_id).update({"mode": event.data})
                print(f"🔧 [{serre_id}] Mode → {event.data}")
        except Exception as e:
            print(f"❌ commande mode [{serre_id}]: {e}")
    return handler

for serre in SERRES:
    pump_cmd_ref(serre).listen(make_pump_listener(serre))
    mode_cmd_ref(serre).listen(make_mode_listener(serre))
    print(f"👂 Commandes [{serre}] actives")

print("-" * 50)

# =========================
# MAIN LOOP
# =========================
def main_loop():
    cycle = 0
    while True:
        cycle += 1
        print(f"\n📥 Cycle #{cycle} — {time.strftime('%H:%M:%S')}")
        try:
            for serre_id in SERRES:
                sensor_data = sensor_ref(serre_id).get()
                config      = config_ref(serre_id).get()

                if not sensor_data:
                    print(f"⚠️  [{serre_id}] Pas de données")
                    continue

                alerts = analyze_alerts(serre_id, sensor_data, config or {})

                if alerts:
                    # Use the first (most critical) alert type for the data payload
                    primary_type, _ = alerts[0]
                    label = serre_id.replace("_", " ").title()

                    if len(alerts) == 1:
                        title = f"⚠️ Alerte {label}"
                        body  = alerts[0][1]
                    else:
                        title = f"⚠️ {label} — {len(alerts)} alertes"
                        body  = " | ".join(msg for _, msg in alerts)

                    if should_send(serre_id, body):
                        send_push_notification(serre_id, primary_type, title, body)
                        save_last_alert(serre_id, primary_type, alerts)
                else:
                    print(f"✅ [{serre_id}] OK")

        except KeyboardInterrupt:
            print("\n🛑 Backend arrêté manuellement")
            break
        except Exception as e:
            print(f"❌ Erreur cycle: {e}")

        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main_loop()