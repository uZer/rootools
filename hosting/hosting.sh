#!/bin/bash
WEBROOT="/home/data/hosting"
CHROOTDIR="/srv/hosting/chroot"
DEFAULTSH="/sbin/nologin"
SFTPGROUP="sftpaccess"
NGINXUSER="www-data"

addwebgroup () {
    _GROUPNAME=${1}

    # Creating group if necessary
    cat /etc/group | cut -d ":" -f1 | grep -qi $_GROUPNAME
    if [ $? -eq 0 ]; then
        echo "Group $_GROUPNAME already exists"
    else
        echo "Creating group $_GROUPNAME"
        groupadd $_GROUPNAME
    fi

    # Folder
    mkdir $WEBROOT/$_GROUPNAME 2>/dev/null

    # Chmod
    echo "Giving access to the shared space $WEBROOT/$_GROUPNAME"
    chmod -R 770 $WEBROOT/$_GROUPNAME
    chown -R root:$_GROUPNAME $WEBROOT/$_GROUPNAME
    find $WEBROOT/$_GROUPNAME -type d -exec chmod g+s {} \;

    # www-data NGINX
    groups $NGINXUSER | grep -qi $_GROUPNAME
    if [ $? -eq 0 ]; then
        echo "$NGINXUSER already in group $_GROUPNAME"
    else
        echo "Adding $NGINXUSER to the $_GROUPNAME group"
        usermod -a -G $_GROUPNAME $NGINXUSER
    fi
    return
}

addwebuser () {
    _USERNAME=${1}
    _GROUPNAME=${2}

    ## CALL GROUP FIRST IF NEEDED ##
    cat /etc/group | cut -d ":" -f1 | grep -qi $_GROUPNAME
    if [ ! $? -eq 0 ]; then
        echo "Group $_GROUPNAME doesn't exist. Creating $_GROUPNAME first..."
        echo
        addwebgroup $_GROUPNAME
        echo
    fi
    ################################

    # Creating user
    id $_USERNAME 2>&1 >/dev/null
    if [ $? -eq 0 ]; then
        echo "User already exists"
        # Placing user in correct group
        groups $_USERNAME | grep -qi $_GROUPNAME
        if [ $? -eq 0 ]; then
            echo "User already in group $_GROUPNAME"
        else
            echo "Adding user to the $_GROUPNAME group"
            usermod -a -G $_GROUPNAME $_USERNAME
        fi
    else
        echo "Creating user"
        useradd \
            -c "Webuser ${_USERNAME}" \
            -d ${CHROOTDIR}/${_USERNAME} \
            -G ${_GROUPNAME},${SFTPGROUP} \
            -M -N -s ${DEFAULTSH} ${_USERNAME}
    fi

    # Placing user in correct group
    groups $_USERNAME | grep -qi $SFTPGROUP
    if [ $? -eq 0 ]; then
        echo "User already in group $SFTPGROUP"
    else
        cat /etc/passwd | egrep "^$_USERNAME" | cut -d ":" -f 6 | egrep -qi "$CHROOTDIR"
        if [ $? -eq 0 ]; then
            echo "This is a chrooted user. Putting in sftpaccess"
            usermod -a -G $SFTPGROUP $_USERNAME
        else
            echo "This is not a chrooted user. Skipping sftpaccess."
        fi
    fi

    echo "Creating home bindings"
    _HOMEDIR=`cat /etc/passwd | egrep "^$_USERNAME" | cut -d ":" -f6`
    mkdir -p ${_HOMEDIR}/${_GROUPNAME} 2>/dev/null
    chmod a+r "${_HOMEDIR}"
    mount | grep -qi ${_HOMEDIR}/${_GROUPNAME}
    if [ $? -eq 0 ]; then
        echo "Group folder $_GROUPNAME already made accessible in chroot dir"
    else
        echo "Making group folder accessible for user"
        echo "$WEBROOT/$_GROUPNAME ${_HOMEDIR}/${_GROUPNAME} none bind,umask=007 0 0" >> /etc/fstab
        mount -a
    fi

    # Password
    echo "Changing password for $_USERNAME"
    passwd $_USERNAME
    echo "OK"
    return
}

addwebsite () {
    _SERVICE=${1}
    _GROUPNAME=${2}
    cat /etc/group | cut -d ":" -f1 | grep -qi $_GROUPNAME
    if [ ! $? -eq 0 ]; then
        echo "Group $_GROUPNAME doesn't exist. Creating $_GROUPNAME first..."
        echo
        addwebgroup $_GROUPNAME
        echo
    fi

    mkdir -p $WEBROOT/$_GROUPNAME/$_SERVICE 2>/dev/null
    chown -R :$_GROUPNAME $WEBROOT/$_GROUPNAME/$_SERVICE
    chmod -R 770 $WEBROOT/$_GROUPNAME/$_SERVICE
    return
}

usage () {
    echo "Usage: $0 \[addwebsite|addwebgroup|addwebuser\] \[PARAMS\]"
    echo "$0 addwebgroup groupname"
    echo "$0 addwebuser username groupname"
    echo "$0 addwebsite sitename groupname"
    return
}

# Let's do this
ACTION=$1
OBJECT=$2
GPNAME=$3

if [ ${ACTION} == "addwebsite" ]; then
    if [ "$#" -ne 3 ]; then
        echo "Illegal number of parameters"
        usage
        exit 1
    fi
    [[ ! $OBJECT =~ ^[-a-z]{1,20}$ ]] && echo "Wrong object format." && exit 2
    [[ ! $GPNAME =~ ^www-[-a-z]{1,20}$ ]] && echo "Wrong group format. Must \
        start with www-" && exit 2
    echo "Action: Adding $OBJECT as a new website owned by $GPNAME"
    addwebsite $OBJECT $GPNAME
    exit 0

elif [ ${ACTION} == "addwebgroup" ]; then
    if [ "$#" -ne 2 ]; then
        echo "Illegal number of parameters"
        usage
        exit 1
    fi
    [[ ! $OBJECT =~ ^www-[-a-z]{1,20}$ ]] && echo "Wrong object format." && exit 2
    echo "Action: Adding $OBJECT as a group"
    addwebgroup $OBJECT
    exit 0

elif [ ${ACTION} == "addwebuser" ]; then
    if [ "$#" -ne 3 ]; then
        echo "Illegal number of parameters"
        usage
        exit 1
    fi
    [[ ! $OBJECT =~ ^[-a-z]{1,20}$ ]] && echo "Wrong object format." && exit 2
    [[ ! $GPNAME =~ ^www-[-a-z]{1,20}$ ]] && echo "Wrong group format. Must \
        start with www-" && exit 2
    echo "Action: Adding $OBJECT as a new user in $GPNAME"
    addwebuser $OBJECT $GPNAME
    exit 0

else
    echo "Genius"
    usage
    exit 10
fi
