/*
  5 Piezo Knock Sensors → Processing
  Sends sensor number and knock intensity (0–1023)
*/

const int numSensors = 5;
const int piezoPins[numSensors] = {A0, A1, A2, A3, A4};
const int threshold = 40;
const unsigned long debounceDelay = 50; // shorter delay for faster response

unsigned long lastKnockTime[numSensors];

void setup() {
  Serial.begin(9600);
  Serial.println("5 Piezo Knock Sensors Ready...");
}

void loop() {
  for (int i = 0; i < numSensors; i++) {
    int reading = analogRead(piezoPins[i]);

    if (reading > threshold && (millis() - lastKnockTime[i]) > debounceDelay) {
      // Send "sensor_number,intensity"
      Serial.print(i + 1);
      Serial.print(",");
      Serial.println(reading);
      lastKnockTime[i] = millis();
    }
  }
}

