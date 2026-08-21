# Inference Server — Cloud Weather Prediction Worker

A lightweight Python worker that watches the Firebase Realtime Database for fresh sensor readings, runs scikit-learn weather models against them, and patches the predictions back so devices and the dashboard can display them. It also exposes a tiny HTTP endpoint for health checks and live log streaming (built for [Render](https://render.com)-style hosts).

---

## Table of Contents

- [What It Does](#what-it-does)
- [Requirements](#requirements)
- [Running Locally](#running-locally)
- [Configuration](#configuration)
- [Prediction Pipeline](#prediction-pipeline)
- [Health & Log Endpoint](#health--log-endpoint)
- [Retraining & Exporting Models](#retraining--exporting-models)
- [Deployment (Render)](#deployment-render)
- [Troubleshooting](#troubleshooting)

---

## What It Does

```
every 5 s:
  GET  /devices.json                      → all claimed devices
  for each device with ≥ 4 readings:
    newest node already has a forecast?   → skip
    build features from last 4 readings   → lags + seasonal sin/cos
    run same-day model + 3-day model
    PATCH {weather_code, forecast} into that same node
```

- **Same-day model** (`servermodels/weather_model_same_day.pkl`) → `weather_code` (current conditions).
- **3-day model** (`servermodels/weather_model.pkl`) → `forecast: [D1, D2, D3]`.
- Codes follow the project's WMO-style mapping shared by firmware and website (`≤10 Sunny`, `≤20 Clear`, `≤40 Slightly Cloudy`, `≤60 Cloud`, `≤80 Light Rain`, else `Rain`).
- Idempotent: a node is only processed once — the presence of `forecast` + `weather_code` marks it done.

## Requirements

- Python 3.9+
- The two `.pkl` files in [`servermodels/`](servermodels/) must be loadable by your installed `scikit-learn` version (they are trained artifacts, not code).

```powershell
pip install -r requirements.txt    # numpy, pandas, scikit-learn, requests
```

## Running Locally

```powershell
python main.py
```

You'll see model loading, per-device predictions and any network issues directly in the console.

## Configuration

| Setting | Where | Default |
| :--- | :--- | :--- |
| `PORT` | env var | `10000` — port for the health/log HTTP server |
| Database URL | hardcoded in `main.py` (`BASE_URL`) | `weather-monitor-f4248` RTDB |

> To point at your own Firebase project, change `BASE_URL` in `main.py`.

## Prediction Pipeline

Feature vector built per prediction:

| Feature group | Source |
| :--- | :--- |
| `temperature_2m`, `relative_humidity_2m`, `surface_pressure` | Newest reading |
| `*_lag_1..3` | Previous three readings |
| `sin_season`, `cos_season` | Day-of-year encoded as annual sine/cosine |

The models are wrapped in small predictor classes stored inside the pickles; `main.py` simply calls them with `(history, month, day)` and rounds outputs to integer codes.

## Health & Log Endpoint

A background thread serves everything printed by the worker (both `print()` and `logging`) as plain text:

```
GET http://localhost:10000/     → full in-memory log stream
```

Any response counts as "healthy" for platform health checks.

## Retraining & Exporting Models

1. Train/replace the pickles in `servermodels/` keeping the `{"predict": <predictor>}` pickle format.
2. Regenerate the on-device KNN header:

```powershell
python modeltoc.py        # writes weather_model_same.h from the same-day pickle
```

3. Copy the generated header into [`firmware/models/`](../firmware/models/) and rebuild the firmware so offline predictions stay in sync with the cloud ones.

## Deployment (Render)

- **Build command:** `pip install -r requirements.txt`
- **Start command:** `python main.py`
- The `/` log endpoint satisfies Render's HTTP health check on `$PORT`.
- Free instances sleep when idle; the worker's outbound pings keep some platforms awake, but expect cold starts.

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| `Failed to load models` | Missing/corrupt `.pkl`, or scikit-learn version mismatch — retrain or pin the version used for training |
| `Database connection failed` | Wrong `BASE_URL` or RTDB disabled; rules allow public read of `/devices` |
| Devices never get forecasts | Need ≥ 4 complete nodes `{t,h,p,ts}` under `/devices/<MAC>`; check timestamps are real epochs |
| Predictions look wrong | Verify sensor units (°C, %, hPa) and that the device clock is NTP-synced |
