import time
import requests
import pickle
import numpy as np
import pandas as pd
import warnings
import logging
import os
import sys
import threading
from io import StringIO
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from sklearn.exceptions import InconsistentVersionWarning

# --- IN-MEMORY LOG STREAM FOR WEB VIEW ---
log_stream = StringIO()

# --- CUSTOM INTERCEPTOR TO CAPTURE PRINT() STATEMENTS ---
class SystemLogInterceptor:
    def __init__(self, original_stream, storage_stream):
        self.original_stream = original_stream
        self.storage_stream = storage_stream

    def write(self, message):
        self.original_stream.write(message)  # Keeps printing to console
        self.storage_stream.write(message)   # Also duplicates it to the Website View

    def flush(self):
        self.original_stream.flush()
        self.storage_stream.flush()

# Redirect sys.stdout and sys.stderr to capture raw print() statements
sys.stdout = SystemLogInterceptor(sys.__stdout__, log_stream)
sys.stderr = SystemLogInterceptor(sys.__stderr__, log_stream)

# --- SETUP LOGGING ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),            # Outputs to console
        logging.StreamHandler(log_stream)   # Saves logs to memory for the website
    ]
)

# Suppress Version Warnings
warnings.filterwarnings("ignore", category=InconsistentVersionWarning)
warnings.filterwarnings("ignore", category=UserWarning)

# --- CLASS DEFINITIONS ---
class WeatherPredictor:
    def __init__(self, model, scaler, feature_names):
        self.model, self.scaler, self.feature_names = model, scaler, feature_names
    def __call__(self, history, month, day):
        t3, t2, t1, curr = history[0], history[1], history[2], history[3]
        data = {
            "temperature_2m": [curr[0]], "relative_humidity_2m": [curr[1]], "surface_pressure": [curr[2]],
            "sin_season": [np.sin(2 * np.pi * ((month - 1) * 30.5 + day) / 365.25)],
            "cos_season": [np.cos(2 * np.pi * ((month - 1) * 30.5 + day) / 365.25)],
            "temperature_2m_lag_1": [t1[0]], "temperature_2m_lag_2": [t2[0]], "temperature_2m_lag_3": [t3[0]],
            "relative_humidity_2m_lag_1": [t1[1]], "relative_humidity_2m_lag_2": [t2[0]], "relative_humidity_2m_lag_3": [t3[1]],
            "surface_pressure_lag_1": [t1[2]], "surface_pressure_lag_2": [t2[2]], "surface_pressure_lag_3": [t3[2]]
        }
        df = pd.DataFrame(data)
        for col in self.feature_names: df[col] = df.get(col, 0.0)
        df = df[self.feature_names]
        preds = self.model.predict(self.scaler.transform(df))[0]
        return {"D1": preds[0], "D2": preds[1], "D3": preds[2]}

class KNRSameDayPredictor:
    def __init__(self, model, scaler, feature_names):
        self.model, self.scaler, self.feature_names = model, scaler, feature_names
    def __call__(self, history, month, day):
        t3, t2, t1, curr = history[0], history[1], history[2], history[3]
        data = {
            "temperature_2m": [curr[0]], "relative_humidity_2m": [curr[1]], "surface_pressure": [curr[2]],
            "sin_season": [np.sin(2 * np.pi * ((month - 1) * 30.5 + day) / 365.25)],
            "cos_season": [np.cos(2 * np.pi * ((month - 1) * 30.5 + day) / 365.25)],
            "temperature_2m_lag_1": [t1[0]], "temperature_2m_lag_2": [t2[0]], "temperature_2m_lag_3": [t3[0]],
            "relative_humidity_2m_lag_1": [t1[1]], "relative_humidity_2m_lag_2": [t2[0]], "relative_humidity_2m_lag_3": [t3[1]],
            "surface_pressure_lag_1": [t1[2]], "surface_pressure_lag_2": [t2[2]], "surface_pressure_lag_3": [t3[2]]
        }
        df = pd.DataFrame(data)
        for col in self.feature_names: df[col] = df.get(col, 0.0)
        df = df[self.feature_names]
        return {"Same": self.model.predict(self.scaler.transform(df))[0]}

