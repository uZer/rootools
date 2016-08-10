#!/bin/bash
#
# Takes a list of record in a file ($1)
# Imports records to FreeIPA only if necessary.
#
# To build the list:
# dig AXFR @$DNS $DOMAIN | grep "A\|CNAME" | awk '{ print $4" "$1" "$5 }' \
#                        | grep -v 'SOA ' | grep -v '<<>>' | sort -k1,2   \
#                        | tr '[:upper:]' '[:lower:]' | sed 's/$/ \$DOMAIN/g' \
#           > reclist.$DOMAIN
#
# Support:
# <youenn.piolet@mediaserv.com>
################################################################################
source ~/log4bash/log4bash.sh
set -u
set +e
IFS=$'\n\t '

# Put here your new FreeIPA DNS
DNS="10.0.0.1"
LOG=".conflicts"

# If set to "no", public IP reverse zones won't be managed
ALLOWPUBLICIP="no"

USELESSNS="list. of. servers. you. dont. want. in. soa."
AXFRLIST="<ip of servers allowed to AXFR separated by;>"
AXFRLIST="10.1.11.81;10.1.11.82;10.1.11.83;10.2.11.81;10.2.11.82;10.2.11.83;10.3.11.81;10.3.11.82;10.3.11.83;10.4.11.81;10.4.11.82;10.4.11.83;10.5.11.83;192.168.50.47;192.168.50.41"

## Print usage
usage () {
    cat << EOF
Usage:
./ipa.dns.import-from-axfr <type> <record> <value> <zone>
(You should kinit first)

EOF
    return
}

## Check if the reverse is present in DNS (FreeIPA)
## $1 <= Type (a, cname, ptr)
## $2 <= Record to check (hostname or ip, not fqdn)
## $3 <= Theorical record value (ip or fqdn.)
## $4 <= If it is a reverse, should be -x
## returns 0 if not found, 1 if already exists, 2 if conflict
checkRecord() {
    _TYPE=$1
    _NAME=$2
    _TV=$3
    __ptr=""
    IFS=$'\n'
    if [[ "$_TYPE" == "ptr" ]]; then
        __ptr="-x"
    else
        _NAME=$_NAME.$ZONE
    fi
    __cmd=$(dig +short +answer $__ptr $_NAME @$DNS)

    # Doesn't exist
    if [[ "$__cmd" == "" ]]; then
        return 0
    else
        # Sometimes, there are multiple answers. Here we check only one value.
        __RES=2
        for __i in $__cmd; do
            if [[ $__i == $_TV ]]; then __RES=1 ; fi
        done

        if [[ $__RES -eq 1 ]]; then
            return 1
        else
            # Conflict
            return 2
        fi
    fi
}

## Add A record where $1 is the record and $2 is the IP
## Takes a global zone variable
## Do not put FQDN in $1
addA() {
    _NAME=$1
    _IP=$2
    ipa dnsrecord-add $ZONE $_NAME --a-ip-address=$_IP
}

## Add PTR record where $1 is the IP and $2 the FQDN
addRev() {
    _IP=$1
    _FQDN=$2
    _REVZONE=`echo $_IP | awk -F'.' '{ print $3"."$2"."$1".in-addr.arpa" }'`
    _ID=`echo $_IP | awk -F'.' '{ print $4 }'`


    ## DON'T ADD PUBLIC
    if [[ $ALLOWPUBLICIP == "no" && ! $_IP =~ ^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.|^192\.168\. ]]; then
        log_debug "PUBLIC IP - Doing nothing."
        return
    fi
    ipa dnsrecord-add $_REVZONE $_ID --ptr-hostname $_FQDN
}

## Add CNAME record where $1 is the record and $2 is the FQDN
## Takes a global zone variable
## Do not put FQDN in $1
addCNAME() {
    _NAME=$1
    _FQDN=$2
    ipa dnsrecord-add $ZONE $_NAME --cname-hostname=$_FQDN
}


