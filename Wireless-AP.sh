#!/bin/bash

# status indicators
plus='\e[1;32m[+]\e[0m'
minus='\e[1;31m[-]\e[0m'

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo -e "$minus This script must be run as root" 1>&2
   exit 1
fi

# ascii art
clear
asciiart=$(base64 -d <<< "CgpfXyAgICAgICAgX19fICAgICAgICAgIF8gICAgICAgICAgICAgICAgICAgICAgIF8gICAgX19fXyAgClwgXCAgICAgIC8gKF8pXyBfXyBfX198IHwgX19fICBfX18gX19fICAgICAgICAvIFwgIHwgIF8gXCAKIFwgXCAvXCAvIC98IHwgJ19fLyBfIFwgfC8gXyBcLyBfXy8gX198X19fX18gLyBfIFwgfCB8XykgfAogIFwgViAgViAvIHwgfCB8IHwgIF9fLyB8ICBfXy9cX18gXF9fIFxfX19fXy8gX19fIFx8ICBfXy8gCiAgIFxfL1xfLyAgfF98X3wgIFxfX198X3xcX19ffHxfX18vX19fLyAgICAvXy8gICBcX1xffCAgICAKCg==")

# Beginning Script
echo -e "$asciiart"
echo -e "A script to setup a wireless accesspoint. \n"
echo -e "\n$plus Checking if prerequisites are installed..."

# Function to check if a package is installed
check_package() {
    dpkg -s "$1" &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "$plus Prequisite met. $1 already installed."
    else
        echo -e "$minus $1 is not installed. Installing now..."
        sudo apt-get install -y "$1"
    fi
}

# Check and install hostapd and dnsmasq if necessary
check_package hostapd
check_package dnsmasq

# Trap CTRL+C and call cleanup function
trap cleanup SIGINT

# Cleanup function to stop services
cleanup() {
    echo -e "\n$plus SIGINT Received. Stopping hostapd and dnsmasq..."
    systemctl stop hostapd
    systemctl stop dnsmasq
    echo -e "$plus Resetting $interface..."
    ip addr del 10.0.0.1/24 dev $interface
    sudo ip link set $interface down
    sudo ip link set $interface up
    echo -e "$plus Services stopped and Interface reset. Exiting."
    exit 1
}

ask_wifi_pw() {
    while true; do
        # Prompt the user
        read -p "$1 (y/n): " answer

        # Process the input
        case $answer in
            [Yy]* ) return 0;;  # If yes, return 0 (success)
            [Nn]* ) return 1;;  # If no, return 1 (failure)
            * ) echo "Please answer yes (y) or no (n).";;  # Otherwise, keep asking
        esac
    done
}

if ask_wifi_pw "Do you want a wireless password on the AP?"; then
    # Ask for SSID, password, interface, and internet interface
    read -p "Enter the SSID (AP Name): " ssid
    read -s -p "Enter the Password (at least 6 characters): " password
    echo
    read -p "Enter the Wireless Interface (e.g., wlan0): " interface
    read -p "What is the interface your internet is on? (e.g, eth0): " internet

    # Validate password length
    if [ ${#password} -lt 6 ]; then
        echo -e "$minus Password must be at least 6 characters."
        exit 1
    fi

    # Configure hostapd
    echo -e "$plus Configuring hostapd..."
    cat > /etc/hostapd/hostapd.conf <<EOF
interface=$interface
ssid=$ssid
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$password
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

    # Configure dnsmasq
    echo -e "$plus Configuring dnsmasq..."
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

    # Setting a static IP for the interface
    echo -e "$plus Assignign a static IP to $interface..."
    ip addr add 10.0.0.1/24 dev $interface

    # Setup sysctl for IP forwarding
    echo -e "$plus Enabling IP forwarding..."
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
    sysctl -p

    # Configure IP tables for NAT
    echo -e "$plus Setting up IP tables for NAT..."
    iptables --flush
    iptables -t nat -A POSTROUTING -o $internet -j MASQUERADE
    iptables -A FORWARD -i $internet -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $interface -o $internet -j ACCEPT

    # Restart network services
    echo -e "$plus Restarting hostapd and dnsmasq..."
    systemctl restart hostapd
    systemctl restart dnsmasq

    echo -e "$plus Wireless access point is running using SSID: $ssid. Press Ctrl+C to exit..."

    # Infinite loop
    while true; do
        sleep 10
    done
else
    # Ask for SSID, interface, and internet interface
    read -p "Enter the SSID (AP Name): " ssid
    read -p "Enter the Wireless Interface (e.g., wlan0): " interface
    read -p "What is the interface your internet is on? (e.g, eth0): " internet

    # Configure hostapd
    echo -e "$plus Configuring hostapd..."
    cat > /etc/hostapd/hostapd.conf <<EOF
interface=$interface
ssid=$ssid
hw_mode=g
channel=6
macaddr_acl=0
ignore_broadcast_ssid=0
EOF

    # Configure dnsmasq
    echo -e "$plus Configuring dnsmasq..."
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

    # Setting a static IP for the interface
    echo -e "$plus Assignign a static IP to $interface..."
    ip addr add 10.0.0.1/24 dev $interface

    # Setup sysctl for IP forwarding
    echo -e "$plus Enabling IP forwarding..."
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
    sysctl -p

    # Configure IP tables for NAT
    echo -e "$plus Setting up IP tables for NAT..."
    iptables --flush
    iptables -t nat -A POSTROUTING -o $internet -j MASQUERADE
    iptables -A FORWARD -i $internet -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $interface -o $internet -j ACCEPT

    # Restart network services
    echo -e "$plus Restarting hostapd and dnsmasq..."
    systemctl restart hostapd
    systemctl restart dnsmasq

    echo -e "$plus Wireless access point is running using SSID: $ssid. Press Ctrl+C to exit..."

    # Infinite loop
    while true; do
        sleep 10
    done
fi
