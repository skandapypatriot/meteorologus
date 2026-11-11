#if OFFLINE_MODE

#include "offline_store.h"
#include <FS.h>
#include <time.h>

extern bool get_local_tm(struct tm* out);

static const char *TAG = "offline";

String now_iso() {
  time_t now = time(nullptr);
  if (now <= 1000000) return String("1970-01-01T00:00:00Z");
  char buf[32];
  struct tm tm;
  gmtime_r(&now, &tm);
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &tm);
  return String(buf);
}

static long now_yyyymmdd() {
  struct tm t;
  if (!get_local_tm(&t)) return 0;
  return (long)(t.tm_year + 1900) * 10000L + (long)(t.tm_mon + 1) * 100L + t.tm_mday;
}

static long cutoff_yyyymmdd() {
  long today = now_yyyymmdd();
  if (today == 0) return 0;
  // Subtract 30 days approximately (30 * 1 in yyyymmdd space is not exact
  // across month boundaries, but good enough for TTL pruning).
  long days = today % 100;
  long month = (today / 100) % 100;
  long year = today / 10000;
  days -= OFFLINE_TTL_DAYS;
  while (days < 1) {
    month--;
    if (month < 1) {
      month = 12;
      year--;
    }
    days += 30;
  }
  return year * 10000L + month * 100L + days;
}

bool offline_store_begin() {
  if (!SPIFFS.begin(true)) {
    LOGLN("[offline] SPIFFS mount failed");
    return false;
  }
  offline_store_purge_expired();
  LOGLN("[offline] Store initialized");
  return true;
}

void offline_store_purge_expired() {
  File f = SPIFFS.open(OFFLINE_STORAGE_FILE, "r");
  if (!f) return;

  DynamicJsonDocument doc(16384);
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  if (err) {
    LOGF("[offline] Purge: corrupt store (%s), resetting\n", err.c_str());
    SPIFFS.remove(OFFLINE_STORAGE_FILE);
    return;
  }

  JsonArray arr = doc.as<JsonArray>();
  long cutoff = cutoff_yyyymmdd();
  bool changed = false;

  for (int i = arr.size() - 1; i >= 0; i--) {
    JsonObject obj = arr[i];
    long ts = obj["ts"] | 0;
    if (ts == 0) continue;
    struct tm tm;
    gmtime_r(&ts, &tm);
    long entry_ymd = (long)(tm.tm_year + 1900) * 10000L +
                     (long)(tm.tm_mon + 1) * 100L + tm.tm_mday;
    if (cutoff > 0 && entry_ymd < cutoff) {
      arr.remove(i);
      changed = true;
    }
  }

  if (changed) {
    File w = SPIFFS.open(OFFLINE_STORAGE_FILE, "w");
    if (w) {
      serializeJson(doc, w);
      w.close();
    }
  }
}

int offline_store_count() {
  File f = SPIFFS.open(OFFLINE_STORAGE_FILE, "r");
  if (!f) return 0;
  DynamicJsonDocument doc(16384);
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  if (err) return 0;
  return doc.as<JsonArray>().size();
}

bool offline_store_save(const OfflinePrediction &pred) {
  File f = SPIFFS.open(OFFLINE_STORAGE_FILE, "r");
  DynamicJsonDocument doc(16384);
  JsonArray arr;
  if (f) {
    DeserializationError err = deserializeJson(doc, f);
    f.close();
    if (!err) arr = doc.as<JsonArray>();
  }
  if (!arr) {
    doc = DynamicJsonDocument(16384);
    arr = doc.to<JsonArray>();
  }

  if (arr.size() >= OFFLINE_MAX_ENTRIES) {
    arr.remove(0);
  }

  JsonObject obj = arr.createNestedObject();
  obj["ts"] = pred.ts;
  obj["t"] = pred.t;
  obj["h"] = pred.h;
  obj["p"] = pred.p;
  obj["weather_code"] = pred.weather_code;
  JsonArray fc = obj.createNestedArray("forecast");
  fc.add(pred.forecast[0]);
  fc.add(pred.forecast[1]);
  fc.add(pred.forecast[2]);

  File w = SPIFFS.open(OFFLINE_STORAGE_FILE, "w");
  if (!w) return false;
  bool ok = serializeJson(doc, w) > 0;
  w.close();
  return ok;
}

bool offline_store_latest(OfflinePrediction &out) {
  File f = SPIFFS.open(OFFLINE_STORAGE_FILE, "r");
  if (!f) return false;
  DynamicJsonDocument doc(16384);
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  if (err) return false;
  JsonArray arr = doc.as<JsonArray>();
  if (arr.size() == 0) return false;
  JsonObject obj = arr[arr.size() - 1];
  out.ts = obj["ts"] | 0;
  out.t = obj["t"] | 0.0f;
  out.h = obj["h"] | 0.0f;
  out.p = obj["p"] | 0.0f;
  out.weather_code = obj["weather_code"] | -1;
  JsonArray fc = obj["forecast"];
  out.forecast[0] = fc[0] | -1;
  out.forecast[1] = fc[1] | -1;
  out.forecast[2] = fc[2] | -1;
  return true;
}

int offline_store_read(OfflinePrediction *out, int maxEntries) {
  File f = SPIFFS.open(OFFLINE_STORAGE_FILE, "r");
  if (!f) return 0;
  DynamicJsonDocument doc(16384);
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  if (err) return 0;
  JsonArray arr = doc.as<JsonArray>();
  int n = arr.size();
  if (n > maxEntries) n = maxEntries;
  for (int i = 0; i < n; i++) {
    JsonObject obj = arr[i];
    out[i].ts = obj["ts"] | 0;
    out[i].t = obj["t"] | 0.0f;
    out[i].h = obj["h"] | 0.0f;
    out[i].p = obj["p"] | 0.0f;
    out[i].weather_code = obj["weather_code"] | -1;
    JsonArray fc = obj["forecast"];
    out[i].forecast[0] = fc[0] | -1;
    out[i].forecast[1] = fc[1] | -1;
    out[i].forecast[2] = fc[2] | -1;
  }
  return n;
}

void offline_store_clear() {
  SPIFFS.remove(OFFLINE_STORAGE_FILE);
}

#endif // OFFLINE_MODE
