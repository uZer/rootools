#!/bin/sh
#
# Configure LDAP server to use TLS with cn=config

## Please configure this before to start
CA_CERT="/etc/ssl/certs/cacert.pem"
SRV_KEY="/etc/ssl/private/server-key.pem"
SRV_CERT="/etc/ssl/certs/server-cert.pem"

## Read existing CipherSuite
echo "Existing situation :"
sudo ldapsearch -LLLQY EXTERNAL -H ldapi:/// -b cn=config -s base oclTLSCipherSuite

## Adding TLS server suit
cat > ldap.tls.certif.ldif << EOF
dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: $CA_CERT
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $SRV_KEY
-
add: olcTLSCertificateFile
olcTLSCertificateFile: $SRV_CERT
EOF

## Change authorized protocols (Only TLS 256, no SSLv3)
##
## cf. http://gnutls.org/manual/html_node/Priority-Strings.html
##
## SECURE256:
## Means all the known to be secure ciphersuites that offer a security level
## 192-bit or more. The message authenticity security level is of 128 bits or
## more, and the certificate verification profile is set to
## GNUTLS_PROFILE_HIGH (128-bits).
cat > ldap.tls.modify.ldif << EOF
dn: cn=config
changetype: modify
add: olcTLSCipherSuite
olcTLSCipherSuite: SECURE256:-VERS-SSL3.0
EOF

## Apply changes
echo "Please edit ldif file according to your needs"
echo
echo "To apply your changes:"
echo sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ldap.tls.certif.ldif
echo sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ldap.tls.modify.ldif
