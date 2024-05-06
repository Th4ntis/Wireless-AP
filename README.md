# Wireless-AP
This is a simple/crude bash script to setup a wireless access point on Debian based linux using hostapd and dnsmasq. This will create an open AP or a WPA Protected AP with the given SSID/Password. This will also ask if you want to capture packets using tcpdump, and what you want the file saved as if so. This will install hostapd dnsmasq and tcpdump if they are not already installed.

# Using
Make the script executable
```
chmod +x Wireless-AP.sh
```

Run the script
```
sudo ./Wireless-AP.sh
```
![image](https://github.com/Th4ntis/Wireless-AP/assets/53808039/a45051f5-c592-43da-b22b-b5395ede9a08)
