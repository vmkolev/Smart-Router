# ThinkPad X201 Smart Router Setup

This project transforms a ThinkPad X201 (or any Debian-based Linux machine) into a versatile, high-performance hardware router. It provides a seamless way to share internet access from either an iPhone or a Standard LAN Cable via a secure, hidden Wi-Fi Access Point.

# 🌐 The Vision: Beyond Routing
This project is evolving into a comprehensive Smart Home Command Center. While it currently serves as a robust networking backbone, the roadmap includes transforming this machine into a sovereign automation hub.

Soon, it will natively host a complete smart home ecosystem, including:
- HomeAssistant for central automation and intelligence.
- WireGuard for encrypted remote access to the home network.
- MQTT Broker to synchronize and control your entire IoT environment.
- DuckDNS for seamless dynamic DNS management.

# 🚀 Features

* Dual Internet Source: Switch seamlessly between Mobile Data (iPhone) and Ethernet (Cable). It is because it will be used in a remote home where Internet is not provided by one source. For now!
* Hidden Hotspot: Creates a secure Wi-Fi Access Point with a hidden SSID - perfect for home security cameras and IoT devices.
* Automatic Configuration: Automatically installs dependencies, generates hostapd and dnsmasq configs, and sets up IP forwarding. It provides more flexibility in case of hardware failure.
* Smart Routing: Automatically handles routing priorities and restores default gateways when switching sources.
* State-of-the-art Firewall: Uses nftables for efficient NAT and traffic filtering.
* Static DHCP Leases: Supports pre-defined IP assignments for specific devices.

# 🛠 Prerequisites
* OS: Debian or any Debian-based Linux.
* Hardware: Laptop (in my case ThinkPad X201), USB Wi-Fi cards that support `AP mode` (like Ralink - rt2800usb driver).
* Packages: The script will automatically install hostapd, dnsmasq, nftables, and iw.

# ⚙️ Configuration (srouter.conf)
Before running the script, ensure your `srouter.conf` is populated.
## Client configuration :

```
client_name="client_1"
client_ip="10.10.10.21"
client_mac="11:22:33:ff:aa:88"

```

# 🚀 Usage
Make the script executable:
```sh
chmod +x smart_router.sh
```

Run with sudo:
```sh
sudo ./smart_router.sh
```
Select Source:
* Press 1 for iPhone: The script will prioritize second wifi card and adjust routes.
* Press 2 for Cable: The script will reset the Ethernet interface and restore the standard gateway.

Status of the current configuration:
```sh
sudo ./net_status.sh
```

If you need to stop|power off|restart :
```sh
sudo ./stop_router.sh
```
> After stop|restart current configuration will be cleared. You need to run `smart_router.sh`

---

## To-Do list

* install & config swatchdog - to collect events
* make swatchdog as service
* close opened ports - fw rules
* change ssh port - use different port like 2332
* install docker engine
* install and configure WireGuard, DuckDNS, MQTT server, HomeAssistant
---


## License

MIT

**Free Software, Hell Yeah!**
