#!/bin/bash
########################################################################################################
# ______    _______  __   __  _______  _______  ______      _______  _______  _______  __   __  _______ 
#|    _ |  |       ||  | |  ||       ||       ||    _ |    |       ||       ||       ||  | |  ||       |
#|   | ||  |   _   ||  | |  ||_     _||    ___||   | ||    |  _____||    ___||_     _||  | |  ||    _  |
#|   |_||_ |  | |  ||  |_|  |  |   |  |   |___ |   |_||_   | |_____ |   |___   |   |  |  |_|  ||   |_| |
#|    __  ||  |_|  ||       |  |   |  |    ___||    __  |  |_____  ||    ___|  |   |  |       ||    ___|
#|   |  | ||       ||       |  |   |  |   |___ |   |  | |   _____| ||   |___   |   |  |       ||   |    
#|___|  |_||_______||_______|  |___|  |_______||___|  |_|  |_______||_______|  |___|  |_______||___|    
#
# FILE: lid-ignore.sh
# PART OF: Smart Router Project
#
# WARNING !!!  Use this script only if you are using laptop
#  
########################################################################################################

# Check if the script is being run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script with sudo or as root!"
  exit 1
fi

FILE="/etc/systemd/logind.conf"
BACKUP_FILE="${FILE}.bak"

echo "⚙️ Starting configuration of lid-close behavior..."

# 1. Create a backup file if one doesn't already exist
if [ ! -f "$BACKUP_FILE" ]; then
    cp "$FILE" "$BACKUP_FILE"
    echo "💾 Original file backed up to: $BACKUP_FILE"
fi

# 2. Function to modify or add configuration settings
update_config() {
    local key=$1
    local value=$2
    
    # If the line exists (commented or not), replace it
    if grep -q "^#\?$key=" "$FILE"; then
        sed -i "s|^#\?$key=.*|$key=$value|" "$FILE"
    else
        # If the key doesn't exist at all, append it to the end
        echo "$key=$value" >> "$FILE"
    fi
}

# 3. Apply settings to ignore the lid switch
update_config "HandleLidSwitch" "ignore"
update_config "HandleLidSwitchExternalPower" "ignore"
update_config "HandleLidSwitchDocked" "ignore"

echo "📝 Settings in $FILE have been successfully updated."

# 4. Restart the logind service to apply changes
echo "🔄 Restarting systemd-logind service..."
systemctl restart systemd-logind

echo "✅ No more sleep when lid is closed."
