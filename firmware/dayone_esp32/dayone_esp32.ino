/*
 * DayOne — ESP32 sensor firmware (Stage 2: LDR, LM393 sound, HC-SR04, MPU6050)
 *
 * Reads the four sensors that are wired now, turns them into the
 * same 0..1 shape the Flutter app's ContextSnapshot expects (light, noise,
 * movement), and serves them as JSON over a small HTTP endpoint so the
 * phone can poll it. The ESP32 runs as its own WiFi access point, so there
 * is no dependency on venue WiFi during a demo — the phone connects
 * directly to it.
 *
 * Pin map (matches the wiring diagram):
 *   LDR module AO        -> GPIO34 (ADC1_CH6)
 *   LM393 sound AO       -> GPIO35 (ADC1_CH7)
 *   HC-SR04 TRIG         -> GPIO5
 *   HC-SR04 ECHO         -> GPIO18 (through the 1k/2k divider on the
 *                            breadboard — do not skip that, ECHO is 5V)
 *   MPU6050 SDA          -> GPIO21
 *   MPU6050 SCL          -> GPIO22
 *   MPU6050 AD0, INT     -> left disconnected (AD0 floating = address 0x68)
 *
 * Library needed (Arduino IDE -> Tools -> Manage Libraries):
 *   "Adafruit MPU6050" (installing it will also pull in
 *   "Adafruit Unified Sensor" and "Adafruit BusIO" automatically)
 *
 * Endpoint:
 *   GET http://192.168.4.1/context
 *   -> {"light":0.00-1.00,"noise":0.00-1.00,"movement":0.00-1.00}
 */

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// ---------- WiFi AP config ----------
const char *AP_SSID = "DayOne-ESP32";
const char *AP_PASSWORD = "dayone123"; // must be 8+ chars for WPA2
WebServer server(80);

// ---------- Pins ----------
const int PIN_LDR = 34;
const int PIN_SOUND = 35;
const int PIN_TRIG = 5;
const int PIN_ECHO = 18;
const int PIN_SDA = 21;
const int PIN_SCL = 22;

// ---------- MPU6050 ----------
Adafruit_MPU6050 mpu;
bool gMpuReady = false;

// How much accel magnitude change (in g, after removing 1g gravity) counts
// as "full movement" (1.0). Start here, then tune from testing: shake gently
// and watch the Serial debug line below; raise this if it saturates at 1.0
// too easily, lower it if gentle moves barely register.
const float MPU_MOVEMENT_CEILING_G = 0.5;

// ---------- Calibration ----------
// If your LDR module reads LOW in bright light instead of HIGH (depends on
// the module's internal divider orientation), flip this to true.
const bool LDR_INVERTED = false;

// Raw ADC range actually seen in your room — adjust after a quick test
// (print rawLdr/rawSound over Serial for a few seconds first).
const int ADC_MIN = 0;
const int ADC_MAX = 4095;

// Ultrasonic distance range (cm) — kept only as a fallback if the MPU6050
// isn't detected at boot (see computeMovement() below).
const float US_MIN_CM = 2.0;
const float US_MAX_CM = 300.0;

// Sound sampling window for a peak-to-peak amplitude read.
const int SOUND_SAMPLE_WINDOW_MS = 30;

// ---------- State ----------
float gLight = 0.5;
float gNoise = 0.2;
float gMovement = 0.15;
float gLastDistanceCm = -1;
unsigned long gLastSampleAt = 0;
const unsigned long SAMPLE_INTERVAL_MS = 200;

