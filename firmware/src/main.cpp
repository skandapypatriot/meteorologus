#include <Arduino.h>
#include <Wire.h>
#include <DHT.h>
#include <Adafruit_BMP085.h>
#include <Adafruit_BME280.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_AHTX0.h>
#include <U8g2lib.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include <esp_sleep.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include "esp_wifi.h"
#include "esp_bt.h"
#include "icons.h"
#include "models.h"
#include "qrcode.h"

// --- RTC (DS3231) SUPPORT ---
// Optional: set RTC_SUPPORT=0 in platformio.ini to compile it out entirely.
// When enabled, the RTC is used if present (runtime-detected); otherwise the
// ESP32's own NTP/system time is the source of wall-clock time.
#ifndef RTC_SUPPORT
  #define RTC_SUPPORT 1
#endif

#if RTC_SUPPORT
  #include <RTClib.h>
#endif

// --- LOGGING CONTROL ---
// Set to 1 to enable all serial logging, 0 to compile it out entirely.
// Default for IDE indexing; override with -DLOGGING_ENABLED=0 in platformio.ini.
#ifndef LOGGING_ENABLED
  #define LOGGING_ENABLED 1
#endif

#if LOGGING_ENABLED
  #define LOGLN(...)  Serial.println(__VA_ARGS__)
  #define LOGF(...)   Serial.printf(__VA_ARGS__)
#else
  #define LOGLN(...)  ((void)0)
  #define LOGF(...)   ((void)0)
#endif

// Pin Definitions
#define DHTPIN 7
#define DHTTYPE DHT11
#define I2C_SDA 8
#define I2C_SCL 9
#define WAKE_BUTTON_PIN 3

// Timing & Intervals
#define SENSOR_UPDATE 1000 
#define OLED_UPDATE 1000
#define SCREEN_DURATION 5000     // 5 seconds per screen
#define PROVISION_RECHECK_INTERVAL 30000 // poll for a claim every 30s while unpaired
#define AWAKE_DURATION 20000     // Stay awake for 20s (enough to show all 3 screens) before Deep Sleep
#define WIFI_CONNECT_TIMEOUT 5000
#define WIFI_SSID "Samsung Galaxy M47 5G"
#define WIFI_PASS "Sahana27"
#define FIREBASE_BASE_URL "https://weather-monitor-f4248-default-rtdb.asia-southeast1.firebasedatabase.app"
#define CLAIM_WEB_BASE "https://weather-monitor-f4248.web.app/"
#define DEEP_SLEEP_DURATION_US 5400000000ULL  // 1hour
#define POWER_PIN 10
  

int currentScreen = 0;
unsigned long lastButtonPress = 0;
const int debounceDelay = 200; // Prevent flickering
bool is_logo = false;
// Debug control - set to false to disable deep sleep
bool ENABLE_SLEEP = true;
bool sleep_triggered = false;
const unsigned long FIREBASE_SYNC_INTERVAL = 12000; // 12 seconds
SemaphoreHandle_t fb_mutex = NULL;

// Sensor Instances
DHT dht(DHTPIN, DHTTYPE); 
Adafruit_BMP085 bmp;
Adafruit_BME280 bme;
Adafruit_BMP280 bmp280;
Adafruit_AHTX0 aht;
U8G2_SSD1306_128X64_NONAME_1_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);

enum class HumiditySensor { NONE, DHT11, AHT20, BME280 };
enum class PressureSensor { NONE, BMP180, BMP280, BME280 };
HumiditySensor humidity_sensor = HumiditySensor::NONE;
PressureSensor pressure_sensor = PressureSensor::NONE;
uint8_t pressure_sensor_address = 0;

#if RTC_SUPPORT
RTC_DS3231 rtc;
bool r_state = false;   // true = RTC present & running (gives valid time)
#endif

const char* i2c_device_name(uint8_t addr) {
  switch (addr) {
    case 0x68: return "DS3231 RTC";
    case 0x77: return "BMP180";
    case 0x3C: return "SSD1306 OLED";
    default:   return "Unknown";
  }
}

bool i2c_device_ok(uint8_t addr) {
  Wire.beginTransmission(addr);
  return Wire.endTransmission() == 0;
}

// ----------------------------------------------------
// SHARED TIME ACCESS
// Best source of wall-clock epoch: RTC (if supported & valid) else NTP/system.
// TZ offset is IST (+5:30) set by configTime(19800, ...).
// ----------------------------------------------------
time_t get_epoch() {
#if RTC_SUPPORT
  if (r_state) return rtc.now().unixtime();
#endif
  return time(nullptr);
}

bool time_ok() {
  return get_epoch() > 1000000;
}

bool get_local_tm(struct tm* out) {
  time_t e = get_epoch();
  if (e <= 1000000) return false;
  // IST offset applied explicitly at conversion (gmtime_r ignores the TZ env
  // var that configTime sets, so this is deterministic).
  e += 19800;                    // +5:30 IST
  gmtime_r(&e, out);
  return true;
}

