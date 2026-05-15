from firebase_admin import credentials, initialize_app, db
import time

cred = credentials.Certificate("serviceAccountKey.json")
initialize_app(cred, {
    "databaseURL": "https://rigoula-smart-default-rtdb.firebaseio.com"
})

def ref(path):
    return db.reference(path)

def get_serre_data(sid):
    return ref(f"/serres/{sid}/capteurs").get()

def save_alert(sid, alert):
    ref(f"/serres/{sid}/last_alert").set({
        "message": alert,
        "timestamp": int(time.time())
    })