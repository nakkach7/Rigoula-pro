from firebase_client import ref

_DEFAULTS = {
    "temp_min":  5.0,
    "temp_max": 40.0,
    "hum_min":  20.0,
    "hum_max":  90.0,
    "soil_min": 20.0,
    "soil_max": 90.0,
}

_config_cache: dict[str, dict] = {}

def _load_config(sid: str) -> dict:
    """Lit /serres/{sid}/config depuis Firebase, avec cache."""
    if sid in _config_cache:
        return _config_cache[sid]
    try:
        raw = ref(f"/serres/{sid}/config").get() or {}
        cfg = {k: float(raw.get(k, _DEFAULTS[k])) for k in _DEFAULTS}
    except Exception:
        cfg = dict(_DEFAULTS)
    _config_cache[sid] = cfg
    return cfg


def invalidate_config_cache(sid: str | None = None):
    """Vider le cache pour forcer une relecture (ex: après mise à jour config)."""
    if sid:
        _config_cache.pop(sid, None)
    else:
        _config_cache.clear()


def detect_anomalies(data: dict, sid: str = "tomate") -> list[str]:
    alerts = []
    cfg = _load_config(sid)

    temp = float(data.get("temperature") or 0)
    hum  = float(data.get("humidity")    or 0)
    soil = float(data.get("soil_percent") or data.get("soilPercent") or 0)

    if temp > cfg["temp_max"]:
        alerts.append(f"temperature elevee {temp}°C")        

    if temp < cfg["temp_min"]:
        alerts.append(f"temperature basse {temp}°C")         
    if hum < cfg["hum_min"]:
        alerts.append(f"humidite basse {hum}%")              

    if hum > cfg["hum_max"]:
        alerts.append(f"humidite elevee {hum}%")            
    if soil < cfg["soil_min"]:
        alerts.append(f"sol tres sec {soil}%")              

    if soil > cfg["soil_max"]:
        alerts.append(f"sol sature {soil}%")                
    return alerts