// --- NTP sync (sole time source, re-run on every wakeup) ---
static void sync_time() {
  if (WiFi.status() != WL_CONNECTED) return;
  LOGLN("[time] NTP: in.pool.ntp.org, time.google.com, time.cloudflare.com");
  configTime(19800, 0, "in.pool.ntp.org", "time.google.com", "time.cloudflare.com");

  unsigned long start = millis();
  while (millis() - start < 15000) {
    delay(200);
    time_t now = time(nullptr);
    if (now > 1000000) {
      time_t ist = now + 19800;   // log in IST
      struct tm t;
      gmtime_r(&ist, &t);
      LOGF("[time] Synced: %04d-%02d-%02d %02d:%02d:%02d IST (epoch=%lld)\n",
           t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec, (long long)now);
#if RTC_SUPPORT
      if (rtc.begin(&Wire)) {
        rtc.adjust(DateTime(now));
        r_state = true;
        LOGLN("[time] RTC adjusted from NTP");
      }
#endif
      return;
    }
  }
  LOGF("[time] SYNC FAILED - time()=%lld\n", (long long)time(nullptr));
}

// Global vars
unsigned long lastsensorupdate = 0;
unsigned long lastguiupdate = 0;
unsigned long last_screen_switch = 0;
unsigned long last_sync_attempt = 0;
unsigned long last_fb_sync = 0;
unsigned long last_provision_check = 0;
unsigned long boot_done = 0;
bool fb_sync_first = true;
bool gui_dirty = true;   // unpaired: redraw the OLED only when the screen actually changes

int current_screen = 0;
float humidity = 0;
float temp = 0;
float pressure = 0;

// Forecast & WiFi state
int currentWeatherCode = -1;
int forecastCodes[3] = {-1, -1, -1}; // Indices: 0, 1, 2
bool hasForecast = false;
bool wifi_available = false;
int wifi_bars = 0;
bool bmp_present = false;

const char* humidity_sensor_name() {
  switch (humidity_sensor) {
    case HumiditySensor::DHT11: return "DHT11";
    case HumiditySensor::AHT20: return "AHT20";
    case HumiditySensor::BME280: return "BME280";
    default: return "none";
  }
}

const char* pressure_sensor_name() {
  switch (pressure_sensor) {
    case PressureSensor::BMP180: return "BMP180";
    case PressureSensor::BMP280: return "BMP280";
    case PressureSensor::BME280: return "BME280";
    default: return "none";
  }
}

uint8_t read_i2c_register(uint8_t address, uint8_t reg) {
  Wire.beginTransmission(address);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(address, (uint8_t)1) != 1) return 0;
  return Wire.read();
}

void detect_sensors() {
  dht.begin();
  humidity_sensor = HumiditySensor::DHT11;
  pressure_sensor = PressureSensor::NONE;
  pressure_sensor_address = 0;

  if (i2c_device_ok(0x38) && aht.begin(&Wire)) {
    humidity_sensor = HumiditySensor::AHT20;
    LOGLN("[sensor] Detected AHT20");
  }

  for (uint8_t address : {uint8_t(0x76), uint8_t(0x77)}) {
    uint8_t chip_id = read_i2c_register(address, 0xD0);
    if (chip_id == 0x60 && bme.begin(address, &Wire)) {
      humidity_sensor = HumiditySensor::BME280;
      pressure_sensor = PressureSensor::BME280;
      pressure_sensor_address = address;
      LOGLN("[sensor] Detected BME280");
      return;
    }
    if (chip_id == 0x58 && bmp280.begin(address)) {
      pressure_sensor = PressureSensor::BMP280;
      pressure_sensor_address = address;
      LOGLN("[sensor] Detected BMP280");
      return;
    }
  }

  if (i2c_device_ok(0x77) && bmp.begin()) {
    pressure_sensor = PressureSensor::BMP180;
    pressure_sensor_address = 0x77;
    LOGLN("[sensor] Detected BMP180");
  }
  LOGF("[sensor] Active sensors: %s + %s\n", humidity_sensor_name(), pressure_sensor_name());
}

// Local model re-run triggers
float prev_temp = NAN, prev_hum = NAN, prev_pres = NAN;
int stable_count = 0;
bool stable_prediction_done = false;

// Device identity & provisioning state
String device_id = "";      // 12 uppercase hex chars (clean MAC)
String device_key = "";     // cloud token that proves ownership
bool device_claimed = false;

// WMO Weather Code Mapping (official approved standard, shared with icons.h)
String getWeatherCategory(int code) {
  switch (classifyCode(code)) {
    case WC_SUNNY:          return "Sunny";
    case WC_CLEAR:          return "Clear";
    case WC_SLIGHTLY_CLOUDY: return "Slightly Cloudy";
    case WC_CLOUD:          return "Cloud";
    case WC_LIGHT_RAIN:     return "Light Rain";
    case WC_RAIN:           return "Rain";
    default:                return "N/A";
  }
}

