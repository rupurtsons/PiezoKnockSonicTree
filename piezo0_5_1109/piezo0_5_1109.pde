// ---------------------------------------------------------
// PIEZO REVERB (MEGA, 5 sensors) — with SELF-TEST + DIAGNOSTICS
// Keys: '1'..'5' = play files 0..4 directly; 'T' = synthetic trigger; 'R' = reload sounds
// ---------------------------------------------------------

import processing.serial.*;
import processing.sound.*;
import java.io.File;

// ---- CONFIG ----
final int    numSensors    = 5;     // A0..A4
final int    layers        = 3;     // overlapping voices per sensor
final int    cooldownMs    = 200;   // per-sensor debounce in Processing
final int    minIntensity  = 60;    // ignore tiny knocks
final int    baudRate      = 9600; // MUST MATCH Arduino (Serial.begin)

// ---- STATE ----
Serial        myPort;
SoundFile[][] voices   = new SoundFile[numSensors][layers];
Reverb        reverb;
int[]         lastTrig = new int[numSensors];
int[]         nextIdx  = new int[numSensors];
boolean       serialReady = false;
String        status   = "Init…";
String        portUsed = "(none)";

String        lastLine = "";
int           linesThisSec = 0, linesPerSec = 0;
int           lastSecondMark = 0;

float[]       fileDur = new float[numSensors];  // seconds per sensor (layer 0 only)

// ---- SETUP ----
void setup() {
  size(800, 420);
  surface.setTitle("Piezo Reverb — MEGA x5 — Self-test/Diagnostics");
  textAlign(LEFT, TOP);
  textSize(14);
  stroke(255);

  println("Available ports:");
  printArray(Serial.list());

  // ---- choose serial port ----
  String chosen = autoPickPort();
  // Optionally hardcode instead:
  // chosen = "/dev/cu.usbmodem2101";

  if (chosen == null) {
    status = "⚠️ No likely Arduino port found. Set 'chosen' manually.";
    println(status);
  } else {
    try {
      myPort = new Serial(this, chosen, baudRate);
      myPort.clear();
      myPort.bufferUntil('\n'); // line-based
      serialReady = true;
      portUsed = chosen;
      status = "Connected: " + chosen + " @ " + baudRate + " baud";
    } catch (Exception e) {
      status = "⚠️ Failed to open port: " + chosen + " (" + e.getMessage() + ")";
      println(status);
      serialReady = false;
    }
  }

  // ---- audio ----
  reverb = new Reverb(this);
  loadSounds();

  // init arrays
  for (int i = 0; i < numSensors; i++) {
    lastTrig[i] = 0;
    nextIdx[i]  = 0;
  }

  lastSecondMark = millis();
}

// ---- DRAW ----
void draw() {
  background(16);

  // update lines/sec meter
  int now = millis();
  if (now - lastSecondMark >= 1000) {
    linesPerSec = linesThisSec;
    linesThisSec = 0;
    lastSecondMark = now;
  }

  fill(240);
  text("Piezo Reverb — 5 sensors (A0–A4) — MEGA @ " + baudRate + " baud", 20, 16);
  text("Port: " + portUsed, 20, 38);
  text("Status: " + status, 20, 60);
  text("Lines/sec: " + linesPerSec + "    Last line: " + lastLine, 20, 82);

  // File sanity panel
  float y = 114;
  text("Sound files check (data/0.wav…4.wav):", 20, y); y += 22;

  for (int i = 0; i < numSensors; i++) {
    String fn = i + ".wav";
    boolean exists = fileExistsInData(fn);
    String msg = " " + fn + "  —  " + (exists ? "FOUND" : "MISSING");

    if (exists) {
      float d = fileDur[i];
      msg += "  (duration: " + nf(d, 1, 2) + " s)";
      if (d <= 0) msg += "  ⚠️ duration 0 — not loadable?";
    }

    fill(exists ? 180 : color(255,80,80));
    text(msg, 20, y); 
    y += 20;
  }

  // Sensor bars
  y += 10;
  text("Per-sensor activity (recent hits brighter).", 20, y); 
  y += 10;

  float x0 = 20, w = width - 40, h = 26, pad = 10;
  for (int i = 0; i < numSensors; i++) {
    float barY = y + i*(h + pad);
    // age 0..1 over cooldownMs
    float age = constrain((millis() - lastTrig[i]) / (float)cooldownMs, 0, 1);
    int alpha = (int)map(age, 0, 1, 255, 60);

    noStroke();
    fill(50);
    rect(x0, barY, w, h, 8);
    fill(200, alpha);
    rect(x0, barY, w * (1.0 - 0.75*age), h, 8);

    fill(235);
    text("Sensor " + (i+1) + "    next layer " + nextIdx[i], x0 + 10, barY + 5);
  }

  // Footer
  y = height - 90;
  fill(180);
  text("Tips: Close Arduino Serial Monitor. If Lines/sec = 0, check Arduino baud/port/wiring.\n" +
       "Self-test: press 1..5 to play 0.wav..4.wav directly. Press T to synth-trigger. Press R to reload files.", 20, y);
}

