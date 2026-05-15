import datetime
from firebase_client import ref


def save_history(sid: str, data: dict):
    today = datetime.date.today().isoformat()
    path = f"/serres/{sid}/historique/{today}"

    current = ref(path).get()

    temp     = float(data.get("temperature") or 0)
    hum      = float(data.get("humidity") or 0)
    soil     = float(data.get("soil_percent") or data.get("soilPercent") or 0)
    pump_raw = data.get("pump", "OFF")
    pump_on  = (pump_raw == "ON") if isinstance(pump_raw, str) else bool(pump_raw)
    ev_raw   = data.get("ev", "CLOSED")
    ev_open  = (ev_raw in ("ON", "OPEN")) if isinstance(ev_raw, str) else bool(ev_raw)

    if temp == 0 and hum == 0 and soil == 0:
        return

    if not current:
        new_data = {
            "temp_min":      temp,
            "temp_max":      temp,
            "hum_min":       hum,
            "hum_max":       hum,
            "soil_min":      soil,
            "soil_max":      soil,
            "pump_count":    1 if pump_on else 0,
            "pump_duration": 0,
            "ev_count":      1 if ev_open else 0,   # ← même nom que Flutter
            "ev_duration":   0,
            "_pump_was_on":  pump_on,
            "_ev_was_open":  ev_open,
        }
    else:
        def safe_min(key, val):
            existing = current.get(key)
            if existing is None:
                return val
            return min(float(existing), val)

        def safe_max(key, val):
            existing = current.get(key)
            if existing is None:
                return val
            return max(float(existing), val)

        prev_pump_on  = bool(current.get("_pump_was_on", False))
        prev_ev_open  = bool(current.get("_ev_was_open", False))

        new_data = {
            "temp_min": safe_min("temp_min", temp),
            "temp_max": safe_max("temp_max", temp),
            "hum_min":  safe_min("hum_min",  hum),
            "hum_max":  safe_max("hum_max",  hum),
            "soil_min": safe_min("soil_min", soil),
            "soil_max": safe_max("soil_max", soil),

            "pump_count": _increment_on_rising(
                int(current.get("pump_count", 0)),
                prev_pump_on,
                pump_on,
            ),
            "pump_duration": int(current.get("pump_duration", 0)),

            "ev_count": _increment_on_rising(    
                int(current.get("ev_count", 0)
                    or current.get("ev_open_count", 0)),  
                prev_ev_open,
                ev_open,
            ),
            "ev_duration": int(current.get("ev_duration", 0)),
            "_pump_was_on": pump_on,
            "_ev_was_open": ev_open,
        }

    ref(path).set(new_data)


def _increment_on_rising(current_count: int, was_active: bool, is_active: bool) -> int:
    if is_active and not was_active:
        return current_count + 1
    return current_count