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