uint8_t wifi_disconnect_reason = 0;   // last STA disconnect reason (0 = never)

const char* wifi_reason_str(int r) {
  switch (r) {
    case 1:   return "UNSPECIFIED";
    case 2:   return "AUTH_EXPIRE";
    case 3:   return "AUTH_LEAVE";
    case 15:  return "4WAY_HANDSHAKE_TIMEOUT (wrong password?)";
    case 16:  return "GROUP_KEY_UPDATE_TIMEOUT";
    case 17:  return "IE_IN_4WAY_DIFFERS";
    case 200: return "BEACON_TIMEOUT";
    case 201: return "NO_AP_FOUND (network not visible/out of range)";
    case 202: return "AUTH_FAIL (wrong password)";
    case 203: return "ASSOC_FAIL";
    case 204: return "HANDSHAKE_TIMEOUT";
    case 205: return "CONNECTION_FAIL";
    default:  return "OTHER";
  }
}

void log_wifi_scan() {
  WiFi.disconnect();  // stop the auto-reconnect loop so a scan can run
  delay(500);
  int n = WiFi.scanNetworks(true, true);  // async, include hidden
  if (n < 0) {
    unsigned long t0 = millis();
    while ((n = WiFi.scanComplete()) < 0 && (millis() - t0) < 8000) delay(100);
  }
  LOGF("[wifi] Scan found %d network(s):\n", n);
  if (n < 0) { LOGF("[wifi] Scan failed (%d)\n", n); return; }
  for (int i = 0; i < n && i < 10; i++) {
    LOGF("[wifi]   %-22s RSSI=%d AUTH=%d\n", WiFi.SSID(i).c_str(), WiFi.RSSI(i), WiFi.encryptionType(i));
  }
  WiFi.scanDelete();
}

void check_wifi_status(){
    if (WiFi.getMode() != WIFI_STA) {
      esp_bt_controller_disable();   // BT shares the 2.4GHz radio - keep it off
      WiFi.mode(WIFI_STA);
    }
    WiFi.setSleep(WIFI_PS_NONE);
    // Power safety patch: 19.5dBm max TX spikes current and browns out the
    // C3 during the WPA handshake (causes AUTH_EXPIRE drops). 15dBm is stable.
    esp_wifi_set_max_tx_power(WIFI_POWER_8_5dBm);

    if (WiFi.status() != WL_CONNECTED) {  
      WiFi.disconnect();             // clean start before joining
      delay(100);
      WiFi.begin(WIFI_SSID, WIFI_PASS);
      unsigned long startAttempt = millis();
      while (WiFi.status() != WL_CONNECTED && (millis() - startAttempt) < WIFI_CONNECT_TIMEOUT) {
        delay(100);
      }
    }

    wifi_available = (WiFi.status() == WL_CONNECTED);

    if (wifi_available) {
      LOGLN("[wifi] Connected to " WIFI_SSID);
      int rssi = WiFi.RSSI();
      if (rssi >= -55) wifi_bars = 4;
      else if (rssi >= -65) wifi_bars = 3;
      else if (rssi >= -75) wifi_bars = 2;
      else if (rssi >= -85) wifi_bars = 1;
      else wifi_bars = 0;
    } else {
      wifi_bars = 0;
      LOGF("[wifi] Connect to '" WIFI_SSID "' FAILED - status=%d reason=%d (%s)\n",
           WiFi.status(), wifi_disconnect_reason, wifi_reason_str(wifi_disconnect_reason));
      log_wifi_scan();
    }
}

// ----------------------------------------------------
// DEVICE IDENTITY & PROVISIONING (NVS "auth" namespace)
// ----------------------------------------------------
String get_device_id() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();
  return mac;
}

String get_stored_device_key() {
  Preferences prefs;
  prefs.begin("auth", true);
  String key = prefs.getString("device_key", "");
  prefs.end();
  return key;
}

void save_device_key(const String &key) {
  Preferences prefs;
  prefs.begin("auth", false);
  prefs.putString("device_key", key);
  prefs.end();
  device_key = key;
  device_claimed = true;
}

void clear_device_key() {
  Preferences prefs;
  prefs.begin("auth", false);
  prefs.remove("device_key");
  prefs.end();
  device_key = "";
  device_claimed = false;
}

// One-shot HTTPS check: if someone claimed this device in the web app, fetch
// the token from /claimed_devices/<MAC> and persist it. Unauthenticated by
// design (the security rules allow open reads on claimed_devices).
bool check_remote_provisioning() {
  if (!wifi_available) return false;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(5000);
  HTTPClient https;
  https.setReuse(false);

  String url = String(FIREBASE_BASE_URL) + "/claimed_devices/" + device_id + ".json";
  if (!https.begin(client, url)) return false;

  int code = https.GET();
  bool claimed = false;
  if (code == 200) {
    String payload = https.getString();
    payload.trim();
    if (payload.length() > 2 && payload != "null") {
      DynamicJsonDocument doc(256);
      DeserializationError err = deserializeJson(doc, payload);
      if (!err) {
        const char* key = doc.as<const char*>();
        if (key != nullptr && strlen(key) > 0) {
          save_device_key(String(key));
          LOGF("[provision] Key fetched from cloud, stored (%d chars).\n", strlen(key));
          claimed = true;
        }
      }
    }
  } else {
    LOGF("[provision] Claim check HTTP %d\n", code);
  }
  https.end();
  return claimed;
}

