#include <Arduino.h>
#include <Wire.h>
#include <DHT.h>
#include <Adafruit_BMP280.h>
#include <U8g2lib.h>
#include <RTClib.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include <esp_sleep.h>
#include <ArduinoJson.h>
#include "esp_wifi.h"
#include "icons.h"
// Pin Definitions
#define DHTPIN 4
#define DHTTYPE DHT11
#define I2C_SDA 8
#define I2C_SCL 9
#define WAKE_BUTTON_PIN 3

// Timing & Intervals
#define SENSOR_UPDATE 1000 
#define OLED_UPDATE 1000
#define SCREEN_DURATION 5000     // 5 seconds per screen
#define AWAKE_DURATION 20000     // Stay awake for 20s (enough to show all 3 screens) before Deep Sleep
#define WIFI_CONNECT_TIMEOUT 5000
#define WIFI_SSID "test1"
#define WIFI_PASS "1234567890"
#define FIREBASE_URL "https://weather-monitor-f4248-default-rtdb.asia-southeast1.firebasedatabase.app/sensor.json"
#define DEEP_SLEEP_DURATION_US 5400000000ULL  // 1hour

  

int currentScreen = 0;
unsigned long lastButtonPress = 0;
const int debounceDelay = 200; // Prevent flickering
bool is_logo = false;
// Debug control - set to false to disable deep sleep
bool ENABLE_SLEEP = true;
bool sleep_triggered = false;
unsigned long last_firebase_sync = 0;
const unsigned long FIREBASE_SYNC_INTERVAL = 12000; // 12 seconds

// Sensor Instances
DHT dht(DHTPIN, DHTTYPE); 
RTC_DS3231 rtc;
Adafruit_BMP280 bmp;
U8G2_SSD1306_128X64_NONAME_1_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);

// Global vars
unsigned long lastsensorupdate = 0;
unsigned long lastguiupdate = 0;
unsigned long last_screen_switch = 0;

int current_screen = 0;
float humidity = 0;
float temp = 0;
float pressure = 0;

// Forecast & WiFi state
int currentWeatherCode = -1;
int forecastCodes[3] = {-1, -1, -1}; // Indices: 0, 1, 2
bool hasForecast = false;
bool wifi_available = false;
int wifi_bars = 0; // Pre-calculated bars
bool r_state = true;

// WMO Weather Code Mapping
String getWeatherCategory(int code) {
  if (code < 0) return "N/A";
  if ((code >= 0 && code <= 19) || (code >= 30 && code <= 35)) return "Clear";
  if ((code >= 20 && code <= 29) || (code >= 36 && code <= 49) || (code >= 70 && code <= 79)) return "Cloudy";
  if ((code >= 50 && code <= 61) || code == 80) return "Lt Rain";
  if ((code >= 62 && code <= 69) || (code >= 81 && code <= 99)) return "Hvy Rain";
  return "Unknown";
}

void calibrate_rtc(){
  if (WiFi.status() == WL_CONNECTED) {
    configTime(0, 0, "time.nist.gov", "pool.ntp.org", "192.168.137.1");
    struct tm t;
    if (getLocalTime(&t)) {
      rtc.adjust(DateTime(t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec));
      r_state = true;
      Serial.println("[rtc] Time synchronized successfully");
    }
  }
}

void check_wifi_status(){
    if (WiFi.getMode() != WIFI_STA) WiFi.mode(WIFI_STA);
    WiFi.setSleep(WIFI_PS_NONE);
    esp_wifi_set_max_tx_power(WIFI_POWER_8_5dBm);

    if (WiFi.status() != WL_CONNECTED) {
      WiFi.begin(WIFI_SSID, WIFI_PASS);
      unsigned long startAttempt = millis();
      while (WiFi.status() != WL_CONNECTED && (millis() - startAttempt) < WIFI_CONNECT_TIMEOUT) {
        delay(100);
      }
    }

    wifi_available = (WiFi.status() == WL_CONNECTED);
    
    // PRE-CALCULATE WIFI BARS HERE
    if (wifi_available) {
      int rssi = WiFi.RSSI();
      if (rssi >= -55) wifi_bars = 4;
      else if (rssi >= -65) wifi_bars = 3;
      else if (rssi >= -75) wifi_bars = 2;
      else if (rssi >= -85) wifi_bars = 1;
      else wifi_bars = 0;
    } else {
      wifi_bars = 0;
    }
    calibrate_rtc();
}

void print_sensor_data(){
  Serial.println("=========================================");
  if (!isnan(humidity) && !isnan(temp)) {
    Serial.printf("Temp: %.2f °C | Humidity: %.2f %%\n", temp, humidity);
  } else {
    Serial.println("Failed to read from DHT11 sensor!");
  }
  Serial.printf("Pressure: %.2f hPa\n", pressure);
  
  if (hasForecast) {
    Serial.printf("Forecast codes -> Now:%d | Tmrw:%d | Day2:%d | Day3:%d\n",
                  currentWeatherCode, forecastCodes[0], forecastCodes[1], forecastCodes[2]);
  }
  Serial.println("=========================================\n");
}

