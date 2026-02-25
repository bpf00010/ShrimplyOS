#!/usr/bin/env bash
# 🦐 Shrimply OS: TUI Fallback 🦐

TITLE="🦐 Shrimply OS: The Dark Abyss 🦐"
BACKTITLE="Shrimply OS - TUI Mode"

whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
    --msgbox "Welcome to the TUI, bottom-feeder.\n\nSystem resources are conserved. You may now navigate the filesystem using standard GNU/Linux utilities.\n\nTo ascend to the Coral Reef later, run:\n  systemctl isolate graphical.target" 12 60

# Drop to a standard bash shell
exec /bin/bash
