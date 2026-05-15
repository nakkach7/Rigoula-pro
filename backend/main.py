import time
import logging
from firebase_client import get_serre_data, save_alert
from history_service import save_history
from anomaly_detector import detect_anomalies
from alert_manager import send_alert

SERRES = ["tomate", "tomate_cerise"]
CHECK_INTERVAL = 10

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("rigoula")

def main():
    log.info("Backend supervision démarré")

    while True:
        for sid in SERRES:
            data = get_serre_data(sid)

            if not data:
                log.warning(f"[{sid}] Pas de données")
                continue

            alerts = detect_anomalies(data, sid)

            for alert in alerts:
                send_alert(sid, alert)
                save_alert(sid, alert)

            save_history(sid, data)
            log.info(f"[{sid}] OK")

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()