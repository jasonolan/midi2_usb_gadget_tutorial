
This is part 1 in a 2 part tutorial series covering Midi 2.0 Gadget Mode and being able to send Midi 2 messages to trigger notes being received within Fluidsynth.

Part 1 will cover everything around Midi 2.0 USB Gadget Kernel within Linux, building the kernel and setting up gadget mode for Midi 2.0. It also engages ALSA libraries and utilities.

Part 2 looks into setting up the audio HAT and drivers, installing Fluidsynth and running it as a service on boot. It also provides the Midibridge script to Midi connect the gadget driver to Fluidsynth. 
# Part 1 - All things kernel
## Introduction
It's exciting times with the headway that Midi 2.0 is making. The standard is released, there are a handful commercially available products emerging, and there are some great development resources available at https://midi2.dev/ or https://github.com/midi2-dev. 
Not to mention that Mac OS, Linux and now Windows all support Midi 2.0. Particularly Linux in this case, where Midi 2.0 can be used in USB gadget mode. What is USB Gadget mode you ask? - it’s where a device like the Pi Zero 2W acts as a USB peripheral (network adapter, keyboard, etc.) instead of a usb host. 

A great resource for all things Midi 2.0 on Linux : https://docs.kernel.org/sound/designs/midi-2.0.html, and kudos to Takashi Iwai (https://github.com/tiwai) for making this a reality.  But I digress, lets get to our practical Midi 2.0  USB Gadget. 
## The Goal
Our goal is to be able to send Midi 2.0 messages to the Pi Zero 2W that plays musical notes through an attached Pi Zero 2W audio hat. Seems simple enough. I have not seen any examples of such a setup publicly available so thought to build, document and share it.
[Fluidsynth](https://www.fluidsynth.org/) is used as the sound generator, and the Midi 2.0 to Midi 1.0 translation is used within the Midi 2.0 Linux kernel. Midi 2.0 Channel Voice (Note On and Note Off) messages are used with no attribute types specified. 

(Future efforts could see the replacement of Fluidsynth with Pure Data. A custom Pure Data module interprets Midi 2.0 CV that would include per note expression. All this on a Raspberry PI)

At the end of part 2 there is a list of Linux and ALSA commands to make navigating Midi 2.0 on Linux a little easier. 

![[Pasted image 20260121091350.png]]
## What you need
The aim is to use commonly available hardware and open source software to build a Midi 2.0 USB Gadget. 
### Hardware
You will need the following:
- Raspberry PI  Zero 2W
- A PI Zero audio hat. In this tutorial we use the [Waveshare WM8960 Audio HAT](https://www.waveshare.com/wiki/WM8960_Audio_HAT)

![[2E3A2982-8E50-4F42-A27E-FC265949EF3D_1_105_c.jpeg]]
What is nice about the WM8960 is that it includes a small set of speakers with the hat. Nice for a standalone testing unit. 

(The epaper display is intended to be used for displaying incoming Midi 2.0 messages but not implemented here )
### Software
- Linux kernel 6.5  or greater
- drivers for the audio hat
- Fluidsynth
- python for the midibridge script that connects the M2.0 USB Gadget to Fluidsynth

## Step 1 - Download, install the PI OS, update and upgrade

Using [Raspberry PI Imager](https://www.raspberrypi.com/software/) install:
- Raspberry PI OS Lite (32 bit) under Raspberry PI OS (Other) menu
Make sure to enable SSH service as we will use this later once we switch to gadget mode.

Why the lite version and 32 bit? 
With the limited resources on the Pi Zero 2W, the lite versions skips the desktop bloat, and 32 bit reduces the memory overhead.

Update packages
```
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Lets see which kernel we have:
```
uname -r
```
 
returns  
*6.12.62+rpt-rpi-v7* 
*(at the time of writing for the Raspberry PI OS Lite (32 bit)*

That looks promising with a kernel greater than 6.5 for Midi 2.0 support. 
Lets see if the kernel has support for Midi 2.0 and UMP

```
grep -E 'CONFIG_SND_(UMP|SEQ_UMP|USB_AUDIO_MIDI_V2)' /boot/config-$(uname -r)
```

returns
*CONFIG_SND_SEQ_UMP is not set*
*CONFIG_SND_USB_AUDIO_MIDI_V2 is not set*

Not so promising anymore. 
The `f_midi2` driver provides the USB Midi 2.0 Gadget functionality.

```
sudo modprobe f_midi2
```
returns
*modprobe: FATAL: Module f_midi2 not found in directory /lib/modules/6.12.62+rpt-rpi-v7*

```
lsmod | grep midi2
```
returns nothing

Lastly, 
```
find /lib/modules/$(uname -r) -name 'usb_f_midi2.ko*'
```
also return nothing.

Despite the kernel being greater than 6.5, the UMP and Midi 2.0 drivers are not present. 

We therefore need to build the kernel to include the `f_midi2` driver and support for UMP and Midi 2.0

## Step 2 - Build the kernel modules for Midi 2.0  and UMP

This is the hardest part so lets do that first, so that after this step its plane sailing with blue skies. 

Install Raspberry Pi kernel build tools: 
```
sudo apt install git bc bison flex libssl-dev make libncurses-dev pkg-config
```

Clone the Rapsberry PI Linux repo
```
mkdir ~/gits 
cd ~/gits
git clone --depth=1 -b rpi-6.12.y https://github.com/raspberrypi/linux
cd linux
```

```
make bcm2709_defconfig
```

Enable f_midi2
```
make menuconfig
```

Navigate and enable/select:
```
Device Drivers
  → USB support
    → USB Gadget Support
      → USB Gadget functions configurable through configfs
        → [y] MIDI 2.0 function
```

also
```bash
Device Drivers
  → Sound card support
    → Advanced Linux Sound Architecture
      → Sequencer support
        → [y] Support for UMP Events
```
Lastly
```bash
Device Drivers
  → Sound card support
    → Advanced Linux Sound Architecture
	    → [*] Legacy RAW Midi support for UMP streams
```


>- `CONFIG_SND_USB_AUDIO_MIDI_V2=y` – Enables USB MIDI 2.0 devices.
>- `CONFIG_SND_UMP=y` – Core support for Universal MIDI Packet (UMP).
>- `CONFIG_SND_SEQ_UMP_CLIENT=y` – ALSA sequencer binding for UMP.
>- `CONFIG_SND_UMP_LEGACY_RAWMIDI=y` – Enables legacy raw MIDI device support.


```
make olddefconfig  # Apply defaults for any new options
scripts/config --file .config -e USB_CONFIGFS_F_MIDI2  # Enable f_midi2 as module
scripts/config --file .config -e USB_CONFIGFS  # Ensure configfs
scripts/config --file .config -e USB_GADGET  # USB gadget support
scripts/config --file .config -e SND_USB_AUDIO  # For ALSA integration (optional but recommended)
make menuconfig  # Optional: Launch ncurses menu to verify (Device Drivers > USB support > USB Gadget Support > MIDI Gadget v2 should be <M>)
```

Save and exit.

Now build it:

```
make -j4
```
Running on the poor PI Zero 2W this takes a good long time! Get some coffee, and when you return it won’t be done. Overnight is better. 

Then install the modules (while still in the ~/gits/linux directory):
```
sudo make modules_install
```

Verify with: (replace kernel version as needed)
```
find /lib/modules/6.12.66-v7+ -name *f_midi2.ko*
find /lib/modules/6.12.66-v7+ -name *ump*.ko*
```
If all went well, it should show the files.
*/lib/modules/6.12.66-v7+/kernel/drivers/usb/gadget/function/usb_f_midi2.ko.xz*
*/lib/modules/6.12.66-v7+/kernel/sound/core/seq/snd-seq-ump-client.ko.xz*
*/lib/modules/6.12.66-v7+/kernel/sound/core/snd-ump.ko.xz*

Backup before installing the newly built modules:
```
sudo cp /boot/firmware/kernel7.img /boot/firmware/kernel7-backup.img
```

Next up, install the kernel (from the ~/gits/linux directory)
```
sudo cp arch/arm/boot/zImage /boot/firmware/kernel7.img
sudo cp arch/arm/boot/dts/broadcom/*.dtb /boot/firmware/
sudo cp arch/arm/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
```

and edit `/boot/firmware/config.txt` and ensure that 
```
kernel=kernel7.img
arm_64bit=0
```
for the 32 bit kernel.

Then reboot...

Verify the new kernel:
```
uname -r
```
returns
*6.12.66-v7+*

Regenerate module dependency maps:
```
sudo depmod -a
```

and 
```
sudo modprobe usb_f_midi2
sudo modprobe snd_seq_ump_client
sudo modprobe snd_ump
```

No errors...then we are good. 

Verify with:
```
lsmod | grep midi
```
returns
*usb_f_**midi**2            40960  2*
*snd_ump                24576  1 usb_f_**midi**2*
*snd_raw**midi**            36864  2 snd_seq_ump_client,snd_ump*
*snd_seq_device         12288  4 snd_seq_ump_client,snd_seq,snd_raw**midi**,snd_ump*
*libcomposite           65536  10 usb_f_**midi**2*
*snd                    94208  11 snd_compress,usb_f_**midi**2,snd_seq,snd_soc_hdmi_codec,snd_timer,snd_raw**midi**,snd_seq_device,snd_bcm2835,snd_soc_core,snd_ump,snd_pcm*

and 
```
modinfo usb_f_midi2
```
returns

*filename:       /lib/modules/6.12.66-v7+/kernel/drivers/usb/gadget/function/usb_f_midi2.ko.xz*
*license:        GPL*
*description:    USB MIDI 2.0 class function driver*
*alias:          usbfunc:midi2*
*srcversion:     94C030B8C48311102E8920B*
*depends:        snd,libcomposite,snd-ump*
*intree:         Y*
*name:           usb_f_midi2*
*vermagic:       6.12.66-v7+ SMP mod_unload modversions ARMv7 p2v8*


Confirm configfs is mounted
```
mount | grep configfs
```
and if not then
```
sudo mount -t configfs none /sys/kernel/config
```

We have officially cleared the hardest part!! The kernel dragon is slain!!

## Step3 - Setup and test USB Gadget Mode
Enabled USB Gadget Mode for Midi 2.0
edit `/boot/firmware/config.txt` to include
```
dtoverlay=dwc2,dr_mode=peripheral
```

and also `/boot/firmware/cmdline.txt` (add after `rootwait` in the same line)
```
modules-load=dwc2
```

reboot again....

Load and setup USB gadget with a systemd script to persist it. 

Create the USB gadget startup script
```
sudo tee /usr/local/bin/start-midi2-gadget.sh > /dev/null <<'EOF'
#!/bin/bash
set -e
modprobe libcomposite
modprobe usb_f_midi2

# Wait for USB controller
while [ -z "$(ls /sys/class/udc 2>/dev/null)" ]; do
    echo "Waiting for UDC..."
    sleep 0.5
done

cd /sys/kernel/config/usb_gadget

G=/sys/kernel/config/usb_gadget/midi2_gadget

# ---- Clean up if gadget exists ----
if [ -d "$G" ]; then
    # Unbind if bound
    if [ -f "$G/UDC" ]; then
        echo "" > "$G/UDC" || true
    fi

    # Remove function symlinks and functions
    rm -f "$G/configs/c.1/midi2.usb0" 2>/dev/null || true
    rmdir "$G/functions/midi2.usb0" 2>/dev/null || true

    # Remove configs
    rmdir "$G/configs/c.1/strings/0x409" 2>/dev/null || true
    rmdir "$G/configs/c.1" 2>/dev/null || true

    # Remove strings
    rmdir "$G/strings/0x409" 2>/dev/null || true

    # Finally remove gadget folder
    rmdir "$G" 2>/dev/null || true
fi


# ---- Create gadget ----
mkdir "$G"
cd "$G"

echo 0x1d6b > idVendor
echo 0x0104 > idProduct

mkdir -p strings/0x409
echo "1234567890" > strings/0x409/serialnumber
echo "M2 USB Gadget" > strings/0x409/product
echo "Nubbsoft" > strings/0x409/manufacturer

mkdir -p configs/c.1/strings/0x409
echo "MIDI 2.0 UMP" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower

mkdir -p functions/midi2.usb0
echo 1 > functions/midi2.usb0/ump_endpoint
ln -s functions/midi2.usb0 configs/c.1/

# ---- Bind gadget ----
ls /sys/class/udc > UDC
EOF
```

It is also possible to download this script [start-midi2-gadget.sh](midi2-gadget/start-midi2-gadget.sh) to place in `/usr/local/bin/`

```
sudo chmod +x /usr/local/bin/start-midi2-gadget.sh
```

And create a systemd service for persistance
```
sudo tee /etc/systemd/system/midi2-gadget.service > /dev/null <<'EOF' 
[Unit] 
Description=RPi Zero 2W USB MIDI 2.0 UMP Gadget 
After=local-fs.target systemd-modules-load.service
Wants=systemd-modules-load.service

[Service] 
Type=oneshot 
RemainAfterExit=yes 
ExecStart=/bin/bash /usr/local/bin/start-midi2-gadget.sh

[Install] 
WantedBy=multi-user.target 
EOF
```

It is also possible to download this script [midi2-gadget.service](midi2-gadget/midi2-gadget.service) to place in `/etc/systemd/system/`

```
sudo systemctl daemon-reload 
sudo systemctl enable --now midi2-gadget.service
```

and reboot.

Be sure to use the USB/OTG port on the Pi Zero. Test usb gadget mode
```
cat /proc/asound/cards  # Lists "MIDI 2.0 Gadget" as a card
```

```
aconnect -l              # Shows UMP rawmidi ports
```
returns
client 0: 'System' [type=kernel]
    0 'Timer           '
    1 'Announce        '
client 14: 'Midi Through' [type=kernel]
    0 'Midi Through Port-0'
client 20: 'MIDI 2.0 Gadget' [type=kernel,UMP-MIDI2,card=1]
    0 'MIDI 2.0        '
    1 'Group 1 (MIDI 2.0 Gadget I/O)'
## Step 4 - Install ALSA libraries and utilities
	
Install alsa libraries and utilities (alsa-lib ≥1.2.10 and alsa-utils ≥1.2.10)
```
sudo apt install alsa-utils libasound2-dev # libasound2-dev pulls recent alsa-lib
```

## End of part 1
This concludes part 1 of the series where we did all the real tough work of building the kernel modules for Midi 2.0 and UMP, as well as setting up and testing the USB Gadget Mode. We finished by installing the ALSA libraries and utilities.

In part 2 we will follow on by installing Fluidsynth and running it as a systemd service. We will install the audio drivers and lastly the midibridge script to automatically connect the Midi 2.0 USB Gadget Driver to Fluidsynth. 