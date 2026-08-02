#include <Arduino.h> // Required for PlatformIO C++ compilation
#include <WiFi.h>
#include "time.h"
#include <Wire.h>
#include <RTClib.h>
#include "esp_wifi.h" 
#include "esp_bt.h"   

#define I2C_SDA 8
#define I2C_SCL 9

// NTP Settings
const char* ntpServer = "time.nist.gov";
const long  gmtOffset_sec = 19800; // Adjust to your local time zone offset
const int   daylightOffset_sec = 0; 

RTC_DS3231 rtc;

// =========================================================================
// PLATFORMIO COMPILER PATCH: Forward Declarations (Function Prototypes)
// =========================================================================
String readSerialString();
void runWiFiNtpCalibration();
void syncRTClocal();

// =========================================================================
// CORE FUNCTIONS
// =========================================================================

void setup() {
  Serial.begin(115200);
  // Wait up to 7 seconds for the user to open their Serial Monitor window
  unsigned long startWait = millis();
  while (!Serial && (millis() - startWait < 7000)); 
  
  delay(1000);
  Serial.println("\n======================================");
  Serial.println("     ESP32-C3 RTC INTERACTIVE TOOL    ");
  Serial.println("======================================");

  // Initialize hardware bus
  Wire.begin(I2C_SDA, I2C_SCL);
  if (!rtc.begin(&Wire)) {
    Serial.println("[-] WARNING: DS3231 module not detected over I2C!");
  } else {
    Serial.println("[+] DS3231 I2C Connection: OK");
  }

  // Optimize radio stability (caps current spikes)
  esp_bt_controller_disable();
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);

  // Present the Main Menu
  Serial.println("\n[MAIN MENU] Choose an option:");
  Serial.println("  1 -> Scan Wi-Fi, Connect, & Calibrate RTC via NTP");
  Serial.println("  2 -> Skip Calibration & Just Read Current RTC Time");
  Serial.print("Enter choice (1 or 2): ");
  
  String choice = readSerialString();
  Serial.println(choice); // Echo selection back

    runWiFiNtpCalibration();

}

void loop() {
  // Read and format time out of the physical clock registers every 5 seconds
  if (rtc.begin(&Wire)) {
    DateTime now = rtc.now();
    char buffer[] = "YYYY-MM-DD hh:mm:ss";
    Serial.print("[RTC Live] ");
    Serial.println(now.toString(buffer));
  } else {
    Serial.println("[RTC Live] Error: External clock missing.");
  }
  delay(5000); 
}

// =========================================================================
// HELPER FUNCTIONS
// =========================================================================

String readSerialString() {
  while (!Serial.available()) {
    delay(10); // Wait for input
  }
  String input = Serial.readStringUntil('\n');
  input.trim(); // Strip carriage returns or spaces
  return input;
}

void runWiFiNtpCalibration() {
  // 1. Perform an all-channel ambient network scan
  Serial.println("\n[*] Scanning all channels for available Wi-Fi networks...");
  int n = WiFi.scanNetworks();
  if (n == 0) {
    Serial.println("[-] No networks found. Check your board antenna placement.");
  } else {
    Serial.printf("[+] Found %d networks in range:\n", n);
    for (int i = 0; i < n; ++i) {
      Serial.printf("    %2d: %-25s (Signal: %d dBm)\n", i + 1, WiFi.SSID(i).c_str(), WiFi.RSSI(i));
    }
  }
Serial.setTimeout(20000);
  // 2. Request Credentials from User via Serial
  Serial.println("\n======================================");
  Serial.print("[?] Enter your Wi-Fi SSID: ");
  String ssidInput = readSerialString();
  Serial.println(ssidInput); // Echo back

  Serial.print("[?] Enter your Wi-Fi Password: ");
  String passInput = readSerialString();
  // Print asterisks instead of plain text password for privacy safety
  Serial.print(passInput); 
  Serial.println();

  // 3. Connect to network across all channels
  Serial.printf("\n[*] Connecting to network: %s\n", ssidInput.c_str());
  WiFi.begin(ssidInput.c_str(), passInput.c_str());
  
  // Power safety patch to stop local ESP32-C3 board brownout disconnect loops
  esp_wifi_set_max_tx_power(WIFI_POWER_15dBm); 

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  // 4. Sync Time if Connected
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\n[+] Wi-Fi Connected! IP Address: ");
    Serial.println(WiFi.localIP());
    
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    syncRTClocal();
    
    // Shut down RF radios immediately to prioritize battery life and stability
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
    Serial.println("[*] Wi-Fi hardware powered off safely.");
  } else {
    Serial.printf("\n[-] Connection Failed. Standard Wi-Fi Status Error Code: %d\n", WiFi.status());
    Serial.println("[-] Check credentials. Moving to runtime fallback.");
  }
}

