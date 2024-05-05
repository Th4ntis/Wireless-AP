#!/bin/bash

# Define color-coded status indicators
green='\e[1;32m[+]\e[0m'
red='\e[1;31m[-]\e[0m'

# Ensure the script is run as root
if [[ "$(id -u)" != "0" ]]; then
   echo -e "$red This script must be run as root" >&2
   exit 1
fi

# Display ASCII art header
clear
echo -e "$(base64 -d <<< "CgpfXyAgICAgICAgX19fICAgICAgICAgIF8gICAgICAgICAgICAgICAgICAgICAgIF8gICAgX19fXyAgClwgXCAgICAgIC8gKF8pXyBfXyBfX198IHwgX19fICBfX18gX19fICAgICAgICAvIFwgIHwgIF8gXCAKIFwgXCAvXCAvIC98IHwgJ19fLyBfIFwgfC8gXyBcLyBfXy8gX198X19fX18gLyBfIFwgfCB8XykgfAogIFwgViAgViAvIHwgfCB8IHwgIF9fLyB8ICBfXy9cX18gXF9fIFxfX19fXy8gX19fIFx8ICBfXy8gCiAgIFxfL1xfLyAgfF98X3wgIFxfX198X3xcX19ffHxfX18vX19fLyAgICAvXy8gICBcX1xffCAgICAKCg==")\n"
echo -e "A script to setup a wireless access point."

# Function to check and install packages
echo -e "\n$green Checking prerequisites..."
install_package() {
    if ! dpkg -s "$1" &> /dev/null; then
        echo -e "$red $1 is not installed. Installing..."
        sudo apt-get install -y "$1"
    else
        echo -e "$green Prerequisite met: $1 already installed."
    fi
}

# Check and install necessary packages
install_package hostapd
install_package dnsmasq

# Trap CTRL+C and call cleanup function
trap 'cleanup; exit 1' SIGINT

cleanup() {
    echo -e "\n$green SIGINT Received. Stopping services and resetting interface..."
    systemctl stop hostapd dnsmasq
    ip addr flush dev $interface
    ip link set $interface down && ip link set $interface up
}

# Main functionality
read -p "Do you want a password on the AP? (y/n): " with_pw

read -p "Enter the SSID (AP Name): " ssid
read -p "Enter the Wireless Interface (e.g., wlan0): " interface
read -p "What is the interface your internet is on? (e.g, eth0): " internet

if [[ "$with_pw" =~ [Yy] ]]; then
    read -s -p "Enter the Password (at least 6 characters): " password
    echo
    if [[ ${#password} -lt 6 ]]; then
        echo -e "$red Password must be at least 6 characters."
        exit 1
    fi
fi

# Configure hostapd
echo -e "$green Configuring hostapd..."
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$interface
ssid=$ssid
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
$( [[ "$with_pw" =~ [Yy] ]] && echo -e "wpa=2\nwpa_passphrase=$password\nwpa_key_mgmt=WPA-PSK\nwpa_pairwise=TKIP\nrsn_pairwise=CCMP" )
EOF

# Configure dnsmasq
echo -e "$green Configuring dnsmasq..."
cat > /etc/dnsmasq.conf <<EOF
interface=$interface
dhcp-range=10.0.0.10,10.0.0.100,255.255.255.0,8h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1,8.8.8.8
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
no-resolv
EOF

# IP forwarding and NAT configuration
echo -e "$green Setting IP and NAT configurations..."
ip addr add 10.0.0.1/24 dev $interface
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sysctl -p
iptables --flush
iptables -t nat -A POSTROUTING -o $internet -j MASQUERADE
iptables -A FORWARD -i $internet -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $interface -o $internet -j ACCEPT

# Restart network services
echo -e "$green Restarting network services..."
systemctl restart hostapd dnsmasq

echo -e "$green Wireless access point is now running with SSID: $ssid. Press Ctrl+C to stop."
while true; do sleep 10; done  # Maintain the script running
