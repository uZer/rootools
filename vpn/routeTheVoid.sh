#! /bin/bash
#
# Add a new route table and redirect traffic through the VPN interface
# using iproute2 and iptables traffic labels. Generic configuration using
# /etc/openvpn/<vpnName> and syslogs in order to discover network settings.
# Shoddy work :P
#
# Syntax:
# ./routeTheVoid.sh <vpnName>
# ./routeTheVoid.sh stop

##############
# CHECK ARGS #
##############

# Quit message
die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "This script requires 1 argument"

vpnname=$1
vpnconf="/etc/openvpn/$vpnname.conf"



############
# VARIABLE #
############
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

echo "SETTINGS SUMMARY"
echo "VPN config file: $vpnconf"
echo "VPN log file: $logfile"
echo "VPN remote server: $vpnserver"
echo "VPN port and protocol: $vpnport $vpnproto"
echo "LAN gateway: $localgw"
echo "Tunnel gateway: $tunnelgw"
echo "Tunnel interface: $tunnelint"
echo "Tunnel IP: $tunnelip"
echo "Table number: $tablenum"
echo ""

#################
# CONFIGURATION #
#################

echo "Flushing old things..."
sudo ip route flush table $tablenum > /dev/null 2>&1
sudo iptables -t nat -D POSTROUTING -m mark --mark $labelnum -o $tunnelint ! -s $tunnelip -j SNAT --to-source $tunnelip > /dev/null 2>&1
sudo iptables -t mangle -D OUTPUT -p $vpnproto --dport $vpnport -j RETURN > /dev/null 2>&1
sudo iptables -t mangle -D OUTPUT -j MARK --set-mark $labelnum > /dev/null 2>&1

# If $1 is "stop" then quit, we just want to flush things.
# Don't you dare calling your VPN "stop". TODO: stop coding like a tool
if [ $1 = stop ]; then
    die "Done flushing."
fi

# Let's work
echo "Create a copy of the main route table removing default route"
ip route show table main | grep -Ev '^default via ' | while read entry; do
    sudo ip route add table $tablenum $entry;
done

echo "Set the tunnel as the default route"
sudo ip route add table $tablenum default via $tunnelgw dev $tunnelint

echo "Route marked paquets with our new route table"
sudo ip rule add fwmark $labelnum table $tablenum

echo "Conditional routing..."

echo "Mark output traffic with label $labelnum except the traffic to $vpnserver"
sudo iptables -t mangle -A OUTPUT -p $vpnproto --dport $vpnport -j RETURN
sudo iptables -t mangle -A OUTPUT -j MARK --set-mark $labelnum

echo "Source NAT before putting traffic in the tunnel"
sudo iptables -t nat -A POSTROUTING -m mark --mark $labelnum -o $tunnelint ! -s $tunnelip -j SNAT --to-source $tunnelip

###############
# PRINT STUFF #
###############

echo ""
echo "DONE!"
sudo ip route show table $tablenum
echo ""
echo "NAT table:"
sudo iptables -t nat -L | grep $tunnelint
echo ""
echo "Conditional routing:"
sudo iptables -t mangle -L | grep "-A OUTPUT"
echo ""
echo "Your default traffic is now routed through interface $tunnelint."
echo "You can stop this with the following command:"
echo "$0 stop"

exit 0
