## Integrate LDAP authentification on FreeNAS

Basic configuration

	hostname:               fr-1vm-sso01.infra.msv
	Base DN:                dc=fr-1vm-sso01,dc=infra,dc=msv
	
If you have a specific user you want to bind for searching your users

	Bind DN:                cn=freenas,ou=ldapusers,dc=fr-1vm-sso01,dc=infra,dc=msv
	Bind password:          *********

Otherwise, you can tick the anonymous box.
Put here the location of your ldap elements

	User Suffix:            ou=people
	Group Suffix:           ou=groups
	Password Suffix:        ou=people
	Machine Suffix:         ou=computers
	SUDO Suffix:            cn=sudoers,ou=authent,ou=groups

Define you encryption method if you need to. You should import your server CA
certificate if you use self signed certificates. This can be done in
System > CAs > Import CA. If your FreeNAS is NOT the CA, don't put the Private
Key in the import form.

	Encryption Mode:        TLS
	Certificate:            <select>

Welcome to the fun part. If you don't configure this correctly, you may have to
enjoy hours of troubleshooting with minimum logging.

Your LDAP backend is the norm you follow to name your entries in ldap. For
example if you decide to use uniqueMember entries in groups, it will not
be the same backend as if you decide to use memberUid to identify your users.
Check the documentation of your LDAP. If you use LAM, I suggest rfc2307.

	Idmap Backend:          rfc2307

Hoi! You fanny, uh! This is NOT rfc2307 you just selected. This actually is
rfc2307bis. Took me hours to figure this out. If you really need to use
rfc2307 and not the newer draft, use Auxiliary Parameters to set this up.


	Samba Schema:           OK

If you have samba schema installed. Please refer to schema importation methods
in the LDAP cheatsheet folder.

This will do the magic:
	 
	Auxiliary Parameters:   ldap_schema = rfc2307

_Additional Information_
You don't want to create any use in your FreeNAS web interface. Use LDAP
directly instead. I highly suggest the usage of LAM (LDAP Account Manager)
which works perfectly if you want to build a CIFS Domain Controler.