bool parseFirebaseForecast(const String &payload) {
  DynamicJsonDocument doc(8192);
  DeserializationError error = deserializeJson(doc, payload);
  
  if (error) {
    Serial.printf("[forecast] JSON parse failed: %s\n", error.c_str());
    return false;
  }

  JsonObject root = doc.as<JsonObject>();
  long newest_ts = 0;
  bool found = false;

  for (JsonPair kv : root) {
    JsonObject node = kv.value().as<JsonObject>();
   if (node.containsKey("forecast")) {
      long node_ts = node["ts"] | 0;
      
      if (node_ts > newest_ts) {
        newest_ts = node_ts;
        currentWeatherCode = node["weather_code"] | -1;
        
        // --- FIX: Access as an Array, not an Object ---
        JsonArray forecast = node["forecast"].as<JsonArray>();
        
        // Access by index [0], [1], [2]
        forecastCodes[0] = forecast[0] | -1;
        forecastCodes[1] = forecast[1] | -1;
        forecastCodes[2] = forecast[2] | -1;
        
        found = true;
      }
    }
  }
  
  if (found) {
    // --- NEW SERIAL LOGGING ---
    Serial.println("\n--- NEW FORECAST DATA RECEIVED ---");
    Serial.printf("Source Timestamp: %ld\n", newest_ts);
    Serial.printf("Current: %d (%s)\n", currentWeatherCode, getWeatherCategory(currentWeatherCode).c_str());
    Serial.printf("Day 1: %d (%s)\n", forecastCodes[0], getWeatherCategory(forecastCodes[0]).c_str());
    Serial.printf("Day 2: %d (%s)\n", forecastCodes[1], getWeatherCategory(forecastCodes[1]).c_str());
    Serial.printf("Day 3: %d (%s)\n", forecastCodes[2], getWeatherCategory(forecastCodes[2]).c_str());
    Serial.println("----------------------------------\n");
    
    hasForecast = true;
    return true;
  }
  return false;
}

void fetch_and_sync_firebase() {
  if (!wifi_available) return;
  
  time_t now = time(nullptr);
  if (now > 1000000 && rtc.begin(&Wire)) rtc.adjust(DateTime(now));

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);
  HTTPClient https;
  https.setReuse(false);
  
  // 1. Post New Sensor Data (Creates a new node)
  if (https.begin(client, FIREBASE_URL) && !isnan(temp) && !isnan(humidity) && !isnan(pressure)) {
    https.addHeader("Content-Type", "application/json");
    String json = "{\"t\":" + String(temp, 1) + ",\"h\":" + String((int)humidity) + ",\"p\":" + String(pressure, 2) + ",\"ts\":" + String((long)now) + "}";
    
    int httpCode = https.POST(json); // Changed to POST to append a new node
    Serial.printf("[firebase] Data POST result: %d\n", httpCode);
    https.end();
  }
  
  // 2. Fetch the 10 most recent nodes to search for the delayed forecast
  String fetchUrl = String(FIREBASE_URL) + "?orderBy=\"$key\"&limitToLast=10";
  
  if (https.begin(client, fetchUrl)) {
    int getCode = https.GET();
    if (getCode == 200) {
      parseFirebaseForecast(https.getString());
    } else {
      Serial.printf("[firebase] GET failed: %d\n", getCode);
    }
    https.end();
  }
}
void enterDeepSleep() {
  if (!ENABLE_SLEEP) {
    Serial.println("[sleep] Deep sleep disabled for debugging.");
    return;
  }

  Serial.println("[sleep] Entering Deep Sleep. Goodnight!");
  u8g2.sendF("c", 0xAE); // Turn OLED off
  
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
    if (!r_state) {
      u8g2.drawStr(2, 10, "RTC Error");
    } else {
      DateTime now = DateTime(rtc.now().unixtime() + 19800); 
      char timeBuf[25];
      sprintf(timeBuf, "%02d:%02d:%02d  %02d/%02d", now.hour(), now.minute(), now.second(), now.day(), now.month());
      u8g2.drawStr(2, 10, timeBuf);
    }
    
    u8g2.drawHLine(0, 14, 128);

    if (temp >= 0 && temp <= 108) {
      if (temp >= 0 && temp <= 108) {
      u8g2.setFont(u8g2_font_logisoso22_tr); 
      char tempBuf[10];
      sprintf(tempBuf, "%.1f", temp);
      u8g2.drawStr(5, 48, tempBuf); // Lowered the temp text slightly
      
      int w = u8g2.getStrWidth(tempBuf);
      
      // Draw Degree Symbol (Circle) - Shifted right and higher
      // Adjust 5+w and 30 to fine-tune the position
      u8g2.drawCircle(5 + w + 5, 30, 2); 
      
      // Draw 'C' - Shifted right and higher to match degree symbol
      u8g2.setFont(u8g2_font_profont11_tr);
      u8g2.drawStr(5 + w + 10, 32, "C");
    }
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
      // Draw pre-calculated bars
      for(int i = 0; i < 4; i++) {
        int h = 4 + (i * 3);
        if (i < wifi_bars) u8g2.drawBox(50 + (i * 6), 32 - h, 4, h);
        else u8g2.drawFrame(50 + (i * 6), 32 - h, 4, h);
      }
      u8g2.drawStr(5, 50, "Firebase: Synced");
    } else {
       u8g2.drawStr(10, 35, "Reconnecting...");
    }
}

