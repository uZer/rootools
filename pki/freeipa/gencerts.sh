#!/bin/sh

## VARIABLES
NSSPATH="/etc/apache2/nssdb"
PWDFILE="$NSSPATH/pwdfile.txt"

CAFILE="/etc/ipa/ca.crt"
CERTNAME="Server-Cert"

DOMAIN="INFRA.MSV"
FQDN=`hostname`
PRINCIPAL="HTTP/$FQDN"

## MAKE DB AND FETCH CERT
mv $NSSPATH $NSSPATH.old.`date +%s`
mkdir -p $NSSPATH
cd $NSSPATH
echo `openssl rand -base64 32` > $PWDFILE
chmod go-rwx $PWDFILE
certutil -N -d $NSSPATH -f $PWDFILE
chown :www-data $NSSPATH/*.db
chmod g+rw $NSSPATH/*.db
certutil -A -d . -n 'INFRA.MSV IPA CA' -t CT,, -a < $CAFILE
ipa-getcert request -d $NSSPATH -n $CERTNAME -K $PRINCIPAL -N CN=$FQDN,O=$DOMAIN -g 2048 -p $PWDFILE

echo "Check status:"
echo "      ipa-getcert list -d $NSSPATH -n $CERTNAME"
echo "Show certificate:"
echo "      certutil -L -d $NSSPATH -n $CERTNAME"
echo "Check validity:"
echo "      certutil -V -u V -d  $NSSPATH -n $CERTNAME"
echo "Delete certmonger request:"
echo "      ipa-getcert stop-tracking -i \$ID"

exit 0

