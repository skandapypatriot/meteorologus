#include "models.h"
#include <Arduino.h>
#include <math.h>
#include <Preferences.h>
#include <time.h>
#include "weather_model_same.h"
#include "weather_model_3d.h"
#include "scalers.h"

#if defined(LOGGING_ENABLED) && LOGGING_ENABLED
  #define MLOG(...) Serial.printf(__VA_ARGS__)
#else
  #define MLOG(...) ((void)0)
#endif

// Shared state & time helpers owned by src/main.cpp
extern float temp;
extern float humidity;
extern float pressure;
extern bool hasForecast;
extern int currentWeatherCode;
extern int forecastCodes[3];
extern SemaphoreHandle_t fb_mutex;
extern bool time_ok();
extern bool get_local_tm(struct tm* out);

struct Reading { float t; float h; float p; };
static Reading history[3];            // [0]=lag1 (yesterday) [1]=lag2 [2]=lag3
static bool history_valid = false;
static long last_date = 0;            // yyyymmdd
static ForecastSource g_source = FORECAST_LOCAL;

ForecastSource get_forecast_source() { return g_source; }
void set_forecast_source(ForecastSource s) { g_source = s; }

static float valid_num(float v, float fallback) {
  return isnan(v) ? fallback : v;
}

static long today_yyyymmdd() {
  struct tm t;
  if (!get_local_tm(&t)) return 0;
  return (long)(t.tm_year + 1900) * 10000L + (long)(t.tm_mon + 1) * 100L + t.tm_mday;
}

static void push_history(float t, float h, float p) {
  history[2] = history[1];
  history[1] = history[0];
  history[0] = { t, h, p };
}

static void load_history() {
  Preferences prefs;
  prefs.begin("wmodel", true);
  last_date = prefs.getLong("last_date", 0);
  history[0].t = prefs.getFloat("t1", NAN);
  history[0].h = prefs.getFloat("h1", NAN);
  history[0].p = prefs.getFloat("p1", NAN);
  history[1].t = prefs.getFloat("t2", NAN);
  history[1].h = prefs.getFloat("h2", NAN);
  history[1].p = prefs.getFloat("p2", NAN);
  history[2].t = prefs.getFloat("t3", NAN);
  history[2].h = prefs.getFloat("h3", NAN);
  history[2].p = prefs.getFloat("p3", NAN);
  prefs.end();
  history_valid = !isnan(history[0].t) && !isnan(history[0].h) && !isnan(history[0].p) &&
                  !isnan(history[1].t) && !isnan(history[1].h) && !isnan(history[1].p) &&
                  !isnan(history[2].t) && !isnan(history[2].h) && !isnan(history[2].p);
}

static void save_history() {
  Preferences prefs;
  prefs.begin("wmodel", false);
  prefs.putLong("last_date", last_date);
  prefs.putFloat("t1", history[0].t);
  prefs.putFloat("h1", history[0].h);
  prefs.putFloat("p1", history[0].p);
  prefs.putFloat("t2", history[1].t);
  prefs.putFloat("h2", history[1].h);
  prefs.putFloat("p2", history[1].p);
  prefs.putFloat("t3", history[2].t);
  prefs.putFloat("h3", history[2].h);
  prefs.putFloat("p3", history[2].p);
  prefs.end();
}

static void build_raw(double* f) {
  int month = 1, day = 1;
  struct tm t;
  if (get_local_tm(&t)) {
    month = t.tm_mon + 1;
    day = t.tm_mday;
  }
  double doy = (month - 1) * 30.5 + day;

  f[0] = 0.0;                                    // 'Unnamed: 0' index col (cloud fills 0.0)
  f[1] = valid_num(temp, history[0].t);
  f[2] = valid_num(humidity, history[0].h);
  f[3] = valid_num(pressure, history[0].p);
  f[4] = sin(2.0 * M_PI * doy / 365.25);
  f[5] = cos(2.0 * M_PI * doy / 365.25);
  f[6]  = history[0].t; f[7]  = history[1].t; f[8]  = history[2].t; // temp lags 1-3
  f[9]  = history[0].h; f[10] = history[1].h; f[11] = history[2].h; // hum  lags 1-3
  f[12] = history[0].p; f[13] = history[1].p; f[14] = history[2].p; // pres lags 1-3
}

static void scale_features(const double* raw, const double* mean, const double* scale, double* out) {
  for (int i = 0; i < 15; i++) {
    out[i] = (raw[i] - mean[i]) / scale[i];
  }
}

static int code_from_scaled(double v) {
  return (int)round(v);
}

void run_local_prediction() {
  MLOG("[model] Running local inference...\n");

  load_history();

  long today = time_ok() ? today_yyyymmdd() : 0;

  if (!history_valid) {
    Reading cur = { valid_num(temp, 18.9F), valid_num(humidity, 90.3F), valid_num(pressure, 909.3F) };
    history[0] = cur;
    history[1] = cur;
    history[2] = cur;
    history_valid = true;
    MLOG("[model] Cold start: history padded with current readings\n");
  } else if (today > 0 && last_date > 0 && today != last_date) {
    Reading cur = { valid_num(temp, history[0].t), valid_num(humidity, history[0].h), valid_num(pressure, history[0].p) };
    push_history(cur.t, cur.h, cur.p);
    MLOG("[model] New day detected, history shifted\n");
  }
  if (today > 0) last_date = today;

  double raw[15], knn_scaled[15], rid_scaled[15];
  build_raw(raw);
  scale_features(raw, SCALER_KNN_MEAN, SCALER_KNN_SCALE, knn_scaled);
  scale_features(raw, SCALER_3D_MEAN, SCALER_3D_SCALE, rid_scaled);

  int cur = (int)round(score_same_day(knn_scaled));
  int fc[3];
  fc[0] = code_from_scaled(score_target_1(rid_scaled));
  fc[1] = code_from_scaled(score_target_2(rid_scaled));
  fc[2] = code_from_scaled(score_target_3(rid_scaled));

  if (fb_mutex) xSemaphoreTake(fb_mutex, portMAX_DELAY);
  if (g_source == FORECAST_FIREBASE) {
    // A Firebase forecast is authoritative: never let the local model override it.
    xSemaphoreGive(fb_mutex);
    MLOG("[model] Firebase forecast active, keeping it (local -> Now:%d | D1:%d | D2:%d | D3:%d)\n",
         cur, fc[0], fc[1], fc[2]);
  } else {
    currentWeatherCode = cur;
    forecastCodes[0] = fc[0];
    forecastCodes[1] = fc[1];
    forecastCodes[2] = fc[2];
    hasForecast = true;
    g_source = FORECAST_LOCAL;
    xSemaphoreGive(fb_mutex);
    MLOG("[model] Local -> Now:%d | D1:%d | D2:%d | D3:%d\n", cur, fc[0], fc[1], fc[2]);
  }

  save_history();
}
