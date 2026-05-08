# ThinkPad X201 Smart Router Setup
---

This project transforms a ThinkPad X201 (or any Debian-based Linux machine) into a versatile hardware router.
It allows you to share internet access from either an iPhone or a Standard LAN Cable via a secure, hidden Wi-Fi Access Point.

# 🚀 Features

* Dual Internet Source: Switch seamlessly between Mobile Data (iPhone) and Ethernet (Cable).
* Hidden Hotspot: Creates a secure Wi-Fi Access Point with a hidden SSID - perfect for home security cameras.
* Automatic Configuration: Automatically installs dependencies, generates hostapd and dnsmasq configs, and sets up IP forwarding.
* Smart Routing: Automatically handles routing priorities and restores default gateways when switching sources.
* State-of-the-art Firewall: Uses nftables for efficient NAT (Network Address Translation) and traffic filtering.
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

# To-Do list

* install & config swatchdog - to collect events
* make swatchdog as service
* close opened ports - fw rules
* change ssh port - use unpredictable port like 2332

---


## License

MIT

**Free Software, Hell Yeah!**