void read_sensors() {
  temp = NAN;
  humidity = NAN;
  pressure = NAN;

  if (humidity_sensor == HumiditySensor::DHT11) {
    temp = dht.readTemperature();
    humidity = dht.readHumidity();
  } else if (humidity_sensor == HumiditySensor::AHT20) {
    sensors_event_t humidity_event, temperature_event;
    aht.getEvent(&humidity_event, &temperature_event);
    temp = temperature_event.temperature;
    humidity = humidity_event.relative_humidity;
  } else if (humidity_sensor == HumiditySensor::BME280) {
    temp = bme.readTemperature();
    humidity = bme.readHumidity();
  }

  if (pressure_sensor == PressureSensor::BMP180) {
    pressure = bmp.readPressure() / 100.0F;
    if (humidity_sensor == HumiditySensor::NONE || humidity_sensor == HumiditySensor::DHT11) {
      temp = bmp.readTemperature();
    }
  } else if (pressure_sensor == PressureSensor::BMP280) {
    pressure = bmp280.readPressure() / 100.0F;
    if (humidity_sensor == HumiditySensor::NONE || humidity_sensor == HumiditySensor::DHT11) {
      temp = bmp280.readTemperature();
    }
  } else if (pressure_sensor == PressureSensor::BME280) {
    pressure = bme.readPressure() / 100.0F;
  }

  bmp_present = pressure_sensor != PressureSensor::NONE;
}

void print_sensor_data(){
  LOGLN("=========================================");
  struct tm t;
  if (get_local_tm(&t)) {
    LOGF("Time: %02d:%02d:%02d  %02d/%02d  (epoch=%lld)\n",
         t.tm_hour, t.tm_min, t.tm_sec, t.tm_mday, t.tm_mon + 1, (long long)get_epoch());
  } else {
    LOGF("Time: NOT SYNCED (epoch=%lld)\n", (long long)get_epoch());
  }
  if (!isnan(humidity)) {
    LOGF("Temp: %.2f °C | Humidity: %.2f %%\n", temp, humidity);
  } else {
    LOGLN("Failed to read from DHT11 sensor!");
  }
  LOGF("Pressure: %.2f hPa\n", pressure);
  
  if (hasForecast) {
    if (xSemaphoreTake(fb_mutex, 100)) {
      LOGF("Forecast codes -> Now:%d | Tmrw:%d | Day2:%d | Day3:%d\n",
                    currentWeatherCode, forecastCodes[0], forecastCodes[1], forecastCodes[2]);
      xSemaphoreGive(fb_mutex);
    }
  }
  LOGLN("=========================================\n");
}

bool parseFirebaseForecast(const String &payload) {
  DynamicJsonDocument doc(8192);
  DeserializationError error = deserializeJson(doc, payload);
  
  if (error) {
    LOGF("[forecast] JSON parse failed: %s\n", error.c_str());
    return false;
  }

  JsonObject root = doc.as<JsonObject>();
  long newest_ts = 0;
  bool found = false;
  int newCurrent = -1;
  int newForecast[3] = {-1, -1, -1};

  for (JsonPair kv : root) {
    JsonObject node = kv.value().as<JsonObject>();
   if (node.containsKey("forecast")) {
      long node_ts = node["ts"] | 0;
      
      if (node_ts > newest_ts) {
        newest_ts = node_ts;
        newCurrent = node["weather_code"] | -1;
        
        JsonArray forecast = node["forecast"].as<JsonArray>();
        
        newForecast[0] = forecast[0] | -1;
        newForecast[1] = forecast[1] | -1;
        newForecast[2] = forecast[2] | -1;
        
        found = true;
      }
    }
  }
  
  if (found) {
    if (xSemaphoreTake(fb_mutex, portMAX_DELAY)) {
      currentWeatherCode = newCurrent;
      forecastCodes[0] = newForecast[0];
      forecastCodes[1] = newForecast[1];
      forecastCodes[2] = newForecast[2];
      hasForecast = true;
      set_forecast_source(FORECAST_FIREBASE);
      xSemaphoreGive(fb_mutex);
    }
    LOGLN("\n--- NEW FORECAST DATA RECEIVED ---");
    LOGF("Source Timestamp: %ld\n", newest_ts);
    LOGF("Current: %d (%s)\n", currentWeatherCode, getWeatherCategory(currentWeatherCode).c_str());
    LOGF("Day 1: %d (%s)\n", forecastCodes[0], getWeatherCategory(forecastCodes[0]).c_str());
    LOGF("Day 2: %d (%s)\n", forecastCodes[1], getWeatherCategory(forecastCodes[1]).c_str());
    LOGF("Day 3: %d (%s)\n", forecastCodes[2], getWeatherCategory(forecastCodes[2]).c_str());
    LOGLN("----------------------------------\n");
    
    return true;
  }
  return false;
}

