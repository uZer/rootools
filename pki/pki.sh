#!/bin/bash
# Sign and revoke certificates
#
# Author: Youenn Piolet
# <piolet.y@gmail.com>

## CHANGE ME ##
DOMAIN="infra.msv"
PKIDIR="/srv/pki-$DOMAIN-root"
CAKEY="private/ca-root.$DOMAIN-key.pem"
CACERT="certs/ca-root.$DOMAIN-cert.pem"
CACHAIN="certs/ca-chain.$DOMAIN-cert.pem"
CACRL="crl/ca-root.$DOMAIN-crl.pem"
CACRLDISTRIBUTION="URI:http://ssl.infra.msv/$CACRL"
EXPORTDIR="$PKIDIR/exports"
COUNTRY="FR"
PROVINCE="IDF"
LOCATION="Paris"
ORG="Orgname"
SIZE="4096"

## HELP & PARAMS ##
###################
display_help()
{
    cat <<EOF
Usage: ./$0 OPTIONS <HOSTNAME-without-domain>

$0 is a light wrapper for openssl (just like EasyRSA) for simple and generic
Usage. Choose an action to perform and the fqdn you want to use.

ACTIONS:
 -h             Display this message

 -s <HOSTNAME>  Gen and sign certificate and private key for domain <HOSTNAME>
 -p <HOSTNAME>  Export package for <HOSTNAME> (KEY, CERT, CSR)
 -c <HOSTNAME>  Check certificate of <HOSTNAME>

 -r <HOSTNAME>  Revoke certificate of <HOSTNAME>
 -u             Update revocation list

Don't put the domain extension in your HOSTNAME (no FQDN)
EOF
    exit 0
}

# No args
[[ $# -eq 0 ]] && display_help
[[ ! -d $PKIDIR ]] && echo "No such dir: $PKIDIR" && exit 1
cd $PKIDIR

## SIGNATURE MODULE ##
######################
# Create private key
gen_sign_cert()
{
    [[ -e certs/$1.$DOMAIN-cert.pem ]] && echo "Cert already exists" && exit 3
    openssl genrsa -out private/$1.$DOMAIN-key.pem $SIZE

    # Certification request
    openssl req \
        -sha256 -new \
        -key private/$1.$DOMAIN-key.pem \
        -out certs/$1.$DOMAIN-csr.pem \
        -subj "/C=$COUNTRY/ST=$PROVINCE/L=$LOCATION/CN=$1.$DOMAIN/O=$ORG" \
        -config ./openssl.cnf

    # Make the CA sign the certificate
    openssl ca \
        -keyfile $CAKEY \
        -cert $CACERT \
        -extensions usr_cert -notext -md sha256 \
        -in certs/$1.$DOMAIN-csr.pem \
        -out certs/$1.$DOMAIN-cert.pem

    # Cleaning and security
    chmod 400 private/$1.$DOMAIN-key.pem
    chmod 444 certs/$1.$DOMAIN-cert.pem
    return
}

## PACKAGING MODULE ##
######################
gen_tarball()
{
    echo "========= Packing certificate bundle for $1.$DOMAIN   ========="
    echo ""
    tar cvzf $EXPORTDIR/$1.$DOMAIN.tar.gz \
        certs/$1.$DOMAIN-cert.pem \
        certs/$1.$DOMAIN-csr.pem \
        private/$1.$DOMAIN-key.pem \
        certs/ca-chain.$DOMAIN-cert.pem
    chmod 400 $EXPORTDIR/$1.$DOMAIN.tar.gz
    echo "Tarball exported on: $EXPORTDIR/$1.$DOMAIN.tar.gz"
    return
}

## CHECKING MODULE ##
#####################
check_crt()
{
    [[ ! -e certs/$1.$DOMAIN-cert.pem ]] && echo "Cert doesn't exist" && exit 3
    echo "========= Verification of certificate $1.$DOMAIN-cert ========="
    echo ""
    # Vertify issuer
    openssl x509 -in certs/$1.$DOMAIN-cert.pem

    # Verify signature
    openssl verify -CAfile $CACHAIN certs/$1.$DOMAIN-cert.pem
    return
}

## CRL GENERATION ##
####################
gen_crl() {
    echo "========= Generating CRL list of revoked certificates  ========="
    echo ""
    openssl ca \
        -keyfile $CAKEY -cert $CACERT -gencrl -out $CACRL \
        -subj "/C=$COUNTRY/ST=$PROVINCE/L=$LOCATION/CN=$1.$DOMAIN/O=$ORG"
    openssl crl -text -in $CACRL
    echo "CRL list of revoked certificates has been generated in $CACRL"
    echo "You can use the following URL in your configuration files:"
    echo "crlDistributionPoints = $CACRLDISTRIBUTION"
    return
}

## REVOKE MODULE ##
###################
revoke()
{
    [[ ! -e certs/$1.$DOMAIN-cert.pem ]] && echo "Cert doesn't exist" && exit 3
    echo "========= Revocation of certificate  $1.$DOMAIN-cert  ========="
    echo ""
    # SSL revocation
    openssl ca -keyfile $CAKEY -cert $CACERT -revoke certs/$1.$DOMAIN-cert.pem
    echo "Certificate has been revoked."
    gen_crl
    return
}

# getopts
while getopts ":hs:p:c:r:u" OPT; do
    case $OPT in
        h)  display_help;;
        s)  gen_sign_cert ${OPTARG};;
        p)  gen_tarball ${OPTARG};;
        c)  check_crt ${OPTARG};;
        r)  revoke ${OPTARG};;
        u)  gen_crl;;

        ?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 2
            ;;
    esac
done
shift `expr $OPTIND - 1`

