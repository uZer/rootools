#!/bin/bash
# Create and pack client openvpn configuration for a specific host
set -euo pipefail
IFS=$'\n\t'


SEARCH=$(ldapsearch -x -h freeipa.server -b cn=sys_ssh,cn=groups,cn=compat,dc=example,dc=com | grep memberUid | cut -d" " -f2)
for i in $SEARCH; do
    echo "Checking home for $i..."
    if [[ ! -d /home/$i ]]; then
        echo "  Creating Home..."
        sudo su $i -c 'echo "  OK"; exit'
    fi
done

exit 0

