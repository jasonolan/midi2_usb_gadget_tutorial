#!/bin/bash

# 2. Find the WM8960 card index dynamically
CARD_ID=$(aplay -l | grep -i "wm8960" | cut -d' ' -f2 | tr -d ':')
AUDIO_DEV=${CARD_ID:-0}

# 4. Wait for BOTH FluidSynth AND the Gadget UMP ports to be visible
echo "Waiting for MIDI ports to initialize..."

for i in {1..10}; do
    # Check for the MIDI 2.0 Gadget UMP Group 1
    GADGET_PORT=$(aconnect -l | grep "MIDI 2.0 Gadget" | grep "Group 1")
    # Check for the FluidSynth ALSA client
    FLUID_PORT=$(aconnect -l | grep "FLUID Synth")
    if [ ! -z "$GADGET_PORT" ] && [ ! -z "$FLUID_PORT" ]; then
        echo "Ports found. Establishing bridge..."
        break
    fi
    sleep 1
done

# 5. Connect Gadget (MIDI 2.0/UMP) to FluidSynth (MIDI 1.0)
# ALSA handles the UMP -> MIDI 1.0 translation automatically here.
aconnect "MIDI 2.0 Gadget":1 "FLUID Synth":0

echo "Success: MIDI 2.0 Gadget connected to FluidSynth."