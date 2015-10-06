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
# IPA Admin tool must be installed
#
################
## PARAMETERS ##
################################################################################

## Binary location
CMD1="$(which ipa) user-add"
CMD2="$(which ipa) group-add-member"
MAIL="$(which mail) -e"
TEE="$(which tee) -a"

## Data sources
LOG="/tmp/ipa_users_add.txt"                # Log file
TXTN="/tmp/ipa_users_add.txt"               # Email content
KERB=`klist -s; echo $?`                    # To check if we got a ticket

## We want to let IPA create password on its own. For that we need to detect
## Password in IPA output after creating the user (quick and dirty)
PASS="Mot de passe al"                      # used in grep "$PASS"

###############
## FUNCTIONS ##
################################################################################

## Print usage
usage () {
    cat << EOF
Usage:
./ipa-add-user.sh login Firstname Lastname email@domain.tld

This script can create users in FreeIPA and send passwords to users by email.
EOF
#You can change sent messages editing the following files:
#$EDITOR $TXTN
#EOF
    return
}

##########
## MAIN ##
################################################################################

## Check args number and print usage if some are missing
[[ -n "$4" ]] || {
    echo "$0: Invalid number of arguments." | $TEE $LOG
    usage
    exit 2
}

## Check Kerberos Credentials
[[ $KERB == "0" ]] || {
echo "$0: Kerberos ticket has expired or doesn't exist." | $TEE $LOG ;
echo "Please create a valid kerberos ticket by typing 'kinit'" ;
exit 1 ; }

PASSWORD=$($CMD1 $1 --first=$2 --last=$3 --random --email=$4 \
        | $TEE \
        | grep "$PASS" | cut -d':' -f2)
[[ -z $PASSWORD ]] || $MAIL -s '[BASTION] Nouveau compte FreeIPA' $4 << EOF
Bonjour $2,

Tes accès BASTION (FreeIPA, notre outil d’authentification centralisée)
sont les suivants :

    Login : $1
    Password : $PASSWORD

Tu peux administrer ton compte via https://freeipa.infra.msv/ au sein du réseau
de bureautique Mediaserv. Un petit popup de connexion peut apparaitre dans
certains navigateurs, il faudra cliquer sur annuler. Il te sera demandé de
changer ton mot de passe lors de ta première connexion.

Ton mot de passe est strictement personnel et ne doit être communiqué à
personne, pas même un administrateur. Nous pourrons te le régénérer en cas
d’oubli.

La liste des services accessibles via ce compte est disponible ici, depuis le
réseau de bureautique :

http://confluence.infra.msv/display/WELCOME/Services+Accessibles+via+Bastion


Contacte ingenierie@mediaserv.com en cas de perte de ton mot de passe ou de
dysfonctionnement.

Cordialement,
Bastion
EOF
