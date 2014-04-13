#! /bin/bash
#
# Add a new route table and redirect trafic through the VPN interface
# using iproute2 and iptables trafic labels. Generic configuration using
# /etc/openvpn/<vpnName> in order to discover network settings
#
# Syntax:
# ./routeTheVoid.sh <vpnName>

############
# VARIABLE #
############
vpnname=$1
vpnconf="/etc/openvpn/$vpnname.conf"
logfile="/var/log/syslog"

# Only takes the first remote
# TODO: Multiple end-point management
vpnserver=`cat $vpnconf | grep -E '^remote' | head -n1 | cut -d" " -f2`
vpnport=`cat $vpnconf | grep -E '^remote' | head -n1 | cut -d" " -f3`
vpnproto=`cat $vpnconf | grep -E '^proto ' | cut -d" " -f2`

# Learn things the hard way
tunnelint=`sudo grep ovpn-$vpnname $logfile | grep "TUN/TAP" | grep "opened" | tail -n1 | cut -d" " -f8`
tunnelgw=`ip route show table main | grep "$tunnelint" | grep "src " | cut -d" " -f1`
tunnelip=`ip route show table main | grep "$tunnelint" | grep "src " | cut -d" " -f12`

localgw=`ip route show table main | grep -E '^default via ' | cut -d" " -f3`

tablenum=10
labelnum=10

###########
# SUMMARY #
###########

echo "VPN config file: $vpnconf"
echo "VPN log file: $logfile"
echo "VPN remote server: $vpnserver"
echo "VPN port and protocol: $vpnport $vpnproto"
echo "LAN gateway: $localgw"
echo "Tunnel gateway: $tunnelgw"
echo "Tunnel interface: $tunnelint"
echo "Tunnel IP: $tunnelip"
echo "Table number: $tablenum"

#################
# CONFIGURATION #
#################

# Cleanning up things
echo "Flushing old tables..."
sudo ip route flush table $tablenum > /dev/null 2>&1
sudo iptables -t nat -D POSTROUTING -m mark --mark $labelnum -o $tunnelint ! -s $tunnelip -j SNAT --to-source $tunnelip > /dev/null 2>&1
sudo iptables -t mangle -D OUTPUT -p $vpnproto --dport $vpnport -j RETURN > /dev/null 2>&1
sudo iptables -t mangle -D OUTPUT -j MARK --set-mark $labelnum > /dev/null 2>&1

# Create a copy of the main route table removing default route
echo "Create the new route table..."
ip route show table main | grep -Ev '^default via ' | while read entry; do
    sudo ip route add table $tablenum $entry;
done

# Set the tunnel as the default route
echo "New default gateway..."
sudo ip route add table $tablenum default via $tunnelgw dev $tunnelint

# Route marked paquets with our new VRF
echo "Mark traffic..."
sudo ip rule add fwmark $labelnum table $tablenum

echo "Conditional routing..."
# Mark output trafic with labelnum except the trafic to the vpnserver itself
sudo iptables -t mangle -A OUTPUT -p $vpnproto --dport $vpnport -j RETURN
sudo iptables -t mangle -A OUTPUT -j MARK --set-mark $labelnum

echo "and finally, NAT"
# Source nat before putting trafic in the tunnel
sudo iptables -t nat -A POSTROUTING -m mark --mark $labelnum -o $tunnelint ! -s $tunnelip -j SNAT --to-source $tunnelip

exit 0
