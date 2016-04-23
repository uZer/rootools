#!/bin/bash
# Create and pack client openvpn configuration for a specific host
# WARNING: Your user should have a valid kerberos token
# and have the permission to add a host to a service.
set -euo pipefail
IFS=$'\n\t'

## PARAMS
_USER=${1:-}
_HOST=${2:-}
_IP=${3:-172.16.42.20}
_REALM=${4:-void}
_EMAIL=${5:-`cat ~/.email`}

## SCRIPT PATHS
_INPUT="/srv/ipa-openvpn-pki/${_REALM}/${_REALM}.${_USER}/${_HOST}"
_OUTPUT="/srv/ipa-openvpn-pki/${_REALM}/${_REALM}.${_USER}/${_HOST}.zip"
_SOURCECA="/etc/ipa/ca.crt"

## OPENVPN CONFIG
_VPNHOST='dans.tesfess.es'
_VPNPORT=1194
_VPNPROTOCOL='udp'
_CA="${_REALM}-ca.crt"
_CERT="${_HOST}.${_REALM}.crt"
_KEY="${_HOST}.${_REALM}.key"


# ------------------------------------------------------------------------------
## DISPLAY HELP
usage()
{
    cat << EOF
Usage: $0 user hostname ip-in-tunnel [realm] [email]

Create a certificate and openvpn configuration for user's computer.
The user doesn't have to be a FreeIPA user.
An email can be sent to the user if needed.

Example: $0 ypiolet abygaelle5 172.16.42.10 infra.msv admin@tesfess.es

EOF

    return
}

# ------------------------------------------------------------------------------
## COUNT
if [[ $# -lt 2 ]] || [[ $# -gt 3 ]]; then
    echo -e "\e[31mInvalid arguments\e[39m"
    usage
    exit 2
fi

if [[ $USER != root ]]; then
    echo -e "\e[31mERROR: This script should be exected as root.\e[39m"
    ipa-getcert list -v | grep org.freedesktop.DBus.Error.AccessDenied
    exit 10
fi

if [[ `getenforce` = 'Enforcing' ]]; then
    echo -e "\e[33mWARNING: Selinux is enabled."
    echo -e "Please make sure the type of ${_INPUT} will be cert_t\e[39m"
    echo ""
fi;
# ------------------------------------------------------------------------------
## SIMPLE CONFIRM FUNCTION
confirm()
{
    # Ask for confirmation
    echo ""
    read -r -p "${1:-Are you sure? [y/N]} " _RESP
    case $_RESP in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# ------------------------------------------------------------------------------
## GENERATE OVPN / CONF FILE
createConfigFiles()
{
    cat > ${_INPUT}/${_HOST}.${_REALM}.ovpn << EOF
client
nobind
remote ${_VPNHOST} ${_VPNPORT} ${_VPNPROTOCOL}
dev tun
dev-type tun
persist-key
persist-tun
verb 3
ca ${_CA}
cert ${_CERT}
key ${_KEY}
mute-replay-warnings
mute 10
EOF
    ## .conf file is a copy of OVPN file for linux
    cp ${_INPUT}/${_HOST}.${_REALM}.ovpn ${_INPUT}/${_HOST}.${_REALM}.conf
    return
}

# ------------------------------------------------------------------------------
## CREATION OF FILES
createCertificates()
{
    # FreeIPA
    echo ""
    echo "Registering host and DNS record in FreeIPA..."
    echo ""
    ipa dnsrecord-add --a-create-reverse --a-ip-address=${_IP} ${_REALM} ${_HOST}
    ipa host-add ${_HOST}.${_REALM}
    ipa service-add openvpn/${_HOST}.${_REALM}
    ipa service-add-host --hosts thecastle.void openvpn/${_HOST}.${_REALM}

    echo ""
    echo "Requesting a certificate..."
    echo ""
    # Certmonger Request
    ipa-getcert request \
        -f ${_INPUT}/${_CERT}     \
        -k ${_INPUT}/${_KEY}      \
        -N CN=${_HOST}.${_REALM} -D ${_HOST}.${_REALM} \
        -r -K openvpn/${_HOST}.${_REALM}

    echo ""
    echo "Adding CA..."
    cp /etc/ipa/ca.crt ${_INPUT}/${_CA}

    echo "Done."
    echo ""
    return
}

# ------------------------------------------------------------------------------
## TAAARBAAAAAAWL
createTarball()
{
    echo ""
    while [[ ! ( -f ${_INPUT}/${_CERT} && -f ${_INPUT}/${_KEY} ) ]]; do
        echo "      Waiting for certs to get signed..."
        sleep 1
    done;

    echo "Compressing files..."
    zip -r ${_OUTPUT} -j ${_INPUT}/*

    # Check if it's cool.
    if [[ -f ${_OUTPUT} ]]; then
        echo "OK."
        echo ""
    else
        echo -e "Oops. No output."
        echo ""
        exit 4
    fi
    return
}

# ------------------------------------------------------------------------------
## SEND BY EMAIL
sendTheStuff()
{
    echo "Let's send this by email..."
    mail -a ${_OUTPUT} \
        -s "[${_REALM}] OpenVPN Certificates for ${_USER}'s ${_HOST}" \
        ${_EMAIL} << EOF
Coucou cer patrick
tu trouveras ci-joint ton pack vpn gratuit pour administrer les internets.

ATTENTION MON GARS:
il faudra lancer openvpn en Adminstratueur sur ton pécé pour qu'il accepte
les routes que tes petits copains du réseau vont t'envoyer.

alé @+

EOF
    echo "Done!"
    echo "wow such zipball"
    echo "${_OUTPUT}"
    return
}

# ------------------------------------------------------------------------------
## CONFIRM AND RUN
cat << EOF
This script will create the following configuration pack:

    USERNAME:   ${_USER}
    HOST:       ${_HOST}
    IP in VPN:  ${_IP}
    REALM:      ${_REALM}

    OUTPUT:     ${_OUTPUT}
    SEND TO:    ${_EMAIL}
EOF

confirm "Is this correct? [y/N]" && {
    echo ""
    mkdir -p ${_INPUT} 2>&1>/dev/null
    createCertificates
    createConfigFiles
    createTarball
    sendTheStuff
}