// ---- SERIAL ----
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  line = trim(line);
  if (line.length() == 0) return;

  lastLine = line;
  linesThisSec++;

  // Expect "sensor,intensity"
  String[] parts = split(line, ',');
  if (parts.length != 2) {
    println("Skip malformed: " + line);
    return;
  }

  int s = -1;
  int v = -1;
  try {
    s = int(parts[0]) - 1;  // incoming 1..5 → 0..4
    v = int(parts[1]);      // 0..1023
  } catch (Exception e) {
    println("Parse error: " + line + " / " + e.getMessage());
    return;
  }

  if (s < 0 || s >= numSensors) return;
  if (v < minIntensity) return;

  // debounce per sensor
  int now = millis();
  if (now - lastTrig[s] < cooldownMs) return;
  lastTrig[s] = now;

  triggerSound(s, v);
}

// ---- AUDIO TRIGGER ----
void triggerSound(int sensor, int intensity) {
  // map intensity
  float room   = map(intensity, 40, 1023, 0.10, 1.00);
  float damp   = map(intensity, 40, 1023, 0.20, 0.80);
  float volume = map(intensity, 40, 1023, 0.40, 1.00);

  reverb.room(room);
  reverb.damp(damp);

  SoundFile sf = voices[sensor][nextIdx[sensor]];
  if (sf == null) {
    println("⚠️ SoundFile null for sensor " + sensor + ", layer " + nextIdx[sensor]);
    return;
  }

  // restart if still ringing for a crisp transient
  if (sf.isPlaying()) sf.stop();
  sf.amp(volume);       // single-arg amp
  sf.play();

  nextIdx[sensor] = (nextIdx[sensor] + 1) % layers;

  println("▶ sensor " + (sensor+1) + " | intensity " + intensity +
          " | room " + nf(room,1,2) + " | damp " + nf(damp,1,2) +
          " | vol " + nf(volume,1,2));
}

// ---- KEYBOARD SELF-TESTS ----
void keyPressed() {
  if (key == '1') manualPlay(0);
  if (key == '2') manualPlay(1);
  if (key == '3') manualPlay(2);
  if (key == '4') manualPlay(3);
  if (key == '5') manualPlay(4);
  if (key == 't' || key == 'T') triggerSound(0, 800);  // synthetic strong hit on sensor 1
  if (key == 'r' || key == 'R') { 
    println("Reloading sounds…");
    loadSounds();
  }
}

void manualPlay(int sensorIdx) {
  if (sensorIdx < 0 || sensorIdx >= numSensors) return;
  SoundFile sf = voices[sensorIdx][0];
  if (sf == null) { println("⚠️ " + sensorIdx + ".wav not loaded."); return; }
  if (sf.isPlaying()) sf.stop();
  reverb.room(0.6);
  reverb.damp(0.5);
  sf.amp(0.8);
  sf.play();
  println("♪ manual play: " + sensorIdx + ".wav");
}

// ---- LOAD/VERIFY SOUNDS ----
void loadSounds() {
  // dispose old files if any
  for (int i = 0; i < numSensors; i++) {
    for (int j = 0; j < layers; j++) {
      voices[i][j] = null;
    }
    fileDur[i] = 0;
  }

  for (int i = 0; i < numSensors; i++) {
    String fn = i + ".wav";
    boolean exists = fileExistsInData(fn);
    if (!exists) {
      println("⚠️ MISSING: data/" + fn + " — add your WAV.");
      continue;
    }
    // Instantiate one file to read duration
    try {
      SoundFile probe = new SoundFile(this, fn);
      float d = max(0, probe.duration());
      fileDur[i] = d;
      println("Loaded " + fn + " duration=" + nf(d,1,2) + "s");
      // Now create layers and route to reverb
      voices[i][0] = probe;
      for (int j = 1; j < layers; j++) {
        voices[i][j] = new SoundFile(this, fn);
      }
      for (int j = 0; j < layers; j++) {
        reverb.process(voices[i][j]);
      }
    } catch (Exception e) {
      println("⚠️ Failed to load " + fn + " : " + e.getMessage());
    }
  }
}

// ---- HELPERS ----
String autoPickPort() {
  String[] ports = Serial.list();
  if (ports == null || ports.length == 0) return null;
  for (String p : ports) {
    String pl = p.toLowerCase();
    if (pl.contains("usbmodem") || pl.contains("usbserial") || pl.contains("tty.usb")) return p;
  }
  return ports[0]; // fallback
}

boolean fileExistsInData(String fname) {
  String p = dataPath(fname);
  return new File(p).exists();
}
