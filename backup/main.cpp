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
#include "esp_wifi.h"
#include "esp_bt.h"

// Pin Definitions
#define DHTPIN 4
#define DHTTYPE DHT11
#define I2C_SDA 8
#define I2C_SCL 9
#define SENSOR_UPDATE 250
#define OLED_UPDATE 1000 
#define TIME_OUT 10000
#define WIFI_C_INTERVAL 10000 
#define WIFI_CONNECT_TIMEOUT 15000
#define SCREEN1_DURATION 7000
#define SCREEN2_DURATION 3000
#define WIFI_SSID "test1"
#define WIFI_PASS "1234567890"
#define FIREBASE_URL "https://weather-monitor-f4248-default-rtdb.asia-southeast1.firebasedatabase.app/sensor.json"
#define FIREBASE_SYNC_INTERVAL 12000
// Sensor Instances
DHT dht(DHTPIN, DHTTYPE); 
RTC_DS3231 rtc;
Adafruit_BMP280 bmp;
U8G2_SSD1306_128X64_NONAME_1_HW_I2C u8g2(U8G2_R0,U8X8_PIN_NONE);

// Global vars
bool bmp_began;
unsigned long lastsensorupdate = 0;
unsigned long lastguiupdate = 0;
unsigned long lastwifiupdate = 0;
unsigned long lastFirebaseSync = 0;
unsigned long last_screen_switch = 0;
int on_time = millis();
int current_screen = 0;
float humidity;
float temp;
float pressure;
bool wifi_available;
bool r_state = true;
bool rtc_calibrated = false;
void calibrate_rtc();
const char* wifi_status_to_string(wl_status_t status) {
  switch (status) {
    case WL_IDLE_STATUS: return "WL_IDLE_STATUS";
    case WL_NO_SSID_AVAIL: return "WL_NO_SSID_AVAIL";
    case WL_SCAN_COMPLETED: return "WL_SCAN_COMPLETED";
    case WL_CONNECTED: return "WL_CONNECTED";
    case WL_CONNECT_FAILED: return "WL_CONNECT_FAILED";
    case WL_CONNECTION_LOST: return "WL_CONNECTION_LOST";
    case WL_DISCONNECTED: return "WL_DISCONNECTED";
    default: return "UNKNOWN";
  }
}

void check_wifi_status(){
    if (WiFi.getMode() != WIFI_STA) {
      WiFi.mode(WIFI_STA);
    }

    WiFi.setSleep(WIFI_PS_NONE);
    esp_wifi_set_max_tx_power(WIFI_POWER_8_5dBm);

    if (WiFi.status() != WL_CONNECTED) {
      int n = WiFi.scanNetworks();
      Serial.printf("[wifi] Scan found %d networks\n", n);
      for (int i = 0; i < n; ++i) {
        Serial.printf("[wifi]   %s\n", WiFi.SSID(i).c_str());
      }

      WiFi.disconnect(true);
      delay(100);
      WiFi.begin(WIFI_SSID, WIFI_PASS);

      unsigned long startAttempt = millis();
      while (WiFi.status() != WL_CONNECTED && (millis() - startAttempt) < WIFI_CONNECT_TIMEOUT) {
        delay(200);
      }
    }

    wl_status_t status = WiFi.status();
    wifi_available = (status == WL_CONNECTED);

    if (wifi_available) {
      calibrate_rtc();
      Serial.printf("[wifi] Connected, IP: %s, RSSI: %d dBm\n",
                    WiFi.localIP().toString().c_str(), WiFi.RSSI());
    } else {
      Serial.printf("[wifi] Disconnected or unavailable (status: %s)\n",
                    wifi_status_to_string(status));
    }
}

void print_sensor_data(){

  Serial.println("=========================================");
  
  if (!isnan(humidity) || !isnan(temp)) {
    Serial.printf("DHT11 temperature: %.2f °C\n", temp);
    Serial.printf("DHT11 humidity:    %.2f %%\n", humidity);
  } else {
    Serial.println("Failed to read from DHT11 sensor!");
  }

  Serial.printf("BMP280 temperature: %.2f °C\n", temp);
  Serial.printf("BMP280 pressure:    %.2f hPa\n", pressure);
  Serial.println("=========================================\n");
}

