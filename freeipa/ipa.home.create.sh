#!/bin/bash
# Crontab: Create home for specific users
set -euo pipefail
IFS=$'\n\t'


SEARCH=$(ldapsearch -x -h freeipa.server -b cn=sys_hashome,cn=groups,cn=compat,dc=example,dc=com | grep memberUid | cut -d" " -f2)
for i in $SEARCH; do
    echo "Checking home for $i..."
    if [[ ! -d /home/$i ]]; then
        echo "  Creating Home..."
        sudo su $i -c 'echo "  OK"; exit'
    fi
    echo "Changing home owner for $i..."
    chown $i:$i /home/$i
done

exit 0

