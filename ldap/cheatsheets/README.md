## LDAP Cheat sheets

If you need to apply any ldif file, use the following syntax:

	ldapmodify -Y EXTERNAL -H ldapi:/// -f ldap.acl.modify.ldif

See .sh files for precisions

If you need to display the content of your directory :

     ldapsearch -LLLQY EXTERNAL -H ldapi:/// -b dc=ldap,dc=lan

If you need to display your LDAP configuration :

     ldapsearch -LLLQY EXTERNAL -H ldapi:/// -b cn=config

Have fun
