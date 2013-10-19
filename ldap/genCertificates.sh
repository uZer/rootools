#!/bin/bash
#
# SIA 2013
# Generates a certificate for all hosts in parameters
# Push them to the necessary hosts, according to options

## TODO: Input file
## TODO: Add logfile

VERB=0
GEN=0
SEND=0

# ENV local (cert serv)
CERTDIR="/etc/openvpn/keys"

# Login credential to connect destination host
DESTUSER="root"

# Generates certificate for specific hostname
genCert () {

    if [[ -e "$CERTDIR/$1" ]]; then
        [[ $VERB -eq 1 ]] && echo "Certificates for $1 already exist"
        return 0
    else
        ## TODO easy-rsa
        return 1
    fi
}

# Copy certificates to a specific host best known as Sir "$1"
copyCert () {
    SIA_CRT="$CERTDIR/ca.crt"
    HOST_CRT="$CERTDIR/$1.crt"
    HOST_KEY="$CERTDIR/$1.key"

    # ENV dest
    DEST_CA="/etc/ssl/certs/ca-sia.crt"
    DEST_CRT="/etc/ssl/certs/$1.crt"
    DEST_KEY="/etc/ssl/private/$1.key"

    # Copy

    [[ $VERB -eq 1 ]] && echo "$SIA_CRT to $1 in $DEST_CRT"
    sshpass -p $2 scp  $SIA_CRT root@$1:$DEST_CRT
    [[ $VERB -eq 1 ]] && echo "$HOST_CRT to $1 in $DEST_CRT"
    sshpass -p $2 scp $HOST_CRT root@$1:$DEST_CRT
    [[ $VERB -eq 1 ]] && echo "$HOST_CRT to $1 in $DEST_KEY"
    sshpass -p $2 scp $HOST_KEY root@$1:$DEST_KEY

    return $?
}

usage () {
    cat <<EOF
Usage: `basename $0` [ -v ] -c hostname1 [hostname2, ...]

This scripts sends certificates for news hosts

OPTIONS:
    -h  Display this message
    -v  Verbose mode
    -g  Generate certificates
    -s  Send files
EOF
}

###############################################################################

# Check arguments
[[ $# -lt 2 ]] && usage && exit 1

# Check options
while getopts "vgs" OPT; do
    case $OPT in
        v)
            # Enable verbose mode
            VERBOSE=1
            ;;

        g)
            # Generates the certificates if necessary
            GEN=1
            ;;

        s)
            # Sends certificates to remote host
            SEND=1
            # Read password
            read -p "Password for $DESTUSER user on REMOTE hosts: " -s SSHPASS
            ;;

        \?)
            # Halp
            usage
            exit 1
            ;;

        :)
            # Duh
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
    shift $(( OPTIND - 1 ))
done


# Do your the job you're paid for
for i; do
    if [ $GEN -eq 1 ]; then
        # Gen certs
        echo "Generating certificates for ${i}..."
        genCert "${i}"
    fi

    if [ $SEND -eq 1 ]; then
        # Copy certs
        echo "Sending files to host ${i}..."
        copyCert "${i}" "${SSHPASS}"
    fi

    [[ $VERB -eq 1 ]] && echo "${i} done"
done
exit $?


