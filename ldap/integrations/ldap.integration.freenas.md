## Integrate LDAP authentification on FreeNAS
These instructions work perfectly with FreeNAS-9.3-STABLE-201412312006. I hope
it will work on your setup.

### SETTINGS
Basic configuration

	hostname:               hostname.of.your.ldap.com
	Base DN:                dc=ldap,dc=lan
	
If you have a specific user you want to bind for searching your LDAP (which I
highly recommand) use these two lines.

	Bind DN:                cn=freenas,ou=ldapusers,dc=ldap,dc=lan
	Bind password:          *********

Otherwise, you can tick the anonymous box.

Then, identify the location of your LDAP elements. You don't need to append
the Base DN here.

	User Suffix:            ou=people
	Group Suffix:           ou=groups
	Password Suffix:        ou=people
	Machine Suffix:         ou=computers
	SUDO Suffix:            cn=sudoers,ou=authent,ou=groups

Define your encryption method if you need to. You should import your server CA
certificate if you use self signed certificates. *Don't* disable the 
verification as you will read on Internet. This would highly reduce the security
of your encryption since anyone could claim being the LDAP server.
To import your ca-certificate.pem you can go to System > CAs > Import CA.
If your FreeNAS is NOT the CA, don't put the Private Key in the import form.

	Encryption Mode:        TLS
	Certificate:            <select>

Welcome to the fun part. If you don't configure this correctly, you may have to
enjoy hours of troubleshooting with minimum logging.

Your LDAP backend is the norm you follow to organize your entries in the LDAP.
For example if you decide to use uniqueMember entries in groups, it will not
be the same norm as if you decide to use memberUid to identify your users.
Check the documentation of your LDAP. If you use LAM, I suggest rfc2307.
You can also read this :
http://ludopoitou.wordpress.com/2011/04/20/linux-and-unix-ldap-clients-and-rfc2307-support/

	Idmap Backend:          rfc2307

Hoi! You fanny, uh! This is NOT rfc2307 you just selected. This actually is
rfc2307bis. Took me hours to figure this out. If you really need to use
rfc2307 and not the newer draft, use Auxiliary Parameters to set this up.


	Samba Schema:           OK

If you have samba schema installed. Please refer to schema importation methods
in my LDAP cheatsheet folder.

This will do the magic in Auxiliary Parameters (these instructions will be
wrote in your system's sssd.conf. Don't trust what you can read on the
Internet. I saw tons of forums suggesting other settings with a different
syntax that doesn't work but will produce NO error output.
	
	ldap_schema = rfc2307

### Additional Information
You may not want to create any user in your FreeNAS web interface and use LDAP
directory instead. I highly suggest the usage of LAM (LDAP Account Manager) for
your user administration. This tool is opensource, native in most distributions
and  works perfectly if you want to build a CIFS Domain Controler for example.

You may still have to use NAS's webconfiguration page to create shares. More
information about thismay appear here sooner or later.

Good debug tools:

	[root@freenas] ~# getent group
	[root@freenas] ~# getent passwd
	[root@freenas] ~# tail -f /var/log/syslog
	[root@freenas] ~# tail -f /var/log/samba4/*
	[root@freenas] ~# cat /etc/local/smb4.conf
	[root@freenas] ~# cat /etc/nsswitch.conf 
	[root@freenas] ~# cat /etc/local/sssd/sssd.conf <-- And compare this to a working config

	And obviously : your ldap logs.