## Add generic record to DNS and reverse PTR if necessary
## $1 <= Type (a, cname, ptr)
## $2 <= Record to check (hostname or ip, not fqdn)
## $3 <= Theorical record value (ip or fqdn.)
## Log in .conflict
addRecord() {
    _TYPE=$1
    _NAME=$2
    _VALUE=$3
    log_debug "START RECORD: $_TYPE $_NAME $_VALUE (Domain $ZONE)"
    checkRecord $1 $2 $3
    case $? in
        ## CONFLICTS
        2)  echo "      $1 $2 $3" >> $LOG
            log_warning "*** $_NAME is already in $DNS but there's a conflict. Doing nothing."
            log_debug "END RECORD: $_TYPE $_NAME $_VALUE (Domain $ZONE)"
            return 1
            ;;

        ## ALREADY GOOD
        1)  log_warning "*** $_TYPE $_NAME ($_TV) is already in $DNS. Doing nothing."
            log_debug "END RECORD: $_TYPE $_NAME $_VALUE (Domain $ZONE)"
            echo ""
            if [[ $_TYPE == "a" ]]; then addRecord "ptr" "$_VALUE" "$2.$ZONE." ; fi
            return 0
            ;;

        ## ADDING...
        0)  log_debug "*** $_TYPE $_NAME ($_TV) is not in $DNS. Adding..."
            case $1 in
                "cname" )   addCNAME    $2 $3 ;;
                  "ptr" )   addRev      $2 $3 ;;
                    "a" )   addA        $2 $3
                            addRecord "ptr" "$_VALUE" "$2.$ZONE."
                            ;;
            esac
            log_debug "END RECORD: $_TYPE $_NAME $_VALUE (Domain $ZONE)"
            echo ""
            return 0
            ;;
    esac
}

## Prepare list
parseAndAddRecord () {
    IFS=$'\n\t '
    _TYPE=$1
    _NAME=$2
    _VALUE=$3
    ZONE=$4
    ## Check args
    if [[ $# -ne 4 ]]; then
        log_error "Invalid number of arguments."
        usage
        exit 3
    fi

    ## We remove the domain part of the record if any
    case $1 in
        "cname" | "a") _KEY=`echo $2 | cut -d '.' -f1` ;;
                    *) _KEY=$1 ;;
    esac

    addRecord $_TYPE $_KEY $_VALUE
}

## Add list of zones in DNS
## Remove useless ns records
addZoneList () {
    _ZONELIST=$1
    IFS=$' '
    for _i in `echo $TOADD`; do
        log_debug "Adding zone $_i..."
        ipa dnszone-add $_i --dynamic-update=TRUE --allow-transfer="$AXFRLIST" --allow-sync-ptr=TRUE --name-server="fr-1vm-ipa01.infra.msv."
        for _j in `echo $USELESSNS`; do
            log_debug "Erasing NS $_j..."
            ipa dnsrecord-del --ns-rec="$_j" $_i @
        done
        log_debug "Done."
    done
    return
}
################################################################################

## Parse file and add
LIST=$1
if [[ ! -f $LIST ]]; then
    log_error "File $LIST doesn't exist."
    exit 10
fi

## Adding new zones if necessary
# We only add private zones
log_debug "START importing file $LIST " >> $LOG
ipa dnszone-find --sizelimit=10000 --raw | grep 'idnsname:' | grep "in-addr.arpa" | awk '{ print $2 }' | sort > .zonelist
cat $LIST | grep '^a\ ' | cut -d' ' -f3 | awk -F'.' '{ print $3"."$2"."$1".in-addr.arpa."}' | sort | uniq > .addzonelist

# Extracting public zone if necessary, and only new zone
if [[ $ALLOWPUBLICIP == "no" ]]; then
    TOADD=$(comm -1 -3 .zonelist .addzonelist | grep -E '(168\.192\.in|\.10\.in|\.1[6789]\.172\.in|\.2[0-9]\.172\.in|\.3[01]\.172\.in)' | xargs)
else
    TOADD=$(comm -1 -3 .zonelist .addzonelist | xargs)
fi

if [[ ! $TOADD == "" ]]; then
    log_debug "The following zones will be added:"
    log_debug "$TOADD"
    addZoneList $TOADD
else
    log_debug "No zones to add."
fi

IFS=$'\n'
log_debug " ---- the following entries can't be added due to conflict ----" >> $LOG
for i in `cat $LIST`; do
    IFS=$' '
    parseAndAddRecord ${i[@]}
done

log_debug "END importing file $LIST" >> $LOG
echo "" >> $LOG
log_debug "Output in $LOG"
exit 0
##
###########
#### RUN ##
###########
##dig AXFR @$SERVER $ZONE \
##    | grep "$FILTER" \
##    | grep "A\|CNAME" \
##    | sort -k5 \
##    | awk '{
##        if ($4=="CNAME") {
##            printf "ipa dnsrecord-add net.dsp";
##            printf " \""$1"\"";
##            printf " --cname-hostname=\""$5"\"\n";
##        }
##        else if ($4=="A") {
##            printf "ipa dnsrecord-add net.dsp";
##            printf " \""$1"\"";
##            printf " --a-ip-address=\""$5"\""
##            printf " --a-create-reverse\n";
##        }
##        else
##            printf "#### ERROR: Record not recognized ####\n";
##      }' \
##    | sh
##
