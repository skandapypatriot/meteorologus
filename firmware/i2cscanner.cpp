#include <Wire.h>
#include <Arduino.h>

#define I2C_SDA 4
#define I2C_SCL 5
#define I2C_CLOCK 100000

void scanAddress(uint8_t addr);
void probeDevice(uint8_t addr);
bool checkAddress(uint8_t addr);
void dumpBus(void);

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);
  Serial.println();
  Serial.println("=== I2C Scanner (ESP32-C3) ===");
  Serial.printf("SDA=%d SCL=%d clock=%dHz\r\n", I2C_SDA, I2C_SCL, I2C_CLOCK);

  if (!Wire.begin(I2C_SDA, I2C_SCL, I2C_CLOCK)) {
    Serial.println("FATAL: Wire.begin() failed to claim pins 4/5");
    Serial.println("Check that nothing else (e.g. anything else on pins 4/5)");
    Serial.println("is driving those pins.");
  }

  Serial.println("Scanning 0x03..0x77 ...");
}

void loop() {
  int found = 0;

  for (uint8_t addr = 0x03; addr <= 0x77; addr++) {
    scanAddress(addr);
    if (addr != 0x77) delay(1);
  }

  Serial.println();
  Serial.println("=== Detailed one-shot read attempt on detected devices ===");
  for (uint8_t addr = 0x03; addr <= 0x77; addr++) {
    if (checkAddress(addr)) {
      found++;
      probeDevice(addr);
    }
  }

  if (found == 0) {
    Serial.println("No I2C devices found.");
    dumpBus();
  } else {
    Serial.printf("Done: %d device(s) found.\r\n", found);
  }

  Serial.println("Rescanning in 3s ...");
  Serial.println();
  delay(3000);
}

bool checkAddress(uint8_t addr) {
  Wire.beginTransmission(addr);
  uint8_t err = Wire.endTransmission();
  return (err == 0);
}

void scanAddress(uint8_t addr) {
  Wire.beginTransmission(addr);
  uint8_t err = Wire.endTransmission();

  if (err == 0) {
    Serial.printf("0x%02X  OK  ", addr);
  } else {
    return;
  }

  uint8_t tmp[4] = {0, 0, 0, 0};
  Wire.requestFrom((int)addr, 4, (int)true);
  if (Wire.available() >= 4) {
    Wire.readBytes(tmp, 4);
    Serial.printf("first4bytes: %02X %02X %02X %02X", tmp[0], tmp[1], tmp[2], tmp[3]);
  } else {
    int n = Wire.available();
    uint8_t b;
    Serial.printf("nack-on-read (%d bytes avail): ", n);
    while (Wire.available()) {
      b = Wire.read();
      Serial.printf("%02X ", b);
    }
  }
  Serial.println();
}

void probeDevice(uint8_t addr) {
  Serial.printf("0x%02X : ", addr);
  int len = Wire.requestFrom((int)addr, 1, (int)true);
  if (len == 1) {
    Serial.printf("ack read -> reg0 = 0x%02X\r\n", Wire.read());
  } else {
    Serial.println("write-addr acked, but no read data (write-only?)\r");
  }
  delay(2);
}

void dumpBus(void) {
  Wire.beginTransmission(0x00);
  Wire.write(0x00);
  uint8_t err = Wire.endTransmission();
  Serial.printf("Bus check: gen-call returned error code %d (0=ok)\r\n", err);
}
