#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 NETWORK STATUS (ThinkPad X201 Router)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Check which interface is used for internet
DEFAULT_ROUTE=$(ip route show default | head -n 1)
GW_IP=$(echo "$DEFAULT_ROUTE" | awk '{print $3}')
INTF=$(echo "$DEFAULT_ROUTE" | awk '{print $5}')

echo "🌐 INTERNET ROUTE:"
if [ -z "$DEFAULT_ROUTE" ]; then
    echo "  🔴 No default gateway set! (No internet)"
else
    echo "  🟢 Gateway: $GW_IP via interface: **$INTF**"
    if [ "$INTF" = "wlp2s0" ]; then
        echo "  📱 Connection: Connected to iPhone (Mobile Hotspot)."
    elif [ "$INTF" = "enp0s25" ]; then
        echo "  🔌 Connection: Connected via Cable (Ethernet)."
    fi
fi

# 2. Ping test for real internet access
echo ""
echo "📡 CONNECTIVITY TEST:"
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "  🟢 Internet is UP! (Ping to 8.8.8.8 successful)"
else
    echo "  🔴 Internet is DOWN! (Ping to 8.8.8.8 failed)"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 3. Connected clients to your Wi-Fi AP
echo "👥 CONNECTED DEVICES (Clients on AP):"

# Get list of MAC addresses using the iw command
connected_macs=$(/usr/sbin/iw dev wlx00026f90e8c2 station dump | grep Station | awk '{print $2}')

if [ -z "$connected_macs" ]; then
    echo "  ⚪ No devices connected at the moment."
else
    # Read the leases file from dnsmasq
    leases_file="/var/lib/misc/dnsmasq.leases"
    
    echo -e "  MAC Address\t\tIP Address\t\tHostname"
    echo "  ----------------------------------------------------------------"
    
    for mac in $connected_macs; do
        # Search for a match in the DHCP leases
        lease_info=$(grep -i "$mac" "$leases_file" 2>/dev/null)
        
        if [ -n "$lease_info" ]; then
            ip_addr=$(echo "$lease_info" | awk '{print $3}')
            hostname=$(echo "$lease_info" | awk '{print $4}')
            echo -e "  $mac\t$ip_addr\t$hostname"
        else
            # If the device is connected to Wi-Fi but has not received an IP yet
            echo -e "  $mac\t(Awaiting IP...)\t(Unknown)"
        fi
    done
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"