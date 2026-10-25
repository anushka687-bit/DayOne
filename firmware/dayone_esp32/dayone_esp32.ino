/*
 * DayOne — ESP32 sensor firmware (Stage 1: LDR, LM393 sound, HC-SR04)
 *
 * Reads the three sensors that are wired right now, turns them into the
 * same 0..1 shape the Flutter app's ContextSnapshot expects (light, noise,
 * movement), and serves them as JSON over a small HTTP endpoint so the
 * phone can poll it. The ESP32 runs as its own WiFi access point, so there
 * is no dependency on venue WiFi during a demo — the phone connects
 * directly to it.
 *
 * Pin map (matches the wiring diagram):
 *   LDR module AO        -> GPIO34 (ADC1_CH6)
 *   LM393 sound AO        -> GPIO35 (ADC1_CH7)
 *   HC-SR04 TRIG          -> GPIO5
 *   HC-SR04 ECHO          -> GPIO18 (through the 1k/2k divider on the
 *                             breadboard — do not skip that, ECHO is 5V)
 *
 * GPIO21 (SDA) / GPIO22 (SCL) are intentionally untouched here — once
 * MPU6050 is soldered on, see the MOVEMENT SOURCE note near
 * computeMovement() below for the one function to swap.
 *
 * Endpoint:
 *   GET http://192.168.4.1/context
 *   -> {"light":0.00-1.00,"noise":0.00-1.00,"movement":0.00-1.00}
 */

#include <WiFi.h>
#include <WebServer.h>

// ---------- WiFi AP config ----------
const char *AP_SSID = "DayOne-ESP32";
const char *AP_PASSWORD = "dayone123"; // must be 8+ chars for WPA2
WebServer server(80);

// ---------- Pins ----------
const int PIN_LDR = 34;
const int PIN_SOUND = 35;
const int PIN_TRIG = 5;
const int PIN_ECHO = 18;

// ---------- Calibration ----------
// If your LDR module reads LOW in bright light instead of HIGH (depends on
// the module's internal divider orientation), flip this to true.
const bool LDR_INVERTED = false;

// Raw ADC range actually seen in your room — adjust after a quick test
// (print rawLdr/rawSound over Serial for a few seconds first).
const int ADC_MIN = 0;
const int ADC_MAX = 4095;

// Ultrasonic distance range (cm) used to scale the movement proxy.
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

// ---- MOVEMENT (Stage 1 proxy): rate of change in ultrasonic distance ----
// No accelerometer yet, so "movement" is approximated by how much the
// nearest reflecting object (presumably the user) is shifting position
// between samples. It's a rough stand-in, not real motion data.
//
// *** MOVEMENT SOURCE — swap this once MPU6050 is soldered on ***
// Replace the body of this function with an accel/gyro magnitude read
// (e.g. sqrt(ax^2+ay^2+az^2) minus 1g, scaled to 0..1) over I2C on
// GPIO21/22. Nothing else in this file, or in the Flutter app, needs to
// change — computeMovement() is the only seam.
float computeMovement() {
  float d = readDistanceCm();
  if (d < 0) {
    // No echo (out of range / nothing in front) — treat as "still".
    gLastDistanceCm = -1;
    return 0.0;
  }

  float movement = 0.0;
  if (gLastDistanceCm >= 0) {
    float delta = fabs(d - gLastDistanceCm);
    float range = (US_MAX_CM - US_MIN_CM);
    // A ~30cm jump between samples counts as fully "a lot of movement".
    movement = clamp01(delta / 30.0);
  }
  gLastDistanceCm = d;
  return movement;
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
