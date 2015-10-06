#!/bin/sh
#
# Script to automate adding users
#
# Craig White for the original script
# Youenn Piolet for latest modifications
#
# Compat: IPA 4.1. Other versions may work but you have to check the new
# user password display syntax (see Passwords detection)
#
################################################################################

## Password detection in FreeIPA Script Output
PASS="Mot de passe al"

## Main configuration
CMD1="$(which ipa) user-add"
CMD2="$(which ipa) group-add-member"
MAIL="$(which mail) -e"
TEE="$(which tee) -a"
LOG="/tmp/ipa_users_add.txt"
KERB=`klist -s; echo $?`
GGID=377400149

## Check args number + Usage
[[ -n "$4" ]] || {
    echo "$0: Invalid number of arguments." | $TEE $LOG
    cat << EOF
Usage:
$0 login Firstname Lastname email@domain.tld

This script can create users in FreeIPA and send passwords to users by email.
You can change sent messages editing the following files:
$EDITOR $TXTN
EOF
    exit 2 ; }

## Check Kerberos Credentials
[[ $KERB == "0" ]] || {
echo "$0: Kerberos ticket has expired or doesn't exist." | $TEE $LOG ;
echo "Please create a valid kerberos ticket by typing 'kinit'" ;
exit 1 ; }

## Email checking. Spoiler: this is waaaay too much.
## For more information please refer to RFC822 and:
## http://stackoverflow.com/questions/14170873/bash-regex-email-matching
#valid_email_char='[[:alnum:]!#\$%&'\''\*\+/=?^_\`{|}~-]'
#valid_login_char='[-.[a-z0-9]!#\$%&'\''\*\+/=?^_\`{|}~-]'
#email_name_part="${char}+(\.${char}+)*"
#email_domain="([[:alnum:]]([[:alnum:]-]*[[:alnum:]])?\.)+[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?"
#begin='(^|[[:space:]])'
#end='($|[[:space:]])'
## /overkill

PASSWORD=$($CMD1 $1 --first=$2 --last=$3 --random --email=$4 \
        --homedir=/ftppublic --noprivate --gidnumber=$GGID \
        | $TEE \
        | grep "$PASS" | cut -d':' -f2)
[[ -z ${PASSWORD} ]] || $MAIL -s '[BASTION] Nouveau compte FreeIPA' $4 << EOF
Bonjour $2 $3,

Vous disposez désormais d'un accès SFTP temporaire sur le serveur suivant :

    Hostname:   publicftp-fr.mediaserv.net
    Protocole:  sftp
    Port:       2222

Vos identifiants sont les suivants :

    Login : $1
    Password : ${PASSWORD}

Merci de bien vouloir contacter ingenierie@mediaserv.com en cas de perte du
mot de passe ou de dysfonctionnement.

Cordialement,
Bastion, Authentification Mediaserv
EOF
echo "Please type: kinit $1@INFRA.MSV"
echo "The Password to enter is: ${PASSWORD}"

