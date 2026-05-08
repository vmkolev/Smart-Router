#!/bin/bash

# ===== VARIABLES =====

BASE_DIR="$(dirname "$0")"
CONF_FILE="$BASE_DIR/srouter.conf"
# If you have FireWall and rules to be applied
NFT_RULES="$BASE_DIR/fw.rules.nft"

# ===== HELPERS =====

# Check for root privileges
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (sudo)!"
        exit 1
    fi
}

# Load variables from the config file
load_config() {
    if [[ -f "$CONF_FILE" ]]; then
        source "$CONF_FILE"
        echo "ℹ️ Configuration file loaded successfully."
    else
        echo "❌ Error: Configuration file $CONF_FILE not found!"
        exit 1
    fi
}

# ===== INSTALL PACKAGES AND CONFIGURE SERVICES =====

# Install required packages if they are missing
install_packages() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Step 1: Checking and installing packages..."
    local packages=(hostapd dnsmasq iptables iw nftables)
    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -ne 0 ]; then
        echo "🔄 Installing missing packages: ${to_install[*]}..."
        apt update && apt install -y "${to_install[@]}"
    else
        echo "✔️ All required packages are already installed."
    fi
}

# Generate configuration files for hostapd and dnsmasq
create_configs() {
    echo "📝 Step 2: Creating configuration files..."

    # 2.1. Hostapd configuration
    echo "📡 Setting up hostapd.conf..."
    cat <<EOF > /etc/hostapd/hostapd.conf
interface=$WIFI_IFACE
driver=nl80211
ssid=$SSID
ignore_broadcast_ssid=1
hw_mode=g
channel=$CHANNEL
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOF
    grep "^WIFI_PASS=" "$CONF_FILE" | sed 's|^WIFI_PASS=|wpa_passphrase=|' >> /etc/hostapd/hostapd.conf

    # Point to hostapd config in default settings
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

    # 2.2. Dnsmasq configuration
    echo "🌐 Setting up dnsmasq.conf..."
    cat <<EOF > /etc/dnsmasq.conf
interface=$WIFI_IFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$NETMASK,24h
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$GATEWAY_IP
server=8.8.8.8
server=1.1.1.1
log-dhcp
EOF

    # 2.3. Add static DHCP leases from config
    echo "📌 Adding static DHCP leases..."
    for var in $(compgen -v LEASE_); do
        value="${!var}"
        # format: MAC,HOSTNAME,IP
        echo "dhcp-host=$(echo "$value" | cut -d',' -f1,2,3)" >> /etc/dnsmasq.conf
    done
}

# ===== NETWORK CONFIG =====

# Configure interfaces, routing, and firewall based on choice
configure_network() {
    local source_mode=$1  # 1 for iPhone, 2 for Cable
    local ACTIVE_WAN=""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔌 Configuring network interfaces..."

    # Common steps for both modes
    modprobe rt2800usb
    ip addr flush dev "$WIFI_IFACE" 2>/dev/null
    ip addr add "$GATEWAY_IP/24" dev "$WIFI_IFACE"
    ip link set "$WIFI_IFACE" up

    if [ "$source_mode" = "1" ]; then
        echo "📱 Mode: INTERNET FROM IPHONE ($WAN_IFACE)"
        # if pass contains special characters like $ for example Th1$_i$_ex@mP1e ::
        # I did not find other way to do it but like this :
        wpa_passphrase "$HOT_SPOT" "$HOT_SPOT_PASS" | sudo tee /etc/wpa_supplicant/wpa_supplicant-wlp2s0.conf > /dev/null
        
        # Bring up iPhone interface
        ifup "$WAN_IFACE" 2>/dev/null
        
        # This keeps the cable active but prevents it from being used for Internet
        ip route del default dev "$CABLE_IFACE" 2>/dev/null || true
        
        ACTIVE_WAN="$WAN_IFACE"
    else
        echo "🔌 Mode: INTERNET FROM CABLE ($CABLE_IFACE)"
        # Disable iPhone to avoid interference
        ip link set "$WAN_IFACE" down 2>/dev/null
        
        # IP and restore the default gateway we deleted earlier.
        echo "🔄 Restoring Cable interface and routes..."
        ifdown "$CABLE_IFACE" 2>/dev/null
        ifup "$CABLE_IFACE" 2>/dev/null
        
        ACTIVE_WAN="$CABLE_IFACE"
    fi

    # 4.1. Enable IP Forwarding
    echo "🔀 Enabling IP Forwarding..."
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-router.conf

    # 4.2. Apply Firewall (nftables)
    echo "🧱 Updating Firewall rules for $ACTIVE_WAN..."
    cat <<EOF > /tmp/nft_vars.nft
define WIFI_AP_IFACE = "$WIFI_IFACE"
define WAN_IFACE = "$ACTIVE_WAN"
EOF

    if nft -f "$NFT_RULES"; then
        echo "✅ Firewall applied successfully."
    else
        echo "❌ Error applying nftables rules!"
    fi
    rm -f /tmp/nft_vars.nft
}

# Restart system services
start_services() {
    echo "🚀 Restarting services..."
    systemctl unmask hostapd 2>/dev/null
    systemctl restart hostapd dnsmasq
}

# ===== MAIN CODE =====

check_root
load_config

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Smart Router Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Select Internet Source:"
echo "1) Use iPhone (Mobile Net)"
echo "2) Use LAN Cable (Ethernet)"
read -p "Make your choice [1-2]: " choice

case $choice in
    1|2)
        install_packages
        create_configs
        configure_network "$choice"
        start_services
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 ALL CLEAR! Your router is now online."
        echo "ℹ️  SSID: $SSID (Hidden)"
        echo "ℹ️  Gateway IP: $GATEWAY_IP"
        echo "ℹ️  DHCP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    *)
        echo "❌ Invalid choice! Canceling..."
        exit 1
        ;;
esac