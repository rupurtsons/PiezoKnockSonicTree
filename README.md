# PiezoKnockSonicTree
This is an open-source experiment connecting piezo sensors to an Arduino and Processing to transform physical touch and vibration into layered, reverberating sound.
Each sensor detects taps or knocks on different surfaces, and the data is sent over serial to Processing, which plays audio samples with varying volume and reverb based on how hard the surface is hit.

The goal is to explore sound as a sculptural and spatial response — where touch, structure, and resonance overlap.

Parts used:

Arduino Mega or Uno

1–5 piezo sensors

470 kΩ (or 1 MΩ) resistor for each sensor (from analog pin to GND)

0.01 µF (10 nF) ceramic capacitor for each sensor (from analog pin to GND)

Breadboard or solderable perfboard

Jumper wires

Computer with Processing installed



How It Works:

The piezo converts physical vibration into voltage spikes.

The Arduino reads those spikes, filters them, and sends numerical intensity data.

Processing translates that data into sound — the stronger the tap, the louder and wetter the reverb.

Up to 5 sensors can be active, each mapped to a different sound file.


This project is released under the MIT License.
Feel free to remix, and use it for your own installations or performances.
If you build on it, please credit:
Teresa Wang – Cubison (2025)