float clamp01(float v) {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

// ---- LIGHT: LDR module AO -> 0..1 ----
float readLight() {
  int raw = analogRead(PIN_LDR);
  float v = (float)(raw - ADC_MIN) / (float)(ADC_MAX - ADC_MIN);
  v = clamp01(v);
  return LDR_INVERTED ? (1.0 - v) : v;
}

// ---- NOISE: LM393 sound AO, peak-to-peak amplitude over a short window ----
float readNoise() {
  int lo = 4095, hi = 0;
  unsigned long start = millis();
  while (millis() - start < SOUND_SAMPLE_WINDOW_MS) {
    int s = analogRead(PIN_SOUND);
    if (s < lo) lo = s;
    if (s > hi) hi = s;
  }
  int amplitude = hi - lo; // 0 (silence) .. up to ~4095 (loud)
  // Mic modules rarely swing the full ADC range on normal room noise, so
  // scale against a smaller practical ceiling — tune ~800-1500 after
  // testing against your actual sensitivity-pot setting.
  const int NOISE_CEILING = 1000;
  return clamp01((float)amplitude / (float)NOISE_CEILING);
}

// ---- Raw ultrasonic distance in cm, or -1 if no echo ----
// Only used as a fallback now (see computeMovement()).
float readDistanceCm() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  long duration = pulseIn(PIN_ECHO, HIGH, 25000); // 25ms timeout (~4m)
  if (duration == 0) return -1;
  return duration * 0.0343 / 2.0; // speed of sound -> cm
}

// ---- Fallback movement proxy (used only if MPU6050 isn't found at boot) ----
float computeMovementFromUltrasonic() {
  float d = readDistanceCm();
  if (d < 0) {
    gLastDistanceCm = -1;
    return 0.0;
  }
  float movement = 0.0;
  if (gLastDistanceCm >= 0) {
    float delta = fabs(d - gLastDistanceCm);
    movement = clamp01(delta / 30.0);
  }
  gLastDistanceCm = d;
  return movement;
}

// ---- MOVEMENT: real accel magnitude from the MPU6050 ----
float computeMovement() {
  if (!gMpuReady) {
    // MPU6050 not detected at boot — fall back to the old ultrasonic proxy
    // so the endpoint still returns something sensible.
    return computeMovementFromUltrasonic();
  }

  sensors_event_t accel, gyro, temp;
  mpu.getEvent(&accel, &gyro, &temp);

  // Adafruit's library returns acceleration in m/s^2. Convert to g (1g =
  // 9.80665 m/s^2), take the magnitude, then subtract 1g to cancel gravity
  // when the board is sitting still.
  const float G = 9.80665;
  float ax = accel.acceleration.x / G;
  float ay = accel.acceleration.y / G;
  float az = accel.acceleration.z / G;
  float magnitudeG = sqrt(ax * ax + ay * ay + az * az);
  float movementG = fabs(magnitudeG - 1.0);

  return clamp01(movementG / MPU_MOVEMENT_CEILING_G);
}

void sampleSensors() {
  gLight = readLight();
  gNoise = readNoise();
  gMovement = computeMovement();
}

void handleContext() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  char buf[128];
  snprintf(buf, sizeof(buf),
           "{\"light\":%.3f,\"noise\":%.3f,\"movement\":%.3f}",
           gLight, gNoise, gMovement);
  server.send(200, "application/json", buf);
}

void handleRoot() {
  server.send(200, "text/plain",
              "DayOne ESP32 sensor node. GET /context for current readings.");
}

void setup() {
  Serial.begin(115200);

  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  analogReadResolution(12); // 0..4095

  // ---- MPU6050 init ----
  Wire.begin(PIN_SDA, PIN_SCL);
  if (mpu.begin()) {
    gMpuReady = true;
    mpu.setAccelerometerRange(MPU6050_RANGE_4_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    Serial.println("MPU6050 found and initialized.");
  } else {
    gMpuReady = false;
    Serial.println("MPU6050 NOT found — falling back to ultrasonic movement proxy.");
  }

  WiFi.softAP(AP_SSID, AP_PASSWORD);
  IPAddress ip = WiFi.softAPIP();
  Serial.print("DayOne AP up. Connect phone to \"");
  Serial.print(AP_SSID);
  Serial.print("\", then GET http://");
  Serial.print(ip);
  Serial.println("/context");

  server.on("/", handleRoot);
  server.on("/context", handleContext);
  server.begin();
}

void loop() {
  server.handleClient();

  unsigned long now = millis();
  if (now - gLastSampleAt >= SAMPLE_INTERVAL_MS) {
    gLastSampleAt = now;
    sampleSensors();
    // Uncomment while calibrating:
    // Serial.printf("light=%.2f noise=%.2f movement=%.2f\n", gLight, gNoise, gMovement);
  }
}
