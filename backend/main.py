import time
import logging
from firebase_client import get_serre_data, save_alert
from history_service import save_history
from anomaly_detector import detect_anomalies
from alert_manager import send_alert

SERRES = ["tomate", "tomate_cerise"]
CHECK_INTERVAL = 180

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("rigoula")

def main():
    
    print("   🌱 RIGOULA SMART FARMING — Backend Supervision")
    

    
    print("\n✅ 1. Connexion à Firebase .............. OK")

    while True:
        print(f"🔄 Cycle de supervision — {time.strftime('%H:%M:%S')}")

        for sid in SERRES:
            print(f"\n🌿 Serre : [{sid.upper()}]")

            print(f"   📡 5. Communication avec les autres composants ...")
            data = get_serre_data(sid)

            if not data:
                print(f"   ⚠️  Pas de données pour [{sid}]")
                continue

            print(f"       Temp={data.get('temperature', '?')}°C | "
                  f"Hum={data.get('humidity', '?')}% | "
                  f"Sol={data.get('soil_percent', '?')}%")

            print(f"   🔍 2. Détection des anomalies ............")
            alerts = detect_anomalies(data, sid)
            if alerts:
                for alert in alerts:
                    print(f"      ⚠️  Anomalie détectée : {alert}")
            else:
                print(f"       ✅ Aucune anomalie détectée")

            print(f"   🔔 3. Gestion des notifications ..........")
            if alerts:
                for alert in alerts:
                    send_alert(sid, alert)
                    save_alert(sid, alert)
                    print(f"       📲 Notification envoyée : {alert}")
            else:
                print(f"       — Aucune notification à envoyer")

            print(f"   📊 4. Gestion de l'historique ............")
            save_history(sid, data)
            print(f"       ✅ Historique mis à jour")

        print(f"\n⏱️  Prochain cycle dans {CHECK_INTERVAL}s ...")
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()