bool fetch_and_sync_firebase() {
  if (!wifi_available) return false;
  if (!device_claimed) return false; // Unclaimed: no key, skip cloud writes.

  time_t now = time(nullptr);
  bool valid_time = (now > 1000000);
  if (!valid_time) {
    if (WiFi.status() == WL_CONNECTED && (millis() - last_sync_attempt) > 60000) {
      last_sync_attempt = millis();
      sync_time();
    }
    now = time(nullptr);
    valid_time = (now > 1000000);
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  HTTPClient https;
  https.setReuse(false);

  String deviceUrl = String(FIREBASE_BASE_URL) + "/devices/" + device_id + ".json";

  // 1. Post New Sensor Data (Creates a new node under /devices/<MAC>)
  if (https.begin(client, deviceUrl) && valid_time && !isnan(temp) && !isnan(humidity) && !isnan(pressure)) {
    https.addHeader("Content-Type", "application/json");
    String json = "{\"t\":" + String(temp, 1) + ",\"h\":" + String((int)humidity) + ",\"p\":" + String(pressure, 2) +
                  ",\"ts\":" + String((long)now) + "}";

    int httpCode = https.POST(json); // Changed to POST to append a new node
    LOGF("[firebase] Data POST result: %d\n", httpCode);
    if (httpCode == 401 || httpCode == 403) {
      LOGLN("[firebase] Auth rejected (key revoked?), clearing stored key.");
      clear_device_key();
      https.end();
      return false;
    }
    https.end();
  }

  // 2. Fetch the 10 most recent nodes to search for the delayed forecast
  String fetchUrl = deviceUrl + "?orderBy=\"$key\"&limitToLast=10";
  bool gotForecast = false;

  if (https.begin(client, fetchUrl)) {
    int getCode = https.GET();
    if (getCode == 200) {
      gotForecast = parseFirebaseForecast(https.getString());
    } else {
      LOGF("[firebase] GET failed: %d\n", getCode);
    }
    https.end();
  }
  return gotForecast;
}

void enterDeepSleep() {
  if (!ENABLE_SLEEP) {
    LOGLN("[sleep] Deep sleep disabled for debugging.");
    return;
  }

  LOGLN("[sleep] Entering Deep Sleep. Goodnight!");
  u8g2.sendF("c", 0xAE); // Turn OLED off
  digitalWrite(POWER_PIN, 0);
  // Enable wake up from deep sleep using the Boot Button (Pin 0) pulling LOW
pinMode(WAKE_BUTTON_PIN, INPUT_PULLUP);
  esp_deep_sleep_enable_gpio_wakeup(1ULL << WAKE_BUTTON_PIN, ESP_GPIO_WAKEUP_GPIO_LOW);
  
  // Enable wake up via timer
  esp_sleep_enable_timer_wakeup(DEEP_SLEEP_DURATION_US);  
   
  // Go to sleep. ESP32 will completely reset upon waking up.
  esp_deep_sleep_start(); 
}

// ----------------------------------------------------
// UI DRAWING FUNCTIONS 
// ----------------------------------------------------

void draw_screen_one() {
    u8g2.setFont(u8g2_font_profont11_tr); 
#if RTC_SUPPORT
  if (!i2c_device_ok(0x68)) {
      if (r_state) LOGLN("[i2c] ERROR: 0x68 (DS3231 RTC) not responding");
      r_state = false;
      u8g2.drawStr(2, 10, "RTC Error");
  } else {
      if (!r_state) {
        LOGLN("[i2c] 0x68 (DS3231 RTC) responding again, re-enabled.");
        r_state = true;
      }
      struct tm t;
      if (!get_local_tm(&t)) {
        u8g2.drawStr(2, 10, "Time Not Set");
      } else {
        char timeBuf[25];
        sprintf(timeBuf, "%02d:%02d:%02d  %02d/%02d", t.tm_hour, t.tm_min, t.tm_sec, t.tm_mday, t.tm_mon + 1);
        u8g2.drawStr(2, 10, timeBuf);
      }
  }
#else
  struct tm t;
  if (!get_local_tm(&t)) {
    u8g2.drawStr(2, 10, "Time Not Set");
  } else {
    char timeBuf[25];
    sprintf(timeBuf, "%02d:%02d:%02d  %02d/%02d", t.tm_hour, t.tm_min, t.tm_sec, t.tm_mday, t.tm_mon + 1);
    u8g2.drawStr(2, 10, timeBuf);
  }
#endif
    
    u8g2.drawHLine(0, 14, 128);

    if (temp >= 0 || temp <= 108) {
      u8g2.setFont(u8g2_font_logisoso22_tr); 
      char tempBuf[10];
      sprintf(tempBuf, "%.1f", temp);
      u8g2.drawStr(5, 48, tempBuf);
      
      int w = u8g2.getStrWidth(tempBuf);

      u8g2.drawCircle(5 + w + 5, 30, 2); 
      
      u8g2.setFont(u8g2_font_profont11_tr);
      u8g2.drawStr(5 + w + 10, 32, "C");
    
    }

    u8g2.setFont(u8g2_font_profont11_tr);
    if (!isnan(humidity)) {
      char humBuf[15];
      sprintf(humBuf, "H: %.0f %%", humidity);
      u8g2.drawStr(80, 32, humBuf);
    }
    if (!isnan(pressure)) {
      char pressBuf[15];
      sprintf(pressBuf, "P: %.0f ", pressure);
      u8g2.drawStr(80, 48, pressBuf);
    }
    u8g2.drawFrame(0, 16, 128, 48);
}

void draw_screen_two() {
    u8g2.setFont(u8g2_font_profont11_tr);
    char statusBuf[32];
    sprintf(statusBuf, "WiFi: %s", wifi_available ? "Connected" : "Offline");
    u8g2.drawStr(2, 10, statusBuf);
    u8g2.drawHLine(0, 14, 128);

    if (wifi_available) {
      u8g2.drawStr(5, 30, "Signal:");
      for(int i = 0; i < 4; i++) {
        int h = 4 + (i * 3);
        if (i < wifi_bars) u8g2.drawBox(50 + (i * 6), 32 - h, 4, h);
        else u8g2.drawFrame(50 + (i * 6), 32 - h, 4, h);
      }
      const char* fcSrc = (get_forecast_source() == FORECAST_FIREBASE) ? "Forecast: Firebase" : "Forecast: Local AI";
      u8g2.drawStr(5, 50, fcSrc);
    } else {
       u8g2.drawStr(10, 35, "Reconnecting...");
       u8g2.drawStr(10, 50, "Forecast: Local AI");
    }
}

void draw_screen_three() {
    u8g2.clearBuffer();

    int localCurrent = currentWeatherCode;
    int localForecast[3] = {-1, -1, -1};
    if (xSemaphoreTake(fb_mutex, 100)) {
      localCurrent = currentWeatherCode;
      localForecast[0] = forecastCodes[0];
      localForecast[1] = forecastCodes[1];
      localForecast[2] = forecastCodes[2];
      xSemaphoreGive(fb_mutex);
    }

    // --- TOP: 3-DAY HORIZONTAL FORECAST ---
    u8g2.setFont(u8g2_font_4x6_tf);
    for(int i = 0; i < 3; i++) {
        // Calculate X position to spread icons evenly (42px wide segments)
        int x_pos = 5 + (i * 42); 
        
        // 1. Icon (Top)
        u8g2.drawXBMP(x_pos + 8, 2, 16, 16, getSmallIcon(localForecast[i]));
        
        // 2. Day Label (Bottom of icon)
        char label[5];
        sprintf(label, "D%d", i + 1);
        u8g2.drawStr(x_pos + 8, 24, label);
    }

    // Divider Line
    u8g2.drawHLine(0, 30, 128);

    // --- BOTTOM: TODAY STATUS ---
    // Big Icon
    u8g2.drawXBMP(10, 36, 32, 32, getBigIcon(localCurrent));
    
    // Status Text
    u8g2.setFont(u8g2_font_profont11_tf);
    u8g2.drawStr(50, 50, "Today:");
    const char* desc = getWeatherDescription(localCurrent);
    u8g2.setFont(u8g2_font_profont11_tf);
    if (u8g2.getStrWidth(desc) > 78) {  
      u8g2.setFont(u8g2_font_profont10_tf);
    }
    u8g2.drawStr(50, 62, desc);
    
    u8g2.sendBuffer();
}

// "What to do" screen shown while unpaired: alternates with the QR every
// SCREEN_DURATION so the display stays stationary between switches.
void draw_claim_instructions() {
  u8g2.clearDisplay();

  // The full claim link (no protocol, so it fits the 128px width):
  //   weather-monitor-f4248.web.app
  //   /146393B35C14
  String link = String(CLAIM_WEB_BASE) + device_id;
  link.replace("https://", "");
  int slash = link.lastIndexOf('/');
  String host = link.substring(0, slash);
  String path = link.substring(slash);

  u8g2.firstPage();
  do {
    u8g2.setFont(u8g2_font_profont11_tr);
    u8g2.drawStr(8, 13, "Meteorologus");

    if (!wifi_available) {
      u8g2.drawStr(8, 25, "NO INTERNET");
    } else {
      u8g2.drawStr(8, 25, "NOT PAIRED YET");
    }
    u8g2.drawHLine(0, 30, 128);

    u8g2.setFont(u8g2_font_4x6_tf);
    if (!wifi_available) {
      u8g2.drawStr(4, 38, "Not connected to");
      u8g2.drawStr(4, 45, "the internet.");
      u8g2.drawStr(4, 52, "WiFi: " WIFI_SSID);
      u8g2.drawStr(4, 59, "Retrying every 30s");
    } else {
      u8g2.drawStr(4, 38, "Scan QR or open:");
      u8g2.drawStr(4, 45, host.c_str());
      u8g2.drawStr(4, 52, path.c_str());
    }
  } while (u8g2.nextPage());
}

// Full-screen QR for the claim flow. Encodes https://<host>.<tld>/<MAC> so a
// phone opens the claim page with the device id pre-filled. Version 3 (29x29)
// fits the 50-char URL at ECC_LOW; rendered 2x => 58x58 px on the 128x64 OLED.
void draw_claiming_qr() {
  u8g2.clearDisplay();   // hardware-clear the panel first (kills logo ghosting)

  String url = String(CLAIM_WEB_BASE) + device_id;

  QRCode qrcode;
  uint8_t qrcodeBytes[((29 * 29) + 7) / 8]; // qrcode_getBufferSize(3) == 106 bytes
  if (qrcode_initText(&qrcode, qrcodeBytes, 3, ECC_LOW, url.c_str()) < 0) {
    u8g2.firstPage();
    do {
      u8g2.setFont(u8g2_font_profont11_tr);
      u8g2.drawStr(2, 10, "QR Error");
      u8g2.drawStr(2, 25, url.c_str());
    } while (u8g2.nextPage());
    return;
  }

  const int scale = 2;
  const int qrPx = qrcode.size * scale;
  const int x0 = (128 - qrPx) / 2;
  const int y0 = (64 - qrPx) / 2;

  // Page-buffer display (128x8 per page): must walk all 8 pages via
  // firstPage()/nextPage(), otherwise only the top 8 rows would render.
  u8g2.firstPage();
  do {
    for (int y = 0; y < qrcode.size; y++) {
      for (int x = 0; x < qrcode.size; x++) {
        if (qrcode_getModule(&qrcode, x, y)) {
          u8g2.drawBox(x0 + x * scale, y0 + y * scale, scale, scale);
        }
      }
    }
  } while (u8g2.nextPage());
}

void update_gui() {
  if (!device_claimed) {
    // Unpaired: alternate the instructions screen and the claim QR.
    if (current_screen == 0) draw_claim_instructions();
    else draw_claiming_qr();
    return;
  }

  u8g2.firstPage();
  do {

      if (current_screen == 0) draw_screen_one();
      else if (current_screen == 1) draw_screen_two();
      else draw_screen_three();

  } while (u8g2.nextPage()); 
}

void setup() {
  Serial.begin(115200);
  
  pinMode(POWER_PIN, OUTPUT);
  digitalWrite(POWER_PIN, HIGH); 
  
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  if(wakeup_reason == ESP_SLEEP_WAKEUP_GPIO) {
    LOGLN("[boot] Woke up from Deep Sleep by Button Press");
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER) {
    LOGLN("[boot] Woke up from Deep Sleep by Timer");
  } else {
    LOGLN("[boot] Cold Boot");
  }
  delay(100);
  pinMode(I2C_SDA, INPUT);
  pinMode(I2C_SCL, INPUT);

  // Capture WiFi disconnect reasons for diagnostics.
  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
    if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
      wifi_disconnect_reason = info.wifi_sta_disconnected.reason;
    }
  });

  Wire.begin(I2C_SDA, I2C_SCL);
  