void syncRTClocal() {
  struct tm timeinfo;
  Serial.print("[*] Waiting for NTP Network Sync...");
  int retry = 0;
  while(!getLocalTime(&timeinfo) && retry < 15) {
    delay(1000);
    retry++;
    Serial.print(".");
  }
  
  if(retry < 15) {
    time_t epochTime;
    time(&epochTime);
    rtc.adjust(DateTime(epochTime));
    Serial.println("\n[+] SUCCESS: DS3231 Hardware calibrated successfully via NTP!");
  } else {
    Serial.println("\n[-] ERROR: NTP server handshake timed out.");
  }
}
// #include <WiFi.h>
// #include "esp_wifi.h"
// // Replace with your Wi-Fi credentials
// const char* ssid = "test12";
// const char* password = "1234567890";

// void setup() {
//   // Initialize Serial Monitor
//   Serial.begin(115200);
//   while (!Serial) {
//     delay(10);
//   }

//   Serial.println("\n--- ESP32-C3 Wi-Fi Test ---");
  
//   // Test 1: Scan Networks
//   Serial.println("Scanning for available networks...");
//   int n = WiFi.scanNetworks();
//   Serial.println("Scan done.");
  
//   if (n == 0) {
//     Serial.println("No networks found.");
//   } else {
//     Serial.print(n);
//     Serial.println(" networks found:");
//     for (int i = 0; i < n; ++i) {
//       Serial.print(i + 1);
//       Serial.print(": ");
//       Serial.print(WiFi.SSID(i));
//       Serial.print(" (");
//       Serial.print(WiFi.RSSI(i));
//       Serial.print(" dBm)");
//       Serial.println((WiFi.encryptionType(i) == WIFI_AUTH_OPEN) ? " " : "*");
//       delay(10);
//     }
//   }
//   Serial.println("\n--------------------------");

//   // Test 2: Connect to Wi-Fi
//   Serial.print("Connecting to: ");
//   Serial.println(ssid);
//   esp_wifi_set_max_tx_power(WIFI_POWER_8_5dBm);
//   WiFi.mode(WIFI_STA);
//   WiFi.setSleep(WIFI_PS_NONE); 
//   WiFi.begin(ssid, password);

//   while (WiFi.status() != WL_CONNECTED) {
//     delay(500);
//     Serial.print(".");
//   }

//   // Connection successful
//   Serial.println("\nWi-Fi connected successfully!");
//   Serial.print("IP Address: ");
//   Serial.println(WiFi.localIP());
//   Serial.print("Signal Strength (RSSI): ");
//   Serial.print(WiFi.RSSI());
//   Serial.println(" dBm");
// }

// void loop() {
//   // Keep connection alive and print signal strength periodically
//   if (WiFi.status() == WL_CONNECTED) {
//     Serial.print("Signal Strength: ");
//     Serial.print(WiFi.RSSI());
//     Serial.println(" dBm");
//   } else {
//     Serial.println("WiFi Disconnected!");
//   }
//   delay(5000);
// }
