#!/bin/sh
# Sign and revoke certificates
FQDN="test"
PKIDIR="/srv/pki-infra.msv-intermediate"
CAKEY="private/ca-intermediate.infra.msv-key.pem"
CACERT="certs/ca-intermediate.infra.msv-cert.pem"
EXPORTDIR="$PKIDIR/exports"
SIZE="4096"

cd $PKIDIR

###################
## HELP & PARAMS ##
###################

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
