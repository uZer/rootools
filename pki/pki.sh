#!/bin/sh
# Sign and revoke certificates
FQDN="test"
PKIDIR="/srv/pki-infra.msv-intermediate"
CAKEY="private/ca-intermediate.infra.msv-key.pem"
CACERT="certs/ca-intermediate.infra.msv-cert.pem"
CACRL="crl/ca-intermediate.infra.msv-crl.pem"
EXPORTDIR="$PKIDIR/exports"
SIZE="4096"

cd $PKIDIR

###################
## HELP & PARAMS ##
###################
display_help()
{
    cat <<EOF
Usage: ./$0 OPTIONS <full.qualified.domain.name>

$0 is a wrapper for openssl (just like EasyRSA) for simple and generic usage.
Choose an action to perform and the fqdn you want to use.

ACTIONS:
    -h              Display this message

    -s <FQDN>       Gen and sign certificate and private key for domain <FQDN>
    -p <FQDN>       Export package for <FQDN> (KEY, CERT, CSR)
    -c <FQDN>       Check certificate of <FQDN>

    -r <FQDN>       Revoke certificate of <FQDN>
    -u              Update revocation list

EOF
    exit 0
}

######################
## SIGNATURE MODULE ##
######################
# Create private key
openssl genrsa -out private/$FQDN-key.pem $SIZE

# Certification request
openssl req \
    -config ./openssl.cnf
    -sha256 -new \
    -key private/$FQDN-key.pem \
    -out certs/$FQDN-csr.pem

# Make the CA sign the certificate
openssl ca \
    -keyfile $CAKEY \
    -cert $CACERT \
    -extensions usr_cert -notext -md sha256 \
    -in certs/$FQDN-csr.pem \
    -out certs/$FQDN-cert.pem

# Cleaning and security
chmod 400 private/$FQDN-key.pem
chmod 444 certs/$FQDN-cert.pem

######################
## PACKAGING MODULE ##
######################
tar cvzf $EXPORTDIR/$FQDN.tar.gz \
    certs/$FQDN-cert.pem
    certs/$FQDN-csr.pem
    private/$FQDN-key.pem

#####################
## CHECKING MODULE ##
#####################
# Vertify issuer
openssl x509 -in certs/$FQDN-cert.pem

# Verify signature
openssl verify -CAfile $CACERT certs/$FQDN-cert.pem

###################
## REVOKE MODULE ##
###################
openssl ca -keyfile $CAKEY -cert $CACERT -revoke certs/$FQDN-cert.pem

####################
## CRL GENERATION ##
####################
openssl ca  -keyfile $CAKEY -cert $CACERT -gencrl -out $CACRL
openssl crl -text -in $CACRL
