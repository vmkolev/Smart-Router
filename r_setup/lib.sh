#!/usr/bin/env bash
###########################################################################
# FILE: lib.sh
# PART OF: Smart Router Project
# PURPOSE: This file contains only functions
#  If you create a new one you need to unclude it in the main script file
###########################################################################


set -euo pipefail

######################
#      PACKAGES      #
######################

packages_install_list() {
  # Read list of packages
  mapfile -t PACKAGES < ${BASE_DIR}/packages.list
  # Update & Install packages  
  apt update -y
  apt install -y "${PACKAGES[@]}"
}

packages_install_docker(){
  # Add Docker's official GPG key:
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: ${DOCKER_REPO_URL}
Suites: ${DISTRO_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.gpg
EOF

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
# Very important !!! otherwise FW will not work properly or docker network will not work either
tee /etc/docker/daemon.json <<EOF
{
  "iptables": false
}  
EOF

  systemctl daemon-reload
  if systemctl is-active --quiet docker.service; then
    systemctl restart docker.service
  else
    systemctl enable docker
    systemctl start docker.service
  fi
}

packages_check_linux(){
if [ "${DOCKER_ENG}" = "true" ]; then
    # Call function to install list of packages
    packages_install_list
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_CODENAME="${VERSION_CODENAME}"
    fi    

    if [[ "$ID" == "ubuntu" ]]; then
        DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"
    elif [[ "$ID" == "debian" ]]; then
        DOCKER_REPO_URL="https://download.docker.com/linux/debian"
    else
        echo "Unsupported distro: $ID"
        exit 1
    fi

    # Call function to install docker
    packages_install_docker
else
  echo "===> It is NON DOMUS: only the list of packages:"
  # Call function to install list of packages
  packages_install_list
fi

echo "✅ All packages are installed."
}

######################
#      NETWORK       #
######################

# Function to find the interface name and MAC address based on the IP prefix
find_interface_info() {
    local INTERFACE_NAME=""
    local MAC_ADDRESS=""
    # Find the line containing the IP address
    IP_LINE=$(ip a | grep "inet $IP_PREFIX")
    
    if [ -z "$IP_LINE" ]; then
        echo "Error: No network interface found with IP address starting with $IP_PREFIX"
        exit 1
    fi

    # Extract the interface name (last field of the line)
    INTERFACE_NAME=$(echo "$IP_LINE" | awk '{print $NF}')
    
    # Extract the MAC address (by finding the line before the IP_LINE that contains 'link/ether')
    # and extracting the second field (the MAC address)
    MAC_ADDRESS=$(ip a | grep -B 1 "inet $IP_PREFIX" | head -n 1 | awk '{print $2}')

    if [ -z "$MAC_ADDRESS" ]; then
        echo "Error: Could not retrieve MAC address for interface $INTERFACE_NAME."
        exit 1
    fi

    echo "===> Found interface: $INTERFACE_NAME (MAC: $MAC_ADDRESS)"
    export CABLE_IFACE=$INTERFACE_NAME
    export IFACE_MAC=$MAC_ADDRESS
    sed -i "s/^CABLE_IFACE=.*/CABLE_IFACE=${INTERFACE_NAME}/" "$BASE_DIR/config.conf"
    sed -i "s/^IFACE_MAC=.*/IFACE_MAC=${MAC_ADDRESS}/" "$BASE_DIR/config.conf"
}

# Function to disable IPv6 and setup statis IP
configure_network() {
# Disable IPv6
echo "===> Disable IPv6 :: "
  tee /etc/sysctl.d/99-disable-ipv6.conf >/dev/null <<'EOF'
# Disable IPv6 globally
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl --system >/dev/null

    # Remove DHCP
    echo "=== Removing DHCP from $CABLE_IFACE ==="
    sed -i "s/^iface $CABLE_IFACE inet dhcp/#&/" /etc/network/interfaces
    sed -i "s/^iface $CABLE_IFACE inet6 auto/#&/" /etc/network/interfaces
}

# Function to setup single IP address
set_ip_address(){
# Set IP address
echo "===> Set IP address :: "
  mkdir -p /etc/network/interfaces.d
  cat > /etc/network/interfaces.d/${CABLE_IFACE} <<EOF
auto ${CABLE_IFACE}
iface ${CABLE_IFACE} inet static
    address ${HOST_IP}
    netmask ${NETMASK}
    gateway ${GATEWAY}
    dns-nameservers ${DNS1} ${DNS2}
EOF

systemctl restart networking
}

# Function to set proper DNS servers
set_dns(){
# Set DNS
echo "===> Set DNS :: "
  if ! dpkg -s resolvconf &>/dev/null && [[ ! -L /etc/resolv.conf ]]; then
    echo "nameserver $DNS1" > /etc/resolv.conf
    echo "nameserver $DNS2" >> /etc/resolv.conf
  fi
}

######################
#   USERS and SSH    #
######################

create_user() {
  local USERNAME="$1"
  local USER_UID="$2"
  local USER_GID="$3"
  
  if [ -z "$USERNAME" ]; then
    echo " *** ERROR: Please point the user."
    return 1
  fi

  # If user exist
  if ! id "$USERNAME" &>/dev/null; then
    echo "===> Create :" ${USERNAME}
      # If UID and GID are empty
      if [ -z "$USER_UID" ] || [ -z "$USER_GID" ]; then
        echo " *** WARN: UID/GID are empty - will gen ID's."
        useradd -m -s /bin/bash "$USERNAME"
      else
        getent group "$USER_GID" >/dev/null || groupadd -g "$USER_GID" "$USERNAME"
        # If UID and GID are given and user does not exit then it will be created
        if ! id -u "$USERNAME" &>/dev/null; then
          useradd -u "$USER_UID" -g "$USER_GID" -m -s /bin/bash "$USERNAME"
        fi
      fi
  else
    echo " *** WARN: User ${USERNAME} exist"
  fi

  mkdir -p /home/$USERNAME/.ssh
  cp -f ${BASE_DIR}/keys/${USERNAME}_id_ed25519* /home/$USERNAME/.ssh/
#  cat /home/$USERNAME/.ssh/${USERNAME}_id_ed25519.pub > /home/$USERNAME/.ssh/authorized_keys
# It removes extra space:
  sed '/^\s*$/d' /home/$USERNAME/.ssh/${USERNAME}_id_ed25519.pub > /home/$USERNAME/.ssh/authorized_keys
  chmod 700 /home/$USERNAME/.ssh
  find /home/$USERNAME/.ssh -type f -exec chmod 600 {} \;
  chown -R "$USERNAME:$USERNAME" /home/$USERNAME/.ssh
}

setup_sudoers() {
  local USERNAME="$1"
  local f="/etc/sudoers.d/${USERNAME}"

  echo "===> Add sudoers :" ${USERNAME}

    if [[ "$USERNAME" =~ ^($USERNAME_VKOLEV)$ ]]; then
      echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "$f"
    else
      echo "${USERNAME} ALL=(ALL:ALL) NOPASSWD: /bin/systemctl suspend, /usr/bin/cat /etc/hostname" > "$f"
    fi
  chmod 440 "$f"
  visudo -cf "$f" >/dev/null || { echo " *** ERROR: Invalid sudoers file: $f"; exit 1; }
}

configure_sshd() {
  # Get all provided users (e.g., "user1 user2")
  local USERS="$@"
  local sshd="/etc/ssh/sshd_config"

  # Check if at least one user is specified
  if [ -z "$USERS" ]; then
    echo "❌ Error: No users specified for sshd configuration!"
    return 1
  fi

  echo "===> Setting up SSH config for users: ${USERS}"

  # 1. Create a backup of the current configuration
  cp -a "$sshd" "${sshd}.bak.$(date +%F_%H%M%S)"

  # 2. Modify settings using sed
  sed -i 's|^#\?Port .*|Port 4224|' "$sshd" || true
  sed -ri 's/^\s*#?\s*PasswordAuthentication\s+.*/PasswordAuthentication no/' "$sshd" || true
  sed -ri 's/^\s*#?\s*PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' "$sshd" || true
  
  # 3. Remove any existing AllowUsers lines to prevent duplicates
  sed -i '/^AllowUsers/d' "$sshd"
  
  # 4. Write the new AllowUsers line with all specified users
  echo "AllowUsers ${USERS}" >> "$sshd"

  # 5. Configure ListenAddress
  if ! grep -q "ListenAddress ${HOST_IP}" "$sshd"; then
    echo "ListenAddress ${HOST_IP}" >> "$sshd"
  fi

  # 6. Add TrustedUserCAKeys if not already present
  if ! grep -q "TrustedUserCAKeys /etc/ssh/ssh_user_ca.pub" "$sshd"; then
    echo "TrustedUserCAKeys /etc/ssh/ssh_user_ca.pub" >> "$sshd"
  fi
}