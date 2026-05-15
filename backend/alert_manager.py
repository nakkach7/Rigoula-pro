import time
from firebase_client import ref
from firebase_admin import messaging

_TYPE_MAP = {
    "temperature elevee": "temp_high",
    "temperature basse":  "temp_low",
    "humidite basse":     "humidity_low",
    "humidite elevee":    "humidity_high",  
    "sol tres sec":       "soil_low",
    "sol sature":         "soil_high",
}


def _infer_type(message: str) -> str:
    """Déduit le type structuré depuis le texte de l'alerte."""
    msg_lower = message.lower()
    for keyword, alert_type in _TYPE_MAP.items():
        if keyword in msg_lower:
            return alert_type
    return "unknown"


def send_alert(serre_id: str, message: str):
    alert_type = _infer_type(message)
    ts = str(int(time.time()))

    msg = messaging.Message(
        notification=messaging.Notification(
            title=f"⚠️ Rigoula — {serre_id.replace('_', ' ').title()}",
            body=message,
        ),
        data={
            "serre":     serre_id,
            "type":      alert_type,
            "message":   message,
            "timestamp": ts,
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="rigoula_alerts",
                priority="high",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default"),
            ),
        ),
        topic="rigoula_alerts",
    )

    try:
        response = messaging.send(msg)
        print(f"[FCM] ✅ Envoyé [{serre_id}] type={alert_type} → {response}")
    except Exception as e:
        print(f"[FCM] ❌ Erreur: {e}")