#if RTC_SUPPORT
  // RTC is OPTIONAL: if no DS3231 on the bus we still run off NTP/system time.
  if (i2c_device_ok(0x68) && rtc.begin(&Wire)) {
    if (rtc.lostPower()) {
      r_state = false;
      LOGLN("[rtc] DS3231 present but lost power (no valid time)");
    } else {
      r_state = true;
      LOGLN("[rtc] DS3231 found, using RTC time");
    }
  } else {
    r_state = false;
    LOGLN("[rtc] DS3231 (0x68) not found - using NTP/system time");
  }
#endif

  detect_sensors();

  u8g2.begin();
  u8g2.setPowerSave(0);
  u8g2.clearDisplay();          

  for (uint8_t addr : {0x68, 0x77, 0x3C}) {
    if (i2c_device_ok(addr)) {
      LOGF("[i2c] Scan: 0x%02X (%s) OK\n", addr, i2c_device_name(addr));
    } else {
      LOGF("[i2c] Scan: 0x%02X (%s) NOT RESPONDING\n", addr, i2c_device_name(addr));
    }
  }
  u8g2.clearBuffer();

do {
      const int logoX = (128 - 64) / 2;
      const int logoY = 0;
      u8g2.drawXBMP(logoX, logoY, 64, 64, start_logo);

      u8g2.setFont(u8g2_font_profont11_tr);
      const char* title = "Meteorologus";
      int titleWidth = u8g2.getStrWidth(title);
      int titleX = (128 - titleWidth) / 2;
      u8g2.drawStr(titleX, 64, title);
  } while (u8g2.nextPage());
  
  delay(1500); 
  // Initial read & sync process before UI starts cycling
  check_wifi_status();
  sync_time(); // NTP is the only time source; re-synced on every wakeup

  // Device identity: clean MAC, then check NVS for a stored claim token.
  device_id = get_device_id();
  LOGF("[provision] Device ID (MAC): %s\n", device_id.c_str());

  device_key = get_stored_device_key();
  device_claimed = (device_key.length() > 0);
  if (device_claimed) {
    LOGLN("[provision] Stored claim key present, device is claimed.");
  } else {
    LOGLN("[provision] No stored key - checking cloud for a claim...");
    check_remote_provisioning();
    if (!device_claimed) LOGLN("[provision] Not claimed yet - showing QR code.");
  }
  last_provision_check = millis();
  
  // Quick initial sensor read (skipped while unpaired - provisioning mode)
  if (device_claimed) read_sensors();

  fb_mutex = xSemaphoreCreateMutex();
  if (device_claimed) {
    // Run local model inference as the baseline; a fresh Firebase forecast overrides it.
    run_local_prediction();
    if (fb_mutex != NULL) {
      // Blocking initial sync. If no forecast came back (first TLS call often
      // needs a retry), the very first loop() iteration will try again before
      // any screen is drawn, so the WiFi screen shows "Forecast: Firebase".
      fb_sync_first = !fetch_and_sync_firebase();
    }
    last_fb_sync = millis();
    print_sensor_data();       // Logs to terminal
  } else {
    fb_sync_first = false;     // nothing to sync until the device is claimed
  }
  
  last_screen_switch = millis();
  boot_done = millis();      // awake clock starts AFTER setup completes
}