def ping_google():
    """Sends a lightweight HEAD request to Google to maintain network traffic."""
    try:
        # Using HEAD keeps the payload tiny while proving outbound internet works
        res = requests.head("https://www.google.com", timeout=5)
        logging.info(f"Pinged Google successfully. Status code: {res.status_code}")
    except requests.RequestException as e:
        logging.warning(f"Google ping failed (Network issue?): {e}")

# --- WEB SERVER FOR RENDER HEALTH CHECKS & LOG STREAMING ---
class LogServerHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(log_stream.getvalue().encode('utf-8'))

    def log_message(self, format, *args):
        return  # Prevent server request details from polluting the logs

def run_web_server():
    port = int(os.environ.get("PORT", 10000))
    server = HTTPServer(("0.0.0.0", port), LogServerHandler)
    logging.info(f"Log server listening on port {port}...")
    server.serve_forever()

# --- MAIN WORKER ---
def run_worker():
    logging.info("Initializing Worker...")
    try:
        with open("servermodels/weather_model.pkl", "rb") as f: p1 = pickle.load(f)["predict"]
        with open("servermodels/weather_model_same_day.pkl", "rb") as f: p2 = pickle.load(f)["predict"]
        logging.info("Models loaded successfully.")
    except Exception as e:
        logging.error(f"Failed to load models: {e}")
        return

    BASE_URL = "https://weather-monitor-f4248-default-rtdb.asia-southeast1.firebasedatabase.app"

    while True:
        try:
            # Fetch ALL claimed devices (each device stores its own sensor history).
            res = requests.get(f"{BASE_URL}/devices.json", timeout=15)
            if res.status_code != 200:
                logging.warning(f"Database connection failed: {res.status_code}")
                ping_google()
                time.sleep(10)
                continue

            devices = res.json()
            if not devices:
                logging.debug("No devices in DB. Skipping...")
                ping_google()
                time.sleep(30)
                continue

            processed = False

            for device_id, nodes in devices.items():
                if not isinstance(nodes, dict) or len(nodes) < 4:
                    continue

                # Sort this device's nodes by timestamp and inspect the newest one.
                # Nodes may be old-format (with 'device_key') or new-format (plain
                # weather only) - both are handled identically here.
                items = sorted(nodes.items(), key=lambda x: x[1].get('ts', 0))
                latest_key, latest_val = items[-1]

                # Already processed by us.
                if "forecast" in latest_val and "weather_code" in latest_val:
                    continue

                history = []
                try:
                    for _, v in items[-4:]:
                        history.append([v['t'], v['h'], v['p']])
                except (KeyError, TypeError):
                    logging.warning(f"Device {device_id}: malformed node data, skipping")
                    continue
                if len(history) < 4:
                    logging.warning(f"Device {device_id}: fewer than 4 complete nodes, skipping")
                    continue

                dt = datetime.fromtimestamp(latest_val['ts'])

                res_same = p2(history, dt.month, dt.day)
                res_3d = p1(history, dt.month, dt.day)

                payload = {
                    "weather_code": int(round(res_same["Same"])),
                    "forecast": [
                        int(round(res_3d["D1"])),
                        int(round(res_3d["D2"])),
                        int(round(res_3d["D3"]))
                    ]
                }

                logging.info(f"Device {device_id}: predicting node {latest_key}: {payload}")

                # PATCH the forecast into the SAME node under this device.
                patch_res = requests.patch(f"{BASE_URL}/devices/{device_id}/{latest_key}.json", json=payload, timeout=15)
                if patch_res.status_code == 200:
                    logging.info(f"Successfully patched node {latest_key} (device {device_id}).")
                    processed = True
                else:
                    logging.error(f"Patch failed: {patch_res.status_code} - {patch_res.text}")

            if not processed:
                logging.debug("No fresh nodes found. Sending heartbeat packet...")
                ping_google()

        except requests.Timeout as te:
            logging.error(f"Network request timed out: {te}. Retrying connection...")
            ping_google()
        except Exception as e:
            logging.error(f"Unexpected loop error: {e}")

        time.sleep(5)

if __name__ == "__main__":
    # Start the web server thread (health checks + log streaming)
    threading.Thread(target=run_web_server, daemon=True).start()
    run_worker()
