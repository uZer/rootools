#! /bin/bash
#
# Add a new route table and redirect traffic through the VPN interface
# using iproute2 and iptables traffic labels. Generic configuration using
# /etc/openvpn/<vpnName> and syslogs in order to discover network settings.
# Shoddy work :P Uses system log files... don't do this at home!

# QUIT MESSAGE (error)
die () {
    echo >&2 "$@"
    exit 1
}

usage () {
    echo "Redirect traffic throught OpenVPN tunnel <vpnName>"
    echo
    echo "Usage:    $0 [-f|--flush] <vpnName>"
    echo "          $0 [-h|--help]"
    echo
    echo "Use -f <vpnName> to reset traffic to default interface"
    echo "/etc/openvpn/<vpnName>.conf must exist."
}

# Flush previous configuration
doFlush () {
    echo "Flushing nat, marks and routes"
    sudo ip route flush table $tablenum > /dev/null 2>&1
    sudo iptables -t nat -D POSTROUTING -m mark --mark $labelnum -o $tunnelint ! -s $tunnelip -j SNAT --to-source $tunnelip > /dev/null 2>&1
    sudo iptables -t mangle -D OUTPUT -p $vpnproto -d $vpnserver --dport $vpnport -j RETURN > /dev/null 2>&1
    sudo iptables -t mangle -D OUTPUT -j MARK --set-mark $labelnum > /dev/null 2>&1
}

# SUMMARY
summary () {
    echo -e "\e[1mSETTINGS SUMMARY\e[0m"
    echo -e "\e[32mVPN config file:\e[39m       $vpnconf"
    echo -e "\e[32mVPN log file:\e[39m          $logfile"
    echo
    echo -e "\e[32mVPN remote server:\e[39m     $vpnserver"
    echo -e "\e[32mVPN port and protocol:\e[39m $vpnport $vpnproto"
    echo
    echo -e "\e[32mTunnel interface:\e[39m      $tunnelint"
    echo -e "\e[32mTunnel IP:\e[39m             $tunnelip"
    echo -e "\e[32mTunnel gateway:\e[39m        $tunnelgw"
    echo
    echo -e "\e[32mLAN gateway:\e[39m           $localgw"
    echo -e "\e[32mTable and label:\e[39m       $tablenum $labelnum"
    echo
    read -p "Is this correct? [y/N]" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        die "Quitting."
    fi
}

postsummary () {
    echo -e "\e[1mVPN ROUTE TABLE\e[0m"
    ip route show table $tablenum
    echo
    echo -e "\e[1mNAT\e[0m"
    iptables -t nat -L | grep mark
    echo
    echo -e "\e[1mMANGLE\e[0m"
    iptables -t mangle -S OUTPUT
    echo
    echo "Your default traffic is now routed through interface $tunnelint."
    echo "You can stop this with the following command:"
    echo "$0 -f $vpnname"
}

doConfigure () {
    echo -e "\e[34m[1/5]\e[39m Building a copy of the main route table removing default route..."
    ip route show table main | grep -Ev '^default via ' | while read entry; do
        ip route add table $tablenum $entry;
    done
    echo -e "\e[34m[2/5]\e[39m Setting the tunnel as the default route..."
    ip route add table $tablenum default via $tunnelgw dev $tunnelint
    echo -e "\e[34m[3/5]\e[39m Routing marked paquets with our new route table..."
    ip rule add fwmark $labelnum table $tablenum
    echo -e "\e[34m[4/5]\e[39m Marking output traffic with label $labelnum (except openvpn traffic to $vpnserver)..."
    iptables -t mangle -A OUTPUT -p $vpnproto -d $vpnserver --dport $vpnport -j RETURN
    iptables -t mangle -A OUTPUT -j MARK --set-mark $labelnum
    echo -e "\e[34m[5/5]\e[39m Applying source NAT before putting traffic in the tunnel..."
    iptables -t nat -A POSTROUTING -m mark --mark $labelnum -o $tunnelint ! -s $tunnelip -j SNAT --to-source $tunnelip
    echo "DONE!"
    echo
}

# Check user
if [ "$UID" -ne 0 ]; then
    die "Please run me as root user"
fi

##############
# CHECK ARGS #
##############
if [ ! $# -eq 1 ] && [ ! $# -eq 2 ]; then
    usage
    die "Wrong arguments"
fi

while [[ $1 == -* ]]; do
    key="$1"
    shift
    case $key in
        -h|--help)
            usage
            exit 2
            ;;
        -f|--flush)
            flush=1
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

vpnname=$1
logfile="/var/log/syslog"
vpnconf="/etc/openvpn/$vpnname.conf"

shift

# Too much is too much
if [ ! $# -eq 0 ]; then
    usage
    exit 2
fi

# Check config file
if [ ! -f $vpnconf ]; then
    die "So such VPN config file: $vpnconf"
fi

# Learn things the hard way

# Please be careful! It only takes the first remote in ovpn config file
# TODO: Multiple end-point management
vpnserver=`cat $vpnconf | grep -E '^remote' | head -n1 | cut -d" " -f2`
vpnserver=`dig +short $vpnserver`
vpnport=`cat $vpnconf | grep -E '^remote' | head -n1 | cut -d" " -f3`
vpnproto=`cat $vpnconf | grep -E '^proto ' | cut -d" " -f2`
tunnelint=`grep ovpn-$vpnname $logfile | grep "TUN/TAP" | grep "opened" | tail -n1 | cut -d" " -f8`
tunnelgw=`ip route show table main | grep "$tunnelint" | grep "src " | cut -d" " -f1`
tunnelip=`ip route show table main | grep "$tunnelint" | grep "src " | cut -d" " -f12`
localgw=`ip route show table main | grep -E '^default via ' | cut -d" " -f3`
tablenum=1
labelnum=1

summary
doFlush

# Is that all?
if [ $flush ]; then
    die "Done flushing."
fi

doConfigure
postsummary

exit 0
