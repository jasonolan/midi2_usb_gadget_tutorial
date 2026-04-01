#!/bin/bash

# 1. Kill any existing FluidSynth instances to clear the audio device
echo "Cleaning up existing FluidSynth processes..."
pkill fluidsynth
sleep 1

# 2. Find the WM8960 card index dynamically
CARD_ID=$(aplay -l | grep -i "wm8960" | cut -d' ' -f2 | tr -d ':')
AUDIO_DEV=${CARD_ID:-0}

# 3. Start FluidSynth with your specific configuration
echo "Starting FluidSynth on hw:$AUDIO_DEV,0..."
fluidsynth -si -f /home/pi/dev/fluidsynth_config/config.txt \
     -a alsa -m alsa_seq \
     -o audio.alsa.device=hw:$AUDIO_DEV,0 \
     -o audio.period-size=128 \
     -o audio.realtime-prio=99 \
     /usr/share/sounds/sf2/FluidR3_GM.sf2