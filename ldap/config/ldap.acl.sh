#!/bin/sh
#
# Change ACL for ldap with cn=config and no slapd.conf

## Read existing ACL
ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -W -b cn=config '(olcDatabase={1}hdb)' olcAccess

## Create ldif file with desired access levels
cat > ldap.acl.modify.ldif << EOF
dn: olcDatabase={1}hdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange
  by self write
  by anonymous auth
  by dn="cn=admin,dc=ldap01,dc=lan" write
  by dn="cn=lam,ou=ldapusers,dc=ldap01,dc=lan" write
  by users none
  by * none
olcAccess: {1}to *
  by dn="cn=admin,dc=ldap01,dc=lan" write
  by dn="cn=lam,ou=ldapusers,dc=ldap01,dc=lan" write
  by users read
  by * none
EOF

## If you need to delete a specific ACL according to its ID
cat > ldap.acl.deleteid.ldif << EOF
dn: olcDatabase={1}hdb,cn=config
delete: olcAccess
olcAccess: {2}
olcAccess: {3}
EOF

## Apply changes
# ldapmodify -Y EXTERNAL -H ldapi:/// -f ldap.acl.modify.ldif
