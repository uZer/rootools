#!/bin/sh
#
# Change verbosity of logs

## Please configure this before to start
DN='dc=thecore,dc=thevoid'
BACKEND='olcDatabase={1}mdb'

## Read existing ACL
## Change with the correct backend : HDB/MDB/BDB
echo "Existing situation :"
sudo ldapsearch -LLLQY EXTERNAL -H ldapi:/// -b cn=config -s base olcLogLevel

## Create a ldif file
##
## Cf. http://www.openldap.org/doc/admin24/slapdconf2.html
##
## LEVEL        DESCRIPTION
## trace	    trace function calls
## packets	    debug packet handling
## args	        heavy trace debugging
## conns	    connection management
## BER	        print out packets sent and received
## filter	    search filter processing
## config	    configuration processing
## ACL	        access control list processing
## stats	    stats log connections/operations/results
## stats2	    stats log entries sent
## shell	    print communication with shell backends
## parse	    print entry parsing debugging
## sync	        syncrepl consumer processing
## none	        only messages that get logged whatever log level is set
cat > ldap.logging.modify.ldif << EOF
dn: cn=config
changetype: modify
add: olcLogLevel
olcLogLevel: stats
EOF

cat > ldap.logging.delete.ldif << EOF
dn: cn=config
changetype: modify
delete: olcLogLevel
EOF

## Apply changes
echo "Please edit ldif file according to your needs."
echo "slapd may puke logs in /var/log/syslog by default."
echo
echo "To apply your changes:"
echo sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ldap.logging.modify.ldif
