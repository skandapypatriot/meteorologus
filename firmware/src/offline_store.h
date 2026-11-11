#ifndef OFFLINE_STORE_H
#define OFFLINE_STORE_H

#include <Arduino.h>

#if OFFLINE_MODE
#include <SPIFFS.h>
#include <ArduinoJson.h>

// Returns an ISO-8601 timestamp string for the current time.
String now_iso();

struct OfflinePrediction {
  long ts;
  float t;
  float h;
  float p;
  int weather_code;
  int forecast[3];
};

#define OFFLINE_TTL_DAYS 30
#define OFFLINE_MAX_ENTRIES 720
#define OFFLINE_STORAGE_FILE "/predictions.json"

// Returns number of entries currently stored.
int offline_store_count();

// Appends a prediction to flash storage. Returns true on success.
bool offline_store_save(const OfflinePrediction &pred);

// Returns the latest prediction, or null if none stored.
bool offline_store_latest(OfflinePrediction &out);

// Fills out with up to maxEntries most recent predictions (newest first).
// Returns number copied.
int offline_store_read(OfflinePrediction *out, int maxEntries);

// Purge entries older than OFFLINE_TTL_DAYS. Call on boot.
void offline_store_purge_expired();

// Clear all stored predictions.
void offline_store_clear();

// Initialize SPIFFS and run purge. Returns true on success.
bool offline_store_begin();
#endif

#endif // OFFLINE_STORE_H
