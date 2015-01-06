#!/bin/sh
#
# Change ACL for ldap with cn=config and no slapd.conf

## Please configure this before to start
DN='dc=thecore,dc=thevoid'
BACKEND='olcDatabase={1}mdb'

## Read existing ACL
## Change with the correct backend : HDB/MDB/BDB
echo "Existing situation :"
sudo ldapsearch -LLLQY EXTERNAL -H ldapi:/// -b cn=config "$BACKEND" olcAccess

## Create ldif file with desired access levels
cat > ldap.acl.modify.ldif << EOF
dn: $BACKEND,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange
  by self write
  by anonymous auth
  by dn="cn=admin,$DN" write
  by dn="cn=lam,ou=ldapusers,$DN" write
  by users none
  by * none
olcAccess: {1}to *
  by dn="cn=admin,$DN" write
  by dn="cn=lam,ou=ldapusers,$DN" write
  by users read
  by * none
EOF

## If you need to delete a specific ACL according to its ID
cat > ldap.acl.deleteid.ldif << EOF
dn: $BACKEND,cn=config
delete: olcAccess
olcAccess: {2}
olcAccess: {3}
EOF

## Apply changes
echo "Please edit ldif file according to your needs"
echo
echo "To apply your changes:"
echo sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f ldap.acl.modify.ldif
