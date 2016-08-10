#!/bin/sh
#
# Generate nssdb Database
# Import service certificate

## VARIABLES
NSSPATH="/etc/apache2/nssdb"
PWDFILE="$NSSPATH/pwdfile.txt"

CAFILE="/etc/ipa/ca.crt"
CERTNAME="Server-Cert"

DOMAIN="INFRA.MSV"
FQDN=`hostname`
CNAME="racktables.infra.msv"
PRINCIPAL="HTTP/$FQDN"
MODNSS_PASSWD="/etc/apache2/password.conf"

#PASSWORD='SuperPassword1234()'
PASSWORD=`openssl rand -base64 32`

## HELP
################################################################################
display_help() {
    cat <<EOF
Usage: ./$O OPTIONS

$0 is a wrapper for certmonger and nssdb manipulation, that can
perform multiple service integrations:

OPTIONS:
    -d          Backup and remove an eventual old nssdb database
    -n          Create a fresh new database and include CA
    -a          Configuration for usage with mod_nss
    -s          Fetch service certificate

    -h          Print help
    -m          Print cheatsheet for certmonger/freeipa
    -i          Print script information
    -c          Check certmonger status

You first need to configure variables in this file!

EOF
    exit 0
}

## SHOW CERTMONGER STATUS FOR SPECIFIC SERVICE
################################################################################
print_status() {
    ipa-getcert list -d $NSSPATH -n $CERTNAME
    return
}

## SHOW VARIABLES
################################################################################
display_debugconfig() {
    echo "          Server FQDN:  $FQDN"
    echo "        Service CNAME:  $CNAME"
    echo "               Domain:  $DOMAIN"
    echo
    echo "  CA Certificate File:  $CAFILE"
    echo "  Service Certif Name:  $CERTNAME"
    echo "    Service Principal:  $PRINCIPAL"
    echo
    echo "           NSSDB Path:  $NSSPATH"
    echo "       NSSDB Password:  $PASSWORD"
    echo "  NSSDB Password File:  $PWDFILE"
    echo "mod_nss Password File:  $MODNSS_PASSWD"
    echo
    exit 0
}

## BACKUP AND REMOVE OLD DB
################################################################################
remove_olddb() {
    echo "* Checking current monitoring..."
    # Check if certificate is monitored in certmonger
    print_status | grep "$CERTNAME"

    # If yes, stop tracking it
    if [ $? -eq 0 ]; then
        echo "* Stop tracking $CERTNAME..."
        ipa-getcert stop-tracking -d $NSSPATH -n $CERTNAME
    fi

    # If there is a previous db folder, backup it up
    echo "* Moving old db to $NSSPATH.old.`date +%s`..."
    mv $NSSPATH $NSSPATH.old.`date +%s` &>/dev/null
    return
}

## BUILD NSSDB
################################################################################
create_db() {
    echo "* Creating new nssdb..."
    mkdir -p $NSSPATH
    cd $NSSPATH
    echo "$PASSWORD" > $PWDFILE
    chmod go-rwx $PWDFILE
    touch $MODNSS_PASSWD
    chmod 640 $MODNSS_PASSWD
    certutil -N -d $NSSPATH -f $PWDFILE
    chmod g+rw $NSSPATH/*.db
    certutil -A -d . -n 'INFRA.MSV IPA CA' -t CT,, -a < $CAFILE
    echo "  Done."
    return
}

## BUILD APACHE2 CONFIG
################################################################################
create_apache2conf() {
    echo "* Creating apache2 config..."
    echo "internal:$PASSWORD" > $MODNSS_PASSWD
    chown :www-data $NSSPATH/*.db
    chown root:www-data $MODNSS_PASSWD
    echo "  Password file created. Please configure your mod_nss to use it."
    return
}

## GET CERTIFICATE FOR SERVICE
################################################################################
get_servercert() {
    echo "* Signing certificate for service..."
    # Sign Cert
    ipa-getcert request -d $NSSPATH -n $CERTNAME -g 2048 \
        -p $PWDFILE -N "CN=$FQDN,O=$DOMAIN" -D "$CNAME" -K $PRINCIPAL
    echo "  Done."
    return
}

## CHEAT SHEET FOR CERTMONGER AND FREEIPA
################################################################################
show_commands () {
    cat <<EOF
#####################
## GET INFORMATION ##
#####################

## Check status
ipa-getcert list -d $NSSPATH -n $CERTNAME

## Show certificate renewal status
certutil -L -d $NSSPATH -n $CERTNAME

## Check validity
certutil -V -u V -d  $NSSPATH -n $CERTNAME

## Delete certmonger request
ipa-getcert stop-tracking -n $CERTNAME

EOF
    exit 0
}

## DO IT
################################################################################
if [ $# -eq 0 ]; then
    display_help
fi

while getopts "hdnamsic" OPT; do
    case $OPT in
        d)  remove_olddb;;
        n)  create_db;;
        a)  create_apache2conf;;
        s)  get_servercert;;

        h)  display_help;;
        m)  show_commands;;
        i)  display_debugconfig;;
        c)  print_status;;

        ?)
            echo "Invalid option: -$OPTARG" >&2
            display_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            display_help
            exit 2
            ;;
    esac
done
shift `expr $OPTIND - 1`
exit 0
