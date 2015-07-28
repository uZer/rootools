SPATH="/etc/apache2/nssdb"
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

## BACKUP
#mv $NSSPATH $NSSPATH.old.`date +%s` &>/dev/null
rm -rf $NSSPATH

## PREPARE
mkdir -p $NSSPATH
cd $NSSPATH
echo "$PASSWORD" > $PWDFILE
echo "internal:$PASSWORD" > $MODNSS_PASSWD
chmod go-rwx $PWDFILE
certutil -N -d $NSSPATH -f $PWDFILE
chown :www-data $NSSPATH/*.db
chown root:www-data $MODNSS_PASSWD
chmod 640 $MODNSS_PASSWD
chmod g+rw $NSSPATH/*.db

# Add CA
certutil -A -d . -n 'INFRA.MSV IPA CA' -t CT,, -a < $CAFILE

# Sign Cert
ipa-getcert request -d $NSSPATH -n $CERTNAME -g 2048 -p $PWDFILE \
    -N "CN=$FQDN,O=$DOMAIN" -D "$CNAME" -K $PRINCIPAL

## OUTPUT
echo "Check status:"
echo "          ipa-getcert list -d $NSSPATH -n $CERTNAME"
echo "Show certificate:"
echo "          certutil -L -d $NSSPATH -n $CERTNAME"
echo "Check validity:"
echo "          certutil -V -u V -d  $NSSPATH -n $CERTNAME"
echo "Delete certmonger request:"
echo "          ipa-getcert stop-tracking -i \$ID"

ipa-getcert list -d /etc/apache2/nssdb -n Server-Cert
