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

# =========================
# INITIALISATION FIREBASE
# =========================
firebase_key = os.environ.get("FIREBASE_KEY")

cred = credentials.Certificate(json.loads(firebase_key))
initialize_app(cred, {'databaseURL': DATABASE_URL})

print("✅ Backend Python Rigoula démarré")
print(f"📡 Base de données: {DATABASE_URL}")
print(f"🔔 Topic FCM: {TOPIC_NAME}")
print(f"⏱️  Vérification toutes les {CHECK_INTERVAL_SECONDS} secondes")
print("-" * 50)

last_sent_message = None
last_sent_time = 0

# =========================
# RÉFÉRENCES FIREBASE
# =========================
sensor_ref = db.reference("/capteurs/dernier")
config_ref = db.reference("/config")
pump_command_ref = db.reference("/capteurs/commandes/pompe")
mode_command_ref = db.reference("/capteurs/commandes/mode")

# =========================
# NOTIFICATION FCM
# =========================
def send_push_notification(title: str, body: str):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            topic=TOPIC_NAME,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="max",
                    visibility="public",
                ),
            ),
            data={
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "type": "alert",
                "title": title,
                "body": body,
            },
        )
        response = messaging.send(message)
        print(f"📲 Notification FCM envoyée: {response}")
    except Exception as e:
        print(f"❌ Erreur notification FCM: {e}")

# =========================
# LECTURE DONNÉES
# =========================
def get_sensor_data():
    return sensor_ref.get()

def get_config():
    return config_ref.get()

# =========================
# ANALYSE DES ALERTES
# ✅ CORRECTION : "emp_min" → "temp_min" (typo dans Firebase corrigé)
# =========================
def analyze_alerts(sensor_data, config):
    alerts = []
    if not sensor_data or not config:
        if not sensor_data:
            print("⚠️  Aucune donnée capteur reçue de Firebase")
        if not config:
            print("⚠️  Aucune config trouvée dans Firebase /config")
        return alerts

    try:
        temperature = float(sensor_data.get("temperature", 0))
        humidity = float(sensor_data.get("humidity", 0))
        soil_percent = float(sensor_data.get("soil_percent", 0))

        # ✅ CORRECTION : "temp_min" (avant c'était "emp_min" dans Firebase — typo!)
        temp_min = float(config.get("temp_min", 0))
        temp_max = float(config.get("temp_max", 100))
        hum_min = float(config.get("hum_min", 0))
        hum_max = float(config.get("hum_max", 100))
        soil_min = float(config.get("soil_min", 0))
        soil_max = float(config.get("soil_max", 100))

        print(f"  🌡️  Temp: {temperature}°C (seuils: {temp_min}-{temp_max}°C)")
        print(f"  💧  Hum:  {humidity}%   (seuils: {hum_min}-{hum_max}%)")
        print(f"  🌱  Sol:  {soil_percent}%  (seuils: {soil_min}-{soil_max}%)")

        if temperature < temp_min:
            alerts.append(f"🥶 Température trop basse : {temperature:.1f}°C (min: {temp_min}°C)")
        elif temperature > temp_max:
            alerts.append(f"🔥 Température trop élevée : {temperature:.1f}°C (max: {temp_max}°C)")

        if humidity < hum_min:
            alerts.append(f"💨 Humidité trop basse : {humidity:.1f}% (min: {hum_min}%)")
        elif humidity > hum_max:
            alerts.append(f"💧 Humidité trop élevée : {humidity:.1f}% (max: {hum_max}%)")

        if soil_percent < soil_min:
            alerts.append(f"🏜️ Sol trop sec : {soil_percent:.1f}% (min: {soil_min}%)")
        elif soil_percent > soil_max:
            alerts.append(f"🌊 Sol trop humide : {soil_percent:.1f}% (max: {soil_max}%)")

    except Exception as e:
        print(f"❌ Erreur analyse: {e}")

    return alerts

# =========================
# ANTI-SPAM NOTIFICATIONS
# =========================
def should_send_notification(message: str):
    global last_sent_message, last_sent_time
    current_time = time.time()
    if message == last_sent_message and (current_time - last_sent_time) < NOTIFICATION_COOLDOWN:
        remaining = int(NOTIFICATION_COOLDOWN - (current_time - last_sent_time))
        print(f"⏳ Anti-spam: même alerte ignorée ({remaining}s restantes)")
        return False
    last_sent_message = message
    last_sent_time = current_time
    return True

def save_last_alert(alerts):
    try:
        db.reference("/last_alert").set({
            "alerts": alerts,
            "message": " | ".join(alerts),
            "timestamp": int(time.time())
        })
    except Exception as e:
        print(f"❌ Erreur sauvegarde alerte: {e}")

# =========================
# ÉCOUTE COMMANDES FLUTTER
# =========================
def on_pump_command(event):
    try:
        command = event.data
        if command in ["ON", "OFF"]:
            sensor_ref.update({"pump": command})
            print(f"🔧 Pompe → {command} (commande Flutter reçue)")
    except Exception as e:
        print(f"❌ Erreur commande pompe: {e}")

def on_mode_command(event):
    try:
        mode = event.data
        if mode in ["AUTO", "MANUEL"]:
            sensor_ref.update({"mode": mode})
            print(f"🔧 Mode → {mode} (commande Flutter reçue)")
    except Exception as e:
        print(f"❌ Erreur commande mode: {e}")

pump_command_ref.listen(on_pump_command)
mode_command_ref.listen(on_mode_command)
print("👂 Écoute des commandes Flutter active (pompe + mode)")
print("-" * 50)

# =========================
# BOUCLE PRINCIPALE
# =========================
def main_loop():
    cycle = 0
    while True:
        cycle += 1
        try:
            print(f"\n📥 Cycle #{cycle} — {time.strftime('%H:%M:%S')}")

            sensor_data = get_sensor_data()
            config = get_config()

            if not sensor_data:
                print("❌ Pas de données Arduino dans Firebase — l'Arduino est-il connecté?")
                time.sleep(CHECK_INTERVAL_SECONDS)
                continue

            alerts = analyze_alerts(sensor_data, config)

            if alerts:
                if len(alerts) == 1:
                    title = "⚠️ Alerte Rigoula"
                    body = alerts[0]
                else:
                    title = f"⚠️ Alertes Multiples ({len(alerts)})"
                    body = " | ".join(alerts)

                print(f"🚨 {len(alerts)} alerte(s) détectée(s)")
                if should_send_notification(body):
                    send_push_notification(title, body)
                    save_last_alert(alerts)
            else:
                print("✅ Tous les capteurs dans les seuils")

        except KeyboardInterrupt:
            print("\n\n🛑 Backend arrêté manuellement")
            break
        except Exception as e:
            print(f"❌ Erreur cycle principal: {e}")

        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main_loop()