void loop() {
  unsigned long now = millis();

  // 1. Read Sensors Periodically (skipped entirely while unpaired)
  if (now - lastsensorupdate >= SENSOR_UPDATE){
    lastsensorupdate = now;

    if (device_claimed) {
      read_sensors();
      print_sensor_data();

      // Run local model once the readings settle (data no longer changing)
      if (!stable_prediction_done) {
        if (!isnan(temp) && !isnan(humidity) && !isnan(pressure) && !isnan(prev_temp) &&
            fabs(temp - prev_temp) < 0.3F &&
            fabs(humidity - prev_hum) < 1.0F &&
            fabs(pressure - prev_pres) < 0.5F) {
          stable_count++;
          if (stable_count >= 3) {
            stable_prediction_done = true;
            run_local_prediction();
          }
        } else {
          stable_count = 0;
        }
      }
      prev_temp = temp;
      prev_hum = humidity;
      prev_pres = pressure;
    }
  }

  // 2. Screen Transitions
  if (now - last_screen_switch >= SCREEN_DURATION) {  
    if (!device_claimed) {
      current_screen = (current_screen == 0) ? 1 : 0; // instructions <-> QR
    } else {
      current_screen++;
      if (current_screen > 2) current_screen = 0;
      // Re-run local model whenever the forecast/prediction screen is shown
      if (current_screen == 2) {
        run_local_prediction();
      }
    }
    last_screen_switch = now;
    gui_dirty = true;
  }

  // 3. Update OLED - while unpaired the display is stationary and only
  //    redrawn when the screen switches; paired screens refresh every second.
  if (gui_dirty || (device_claimed && now - lastguiupdate >= OLED_UPDATE)) {
      update_gui();
      lastguiupdate = now;
      gui_dirty = false;
  }

  // 4. Firebase Sync (blocking, delay-scheduled)
  if (fb_sync_first || now - last_fb_sync >= FIREBASE_SYNC_INTERVAL) {
      fb_sync_first = false;
      fetch_and_sync_firebase();  
      last_fb_sync = millis();
  }

  // 5. While unpaired: stay awake, keep retrying WiFi, and poll the cloud for
  //    a claim so a fresh claim is picked up without a reboot.
  if (!device_claimed && (now - last_provision_check >= PROVISION_RECHECK_INTERVAL)) {
      last_provision_check = now;
      if (!wifi_available) {
        check_wifi_status();   // keep trying to join the network
        if (wifi_available) {
          LOGLN("[wifi] Connected - syncing time.");
          sync_time();
          gui_dirty = true;    // refresh the info screen status
        }
      }
      if (wifi_available) {
        if (check_remote_provisioning()) {
          LOGLN("[provision] Claimed while awake - resuming normal operation.");
          fb_sync_first = true;      // sync on the next loop pass
          sleep_triggered = false;
          gui_dirty = true;          // redraw normal screens immediately
          lastguiupdate = 0;
          boot_done = millis();      // restart the 20s awake window before sleeping
        }
      }
  }

  // 6. Deep Sleep Trigger (Happens after staying awake for AWAKE_DURATION)
  //    Only when paired - an unclaimed node stays awake showing the QR code.
  if (now - boot_done > AWAKE_DURATION && !sleep_triggered && device_claimed) {
     sleep_triggered = true; // Set to true so it never enters here again
     enterDeepSleep();
  }
}

