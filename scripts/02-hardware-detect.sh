#!/usr/bin/env bash
# 🦐 Shrimply OS: Hardware Detection & UI Handoff 🦐

# Crustacean Motif UI Variables
TITLE="🦐 Shrimply OS: Molting Phase 🦐"
BACKTITLE="Shrimply OS - Bottom-Feeder Configuration Utility"

# Detect NVIDIA GPU via PCI Vendor ID (10de)
if lspci -nn | grep -i vga | grep -iq "10de"; then
    if whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
        --yesno "Ahoy, fellow bottom-feeder! Our antennae have detected a shiny NVIDIA carapace attached to your motherboard.\n\nShall we graft the proprietary NVIDIA drivers to your exoskeleton for maximum graphical current?" 12 60; then
        
        whiptail --title "$TITLE" --infobox "Initiating molting process... Fetching proprietary algae (drivers)..." 8 50
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y nvidia-driver firmware-misc-nonfree
        
        whiptail --title "$TITLE" --msgbox "Grafting complete! Your shell is now hardware-accelerated." 8 50
    else
        whiptail --title "$TITLE" --msgbox "Understood. We shall rely on the open-source Nouveau current instead. Keep your swimmerets crossed!" 8 50
    fi
fi

# XFCE vs TUI Handoff
if whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --yesno "Do you wish to ascend from the murky depths of the terminal and enter the XFCE Coral Reef (Graphical Interface)?" 10 60; then

    if ! command -v xfce4-session >/dev/null 2>&1 || ! command -v startxfce4 >/dev/null 2>&1; then
        whiptail --title "$TITLE" --infobox "Preparing the XFCE Coral Reef packages..." 8 50
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y xserver-xorg xserver-xorg-video-all xserver-xorg-input-all mesa-utils xfce4 xinit dbus-x11 lightdm lightdm-gtk-greeter
    fi
    
    whiptail --title "$TITLE" --infobox "Summoning LightDM... Prepare your compound eyes." 8 50
    if [[ "$(cat /proc/1/comm 2>/dev/null)" == "systemd" ]]; then
        systemctl isolate graphical.target
    else
        dbus-run-session startxfce4
    fi
else
    whiptail --title "$TITLE" --msgbox "Remaining in the dark abyss (TUI). Happy scavenging!" 8 50
    /tmp/scripts/03-tui-fallback.sh
    exit 0
fi
