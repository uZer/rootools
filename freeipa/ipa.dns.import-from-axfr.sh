#!/bin/sh
# piolet.y@gmail.com
#
# Run a dig AXFR on DNS server $1, for zone $2.
# Filter entries with $3.
# You should kinit first.
#
SERVER=$1
ZONE=$2
FILTER=$3

## Print usage
usage () {
    cat << EOF
Usage:
./ipa.dns.import-from-axfr <DNSSERVER> <zone> <grep filter> -r

This script will run a dig AXFR on <DNSSERVER> for specific <zone>.
You can filter entries that contain <grep filter> in the record name.

A set of FreeIPA instructions will be generated and run.
(You should kinit first)

EOF
    return
}

#########
## RUN ##
#########
dig AXFR @$1 $2 \
    | grep "$3" \
    | grep "A\|CNAME" \
    | sort -k5 \
    | awk '{
        if ($4=="CNAME") {
            printf "ipa dnsrecord-add example.com";
            printf " \""$1"\"";
            printf " --cname-hostname=\""$5"\"\n";
        }
        else if ($4=="A") {
            printf "ipa dnsrecord-add example.com";
            printf " \""$1"\"";
            printf " --a-ip-address=\""$5"\""
            printf " --a-create-reverse\n";
        }
        else
            printf "#### ERROR: Record not recognized ####\n";
      }' \
    | sh

