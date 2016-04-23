#!/usr/bin/env bash
## ExoBGP: Check DNS resolution
## Return state
##
STATE="down"
VERBOSE=true

_IP=""
_LO=""

## CHECK DNS
dig

if [[ $? == 0 ]]; then
    if [[ "_STATE" != "up" ]]; then
        echo "announce $_LO next-hop self"
        _STATE="up"
    fi
else
    if [[ "_STATE" != "down" ]]; then
        echo "withdraw $_LO next-hop self"
        _STATE="down"
    fi
fi
