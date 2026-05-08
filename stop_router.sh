#!/bin/bash

# Load configuration
CONF_FILE="$(dirname "$0")/srouter.conf"

if [ -f "$CONF_FILE" ]; then
    source "$CONF_FILE"
    echo "Configuration loaded from $CONF_FILE."
else
    echo "Error: $CONF_FILE not found. Cannot determine interfaces."
    exit 1
fi

echo "1. Stopping services..."
systemctl stop isc-dhcp-server hostapd nftables dnsmasq 2>/dev/null
systemctl disable isc-dhcp-server hostapd nftables dnsmasq 2>/dev/null
pkill -9 hostapd 2>/dev/null
pkill -9 wpa_supplicant 2>/dev/null


echo "Cleaning Wi-Fi interfaces..."
TARGET_INTERFACES=("$WIFI_IFACE" "$WAN_IFACE")

for iface in "${TARGET_INTERFACES[@]}"; do
    if [ -n "$iface" ] && [ -d "/sys/class/net/$iface" ]; then
        echo " - Cleaning $iface..."
        sudo ip addr flush dev "$iface"
        sudo ip link set "$iface" down
    fi
done

echo "3. Flushing Firewall rules (nftables)..."
sudo nft flush ruleset 2>/dev/null

echo "4. Disabling IP Forwarding..."
sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null

echo "5. Releasing DHCP leases..."
sudo rm -f /var/lib/dhcp/dhcpd.leases 2>/dev/null

# Final choice menu
echo "---------------------------------------"
echo "Cleanup complete. What would you like to do now? :"
echo "---------------------------------------"
echo "3) Power off"
echo "2) Reboot"
echo "1) Exit (do nothing)"
read -p "Select an option [1-3]: " choice

case $choice in
    3)
        echo "Shutting down..."
        shutdown now
        ;;
    2)
        echo "Rebooting..."
        reboot
        ;;
    1)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid option. Exiting by default."
        exit 0
        ;;
esac