bool sync_time_from_ntp() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  configTime(19800, 0, "pool.ntp.org", "time.google.com", "10.189.133.225");
  unsigned long start = millis();
  while (millis() - start < 10000 && time(nullptr) < 1000000) {
    delay(200);
  }

  return time(nullptr) > 1000000;
}

void send_firebase_data() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Firebase] No WiFi connection");
    return;
  }

  if (!sync_time_from_ntp()) {
    Serial.println("[Firebase] Time not synced yet");
    return;
  }

  time_t now = time(nullptr);
  if (now < 1000000) {
    Serial.println("[Firebase] Invalid time value");
    return;
  }

  if (rtc.begin(&Wire)) {
    rtc.adjust(DateTime(now));
  }

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(10000);

  HTTPClient https;
  https.setReuse(false);

  Serial.println("[Firebase] Connecting to RTDB...");
  if (https.begin(client, FIREBASE_URL)) {
    https.addHeader("Content-Type", "application/json");
    https.addHeader("Connection", "close");

    String json = "{\"t\":" + String(temp, 1) + ",\"h\":" + String((int)humidity) + ",\"p\":" + String(pressure, 2) + ",\"ts\":" + String((long)now) + "}";
    Serial.print("[Firebase] Sending: ");
    Serial.println(json);

    int code = https.POST(json);

    if (code > 0) {
      Serial.printf("[Firebase] Success! Code: %d\n", code);
      if (code == 200) {
        String payload = https.getString();
        Serial.println("[Firebase] Response: " + payload);
      }
    } else {
      Serial.printf("[Firebase] Failed. Error: %s\n", https.errorToString(code).c_str());
    }

    https.end();
  } else {
    Serial.println("[Firebase] Unable to connect");
  }
}
void calibrate_rtc(){
  if (WiFi.status() != WL_CONNECTED) {
    check_wifi_status();
  }

  if (WiFi.status() == WL_CONNECTED) {
    configTime(0, 0, "time.nist.gov", "pool.ntp.org", "192.168.137.1");
    struct tm t;
    if (getLocalTime(&t)) {
      rtc.adjust(DateTime(t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec));
      r_state = true;
      Serial.println("[rtc] Time synchronized successfully");
    } else {

      Serial.println("[rtc] NTP sync failed");
    }
  } else {
    
    Serial.println("[rtc] WiFi unavailable for RTC calibration");
  }
}
void screen_one(){
    // time section
    u8g2.setFont(u8g2_font_6x12_tr); 
    if (!r_state) {
      u8g2.drawStr(0,14,"RTC Error or No time");
    } 
    else {
      DateTime now = DateTime(rtc.now().unixtime() + 19800); // Local IST offset (+5:30)
      char timeBuf[25];
      sprintf(timeBuf, "%04d/%02d/%02d  %02d:%02d:%02d", now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
      u8g2.setCursor(0, 14);
      u8g2.print(F(timeBuf));
    }
    // Sensor data
    u8g2.drawHLine(0,16,128);
    if (!((temp > 108) || (temp < 0))){
      char tempBuf[50];
      sprintf(tempBuf, "Temp: %0.2f C", temp);
      u8g2.drawStr(0,28,tempBuf);
    }
    if (!((humidity > 108) || (humidity < 0) || (isnan(humidity)))){
      char humidityBuf[50];
      sprintf(humidityBuf, "Humidity: %0.2f %%", humidity);
      u8g2.drawStr(0,40,humidityBuf);
    }
    if(!((pressure < 0) || (isnan(pressure)))) {
      char pressureBuf[50];
      sprintf(pressureBuf, "Pressure: %0.2f Hpa", pressure);
      u8g2.drawStr(0,52,pressureBuf);
    }

}

void screen_two(){
    u8g2.setFont(u8g2_font_6x12_tr);
    u8g2.drawStr(0, 14, "WiFi Status");
    u8g2.drawHLine(0, 16, 128);

    if (wifi_available) {
      int rssi = WiFi.RSSI();
      char stateBuf[32];
      sprintf(stateBuf, "State: Connected");
      u8g2.drawStr(0, 28, stateBuf);

      char rssiBuf[32];
      sprintf(rssiBuf, "RSSI: %d dBm", rssi);
      u8g2.drawStr(0, 40, rssiBuf);

      int bars = 0;
      if (rssi >= -55) bars = 4;
      else if (rssi >= -65) bars = 3;
      else if (rssi >= -75) bars = 2;
      else if (rssi >= -85) bars = 1;

      char meterBuf[32];
      sprintf(meterBuf, "Meter: %s", bars == 0 ? "none" : "||||");
      u8g2.drawStr(0, 52, meterBuf);

      if (!rtc_calibrated) {
        calibrate_rtc();
        rtc_calibrated = true;
      }
    } else {
      u8g2.drawStr(0, 28, "State: Offline");
      u8g2.drawStr(0, 40, "RSSI: n/a");
      u8g2.drawStr(0, 52, "Meter: none");
      u8g2.drawStr(0, 64, "Trying to connect...");
    }
}

void update_gui(){
  unsigned long screen_duration = (current_screen == 0) ? SCREEN1_DURATION : SCREEN2_DURATION;

  if ((last_screen_switch == 0) || ((millis() - last_screen_switch) >= screen_duration)) {
    current_screen = 1 - current_screen;
    last_screen_switch = millis();
  }

  u8g2.firstPage();
  do {
    if (current_screen == 0) {
      screen_one();
    } else {
      screen_two();
    }
  } while ( u8g2.nextPage() );
}

void setup() {

  Serial.begin(115200);
  while (!Serial) delay(100);

  pinMode(I2C_SDA, INPUT);
  pinMode(I2C_SCL, INPUT);
  delay(500); 

  esp_bt_controller_disable();
  esp_wifi_set_max_tx_power(WIFI_POWER_8_5dBm);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(WIFI_PS_NONE); 
  delay(100);

  Wire.begin(I2C_SDA, I2C_SCL);
  delay(100);

  dht.begin();
  Serial.println("[sensor] DHT11 initialized.");

  //Check if RTC had real time or not
  bool raw_r_state = rtc.begin(&Wire) ;
  if (raw_r_state){

    if ((rtc.lostPower())){r_state = false;calibrate_rtc();}
    else{r_state = true;}
  }
  else{r_state = false;}


  bmp_began = bmp.begin(0x76);
  if (!bmp_began) {
    Serial.println("[sensor] Could not find a valid BMP280 sensor, check wiring or I2C address!");
  }
  else{
    // Citation : Settings for the below BMP code is generated by ai
    /* Default settings for the BMP280 indoor navigation setup */
  bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,     /* Operating Mode. */
                  Adafruit_BMP280::SAMPLING_X2,     /* temp. oversampling */
                  Adafruit_BMP280::SAMPLING_X16,    /* pressure oversampling */
                  Adafruit_BMP280::FILTER_X16,      /* Filtering. */
                  Adafruit_BMP280::STANDBY_MS_500); /* Standby time. */
  }
  Serial.println("BMP280 initialized successfully.\n");
  // OLED delays to stabilize lanes
  delay(100);
  u8g2.begin();
  u8g2.setPowerSave(0);
  wifi_available = (WiFi.status() == WL_CONNECTED);
  u8g2.clearDisplay();          
  u8g2.setFont(u8g2_font_6x13_tr);
  delay(50);                
  
}


void loop() {

  if ((lastsensorupdate == 0) || ((millis() - lastsensorupdate) >= SENSOR_UPDATE)){
    humidity = dht.readHumidity();
    temp = bmp.readTemperature();
    pressure = bmp.readPressure() / 100.0F; // Convert Pa to hPa 
    print_sensor_data();
    lastsensorupdate = millis(); 
  }
  
  if ((lastguiupdate == 0) || ((millis() - lastguiupdate) >= OLED_UPDATE )){
      update_gui();
      lastguiupdate = millis();
  }
  if ((lastwifiupdate == 0) || ((millis() - lastwifiupdate) >= WIFI_C_INTERVAL)){
    check_wifi_status();
    lastwifiupdate = millis();
  }

  if ((lastFirebaseSync == 0) || ((millis() - lastFirebaseSync) >= FIREBASE_SYNC_INTERVAL)) {
    send_firebase_data();
    lastFirebaseSync = millis();
  }
}

// add a startup screen logo that read from a file named images .h and a array name startup_logo in xbm format .c format and get prediction of wether from the the firebase the next three days as  0,1 ,2 under a {} named predictions and toady's in root of the josn object weather_code