#!/bin/bash

printf "\033c"
echo "=================================================="
echo "       DARKOS DESKTOP INSTALLER v0.1 (Alpha)      "
echo "        (The \"Everything Works\" Edition)        "
echo "=================================================="
echo -e "\033[0;32m"
echo "        _____  _       _ _______        _         "
echo "       / ____|(_)     | |__   __|      | |        "
echo "      | (___   _ ___  | |  | | ___  ___| |__      "
echo "       \___ \ | / __| | |  | |/ _ \/ __| '_ \     "
echo "       ____) || \__ \ | |  | |  __/ (__| | | |    "
echo "      |_____/ | |___/ |_|  |_|\___|\___|_| |_|    "
echo "             _/ |                                 "
echo "            |__/                                  "
echo -e "\033[0m"
echo "=================================================="
sleep 2

# 1. Update and Install
echo "--- Step 1: Installing core components ---"
sudo apt-get update -y
sudo apt-get install xfce4 xfce4-terminal xorg xdotool python3-evdev dbus-x11 onboard alsa-utils -y

# 2. Optimized Mouse Driver
echo "--- Step 2: Creating Mouse Driver ---"
cat << 'EOF' | sudo tee /usr/local/bin/r36s-mouse.py > /dev/null
import evdev, os, threading, time
from evdev import ecodes

time.sleep(5)
os.environ["DISPLAY"] = ":0"
os.environ["XAUTHORITY"] = "/home/ark/.Xauthority"

device = evdev.InputDevice("/dev/input/event2")
state = {"lx": 0, "ly": 0, "rx": 0, "ry": 0}

def move_loop():
    while True:
        mx, my = 0, 0
        if abs(state["lx"]) > 500 or abs(state["ly"]) > 500:
            mx += int(state["lx"] * 0.5); my += int(state["ly"] * 0.5)
        if abs(state["rx"]) > 500 or abs(state["ry"]) > 500:
            mx += int(state["rx"] * 0.24); my += int(state["ry"] * 0.24)
        if mx != 0 or my != 0:
            os.system(f"xdotool mousemove_relative -- {int(mx/100)} {int(my/100)}")
        time.sleep(0.01)

threading.Thread(target=move_loop, daemon=True).start()

for event in device.read_loop():
    if event.type == ecodes.EV_KEY:
        # Mouse Buttons
        if event.code == 312: # L2
            os.system("xdotool mousedown 1") if event.value == 1 else os.system("xdotool mouseup 1")
        elif event.code == 313: # R2
            os.system("xdotool mousedown 3") if event.value == 1 else os.system("xdotool mouseup 3")
        
        # Mouse Wheel (Scroll)
        elif event.code == 310 and event.value == 1: # L1
            os.system("xdotool click 4")
        elif event.code == 311 and event.value == 1: # R1
            os.system("xdotool click 5")

        # D-Pad to Arrow Keys
        elif event.value == 1: # Only trigger on press
            if event.code == 544: os.system("xdotool key Up")
            elif event.code == 545: os.system("xdotool key Down")
            elif event.code == 546: os.system("xdotool key Left")
            elif event.code == 547: os.system("xdotool key Right")
            
            # System Keys
            elif event.code == 704: os.system("xdotool key Escape") # Select
            elif event.code == 705: os.system("xdotool key Return") # Start            
            # ABXY Face Buttons
            elif event.code == 305: os.system("xdotool key space")     # A
            elif event.code == 304: os.system("xdotool key BackSpace") # B
            elif event.code == 307: os.system("xdotool key Tab")       # X
            elif event.code == 308: os.system("xdotool key Super_L")   # Y

    elif event.type == ecodes.EV_ABS:
        if event.code == 0: state["lx"] = event.value
        elif event.code == 1: state["ly"] = event.value
        elif event.code == 3: state["rx"] = event.value
        elif event.code == 4: state["ry"] = event.value
EOF


# 3. Terminal, Permissions, & Xwrapper Fix
echo "--- Step 3: Fixing Terminal and X Server permissions ---"
sudo update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper
echo "allowed_users=anybody" | sudo tee /etc/X11/Xwrapper.config
echo "needs_root_rights=yes" | sudo tee -a /etc/X11/Xwrapper.config
sudo usermod -a -G tty,video,input,render,audio ark
sudo chmod u+s /usr/lib/xorg/Xorg.wrap

# 4. AUDIO FIX
echo "--- Step 4: Configuring Audio Routing ---"
cat << 'EOF' > /home/ark/audio_fix.sh
#!/bin/bash
# Kill PulseAudio as it interferes with ALSA hardware
pulseaudio -k 2>/dev/null
sleep 1
# Force Hardware Switches
amixer -c 0 cset name='Master Playback Switch' on 2>/dev/null
amixer -c 0 cset name='Master Playback Volume' 65536 2>/dev/null
amixer -c 0 cset name='Internal Speaker Switch' on 2>/dev/null
amixer -c 0 cset name='Speaker Playback Switch' on 2>/dev/null
amixer -c 0 cset name='HPO L Switch' on 2>/dev/null
amixer -c 0 cset name='HPO R Switch' on 2>/dev/null
# Pulse fallback unmute
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null
pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
EOF
chmod +x /home/ark/audio_fix.sh

# 5. Create Shortcuts and Autostart
echo "--- Step 5: Finalizing Shortcuts and Autostart ---"
mkdir -p /home/ark/.config/autostart
echo -e "[Desktop Entry]\nType=Application\nExec=python3 /usr/local/bin/r36s-mouse.py\nName=Mouse" > /home/ark/.config/autostart/mouse.desktop
echo -e "[Desktop Entry]\nType=Application\nExec=sh -c 'sleep 5 && dbus-launch onboard'\nName=Onboard" > /home/ark/.config/autostart/onboard.desktop
echo -e "[Desktop Entry]\nType=Application\nExec=/home/ark/audio_fix.sh\nName=AudioFix" > /home/ark/.config/autostart/audio.desktop

mkdir -p /home/ark/Desktop
cat << 'EOF' > /home/ark/Desktop/Exit.desktop
[Desktop Entry]
Type=Application
Name=Exit to ES
Exec=sudo systemctl stop desktop.service
Icon=application-exit
Terminal=false
EOF

sudo chown -R ark:ark /home/ark/
sudo chmod -R 755 /home/ark/
sudo chmod +x /home/ark/Desktop/Exit.desktop /usr/local/bin/r36s-mouse.py

# 6. The Master Service
echo "--- Step 6: Setting up Desktop Service ---"
cat << 'EOF' | sudo tee /etc/systemd/system/desktop.service > /dev/null
[Unit]
Description=XFCE Desktop
[Service]
Type=simple
User=ark
WorkingDirectory=/home/ark
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/ark/.Xauthority
ExecStartPre=-/usr/bin/sudo /usr/bin/systemctl stop emulationstation
ExecStartPre=-/usr/bin/sudo /usr/bin/rm -f /tmp/.X0-lock
ExecStart=/usr/bin/startx /usr/bin/startxfce4 -- :0 vt1
ExecStopPost=-/usr/bin/sudo /usr/bin/systemctl start emulationstation
[Install]
WantedBy=multi-user.target
EOF

# Tool Shortcut
echo "sudo systemctl start desktop.service" | sudo tee /roms/tools/Desktop.sh > /dev/null
sudo chmod +x /roms/tools/Desktop.sh
sudo systemctl daemon-reload

echo "DONE! dArkOS Desktop Installed! Rebooting..."
sleep 3
sudo reboot