void draw_screen_three() {
    u8g2.clearBuffer();

    // --- TOP: 3-DAY HORIZONTAL FORECAST ---
    u8g2.setFont(u8g2_font_4x6_tf);
    for(int i = 0; i < 3; i++) {
        // Calculate X position to spread icons evenly (42px wide segments)
        int x_pos = 5 + (i * 42); 
        
        // 1. Icon (Top)
        u8g2.drawXBMP(x_pos + 8, 2, 16, 16, getSmallIcon(forecastCodes[i]));
        
        // 2. Day Label (Bottom of icon)
        char label[5];
        sprintf(label, "D%d", i + 1);
        u8g2.drawStr(x_pos + 8, 24, label);
    }

    // Divider Line
    u8g2.drawHLine(0, 30, 128);

    // --- BOTTOM: TODAY STATUS ---
    // Big Icon
    u8g2.drawXBMP(10, 36, 32, 32, getBigIcon(currentWeatherCode));
    
    // Status Text
    u8g2.setFont(u8g2_font_profont11_tf);
    u8g2.drawStr(50, 50, "Today:");
    u8g2.drawStr(50, 62, getWeatherDescription(currentWeatherCode)); // Or display your weather status here
    
    u8g2.sendBuffer();
}

void update_gui() {
  u8g2.firstPage();
  do {
    if (!is_logo){
      u8g2.drawXBMP(0, 0, 128, 64, start_logo); 
      u8g2.sendBuffer();
      delay(6000);

    }
    else {
      if (current_screen == 0) draw_screen_one();
      else if (current_screen == 1) draw_screen_two();
      else draw_screen_three();
    }

  } while (u8g2.nextPage()); 
}

void setup() {
  Serial.begin(115200);
  
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  if(wakeup_reason == ESP_SLEEP_WAKEUP_GPIO) {
    Serial.println("[boot] Woke up from Deep Sleep by Button Press");
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER) {
    Serial.println("[boot] Woke up from Deep Sleep by Timer");
  } else {
    Serial.println("[boot] Cold Boot");
  }

  pinMode(I2C_SDA, INPUT);
  pinMode(I2C_SCL, INPUT);
  
  Wire.begin(I2C_SDA, I2C_SCL);
  dht.begin();
  
  if (rtc.begin(&Wire)) {
    if (rtc.lostPower()) { r_state = false; }
    else r_state = true;
  } else r_state = false;

  if (bmp.begin(0x76)) {
    bmp.setSampling(Adafruit_BMP280::MODE_NORMAL, Adafruit_BMP280::SAMPLING_X2, Adafruit_BMP280::SAMPLING_X16, Adafruit_BMP280::FILTER_X16, Adafruit_BMP280::STANDBY_MS_500);
  }

  u8g2.begin();
  u8g2.setPowerSave(0);
  u8g2.clearDisplay();          
  u8g2.clearBuffer();
// Parameters: x, y, width, height, bitmap_array
 // Keep logo on screen for 2 seconds

  // Initial read & sync process before UI starts cycling
  check_wifi_status();
  if (wifi_available) {
      configTime(19800, 0, "pool.ntp.org", "time.google.com");
      calibrate_rtc();
  }
  
  // Quick initial sensor read
  humidity = dht.readHumidity();
  temp = bmp.readTemperature();
  pressure = bmp.readPressure() / 100.0F; 
  
  fetch_and_sync_firebase(); // Gets prediction data
  print_sensor_data();       // Logs to terminal
  
  last_screen_switch = millis();
}

void loop() {
  unsigned long now = millis();

  // 1. Read Sensors Periodically
  if (now - lastsensorupdate >= SENSOR_UPDATE){
    humidity = dht.readHumidity();
    temp = bmp.readTemperature();
    pressure = bmp.readPressure() / 100.0F; 
    print_sensor_data();
    lastsensorupdate = now; 
  }

  // 2. Screen Transitions
  if (now - last_screen_switch >= SCREEN_DURATION) {
    current_screen++;
    if (current_screen > 2) current_screen = 0;
    last_screen_switch = now;
  }

  // 3. Update OLED
  if (now - lastguiupdate >= OLED_UPDATE) {
      update_gui();
      lastguiupdate = now;
  }
if (now - last_firebase_sync >= FIREBASE_SYNC_INTERVAL) {
    Serial.println("[system] Running periodic Firebase sync...");
    fetch_and_sync_firebase(); 
    last_firebase_sync = now;
  }
  // 4. Deep Sleep Trigger (Happens after staying awake for AWAKE_DURATION)
if (now > AWAKE_DURATION && !sleep_triggered) {
     sleep_triggered = true; // Set to true so it never enters here again
     enterDeepSleep();
  }
}