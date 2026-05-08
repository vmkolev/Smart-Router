#!/usr/bin/env bash
########################################################################################################
# ______    _______  __   __  _______  _______  ______      _______  _______  _______  __   __  _______ 
#|    _ |  |       ||  | |  ||       ||       ||    _ |    |       ||       ||       ||  | |  ||       |
#|   | ||  |   _   ||  | |  ||_     _||    ___||   | ||    |  _____||    ___||_     _||  | |  ||    _  |
#|   |_||_ |  | |  ||  |_|  |  |   |  |   |___ |   |_||_   | |_____ |   |___   |   |  |  |_|  ||   |_| |
#|    __  ||  |_|  ||       |  |   |  |    ___||    __  |  |_____  ||    ___|  |   |  |       ||    ___|
#|   |  | ||       ||       |  |   |  |   |___ |   |  | |   _____| ||   |___   |   |  |       ||   |    
#|___|  |_||_______||_______|  |___|  |_______||___|  |_|  |_______||_______|  |___|  |_______||___|    
#
# FILE: router_setup.sh
# PART OF: Smart Router Project
#
# NOTE: Before run this script check and fill out config.conf file 
#  
########################################################################################################

set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [command]

Commands:
  all           All options: packages, user-ssh, network, firewall
  packages      Install all packages listed in packages.list
  user-ssh      Create users, sudoers and SSH access
  network       Network configuration
  status        Status (IP address)
  help          Help menu
USAGE
}

require_root() { [[ $EUID -eq 0 ]] || { echo "Must be root."; exit 1; }; }

# Install software
cmd_packages() {
  require_root
  echo "🔍 Install packages from a list ::"
  packages_check_linux
  echo "✅ Packages are installed."
}

# Configure netowkr
cmd_network() {
  require_root

  # Call function to find interface info
  echo "🔍 Get the proper IFACE name ::"
  find_interface_info

  # Call function to configure network
  echo "✅ Setup network configuration ::"
  configure_network

  echo "✅ Setup IP configuration ::"
  set_ip_address

  # Set DNS servers
  set_dns

  echo "===> Add hosts list to /etc/hosts:"
  cat ${BASE_DIR}/files/hosts >> /etc/hosts

  echo "✅ Network configured ::"
  echo "--------------------------------"
  echo "|Interface    :" ${IFACE}
  echo "|IP Address   :" ${SERVICE_IP}
  echo "|Netmask      :" ${NETMASK}
  echo "|Gateway      :" ${GATEWAY}
  echo "|DNS1         :" ${DNS1}
  echo "|DNS2         :" ${DNS2}
}

# Create All users and setup ssh
cmd_user_ssh() {
  require_root

      echo "===> It will create user VKOLEV ::"
      create_user "$USERNAME_USER2" " " " "
      setup_sudoers "$USERNAME_USER2"

      echo "===> It will create user USER1 ::"
      create_user "$USERNAME_USER1" "$USER_ID_USER1" "$USER_GID_USER1"
      setup_sudoers "$USERNAME_USER1"

      configure_sshd "$USERNAME_USER2" "$USERNAME_USER1"

  # Restart ssh service
  systemctl reload ssh || systemctl restart ssh
  echo "✅ Users have been created."
}


# Show status
cmd_status() {
  echo "#           Status   ::"
  echo "--------------------------------"
  echo "Network interface : "$IFACE
  echo "MAC address : "$IFACE_MAC
  echo "All networks : "
  ip -br a || true
  echo
  systemctl is-enabled nftables 2>/dev/null && echo "nftables: enabled" || echo "nftables: not enabled"
  systemctl is-active nftables  2>/dev/null && echo "nftables: active"  || echo "nftables: inactive"
  echo
}

cmd_all() {
  cmd_packages
  cmd_network
  cmd_user_ssh
  cmd_status
}

main() {
  case "${1:-all}" in
    all)         cmd_all ;;
    packages)    cmd_packages ;;
    user-ssh)    cmd_user_ssh ;;
    network)     cmd_network ;;
    status)      cmd_status ;;
    help|-h|--help) usage ;;
    *) echo "❌ Try again: ${1}"; echo; usage; exit 1 ;;
  esac
}

export BASE_DIR=${PWD}
source ${BASE_DIR}/config.conf
source ${BASE_DIR}/lib.sh

main "$@"
