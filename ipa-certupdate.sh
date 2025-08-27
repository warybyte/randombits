# Description: Forcefully update FreeIPA certificate on older versions (ones without the -Force flag)

# Backup everything! 
mkdir backup_050825 
cd backup_050825/ 
cp -r /etc/dirsrv/slapd-YOUR-IPA/ . 
cp -r /etc/httpd/alias/ . 
cp -r /var/lib/certmonger/ . 
cp -r /var/lib/ipa/certs/ . 
cp -r /var/lib/ipa/private . 
cp -r /var/lib/ipa/passwds/ . 

# Clear the expired alias from NSSDB 

# List cert alias in NSSDB 
/usr/bin/certutil -d sql:/etc/dirsrv/slapd-YOUR-IPA -L -f /etc/dirsrv/slapd-YOUR-IPA/pwdfile.txt 

# Delete expired alias
/usr/bin/certutil -D -n "CN=ipa-s01.your.domain" -d /etc/dirsrv/slapd-YOUR-IPA/ -f /etc/dirsrv/slapd-YOUR-IPA/pwdfile.txt 

# Generate PK12 version of cert/key combo matching alias name. The name MUST remain exactly the same, or DirServ won't start!

openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out ipa.p12 -name "CN=ipa-s01.your.domain" 

# Import 
pk12util -i ipa.p12 -d sql:/etc/dirsrv/slapd-YOUR-IPA -k /etc/dirsrv/slapd-YOUR-IPA/pwdfile.txt 

# Validate 
/usr/bin/certutil -d sql:/etc/dirsrv/slapd-YOUR-IPA -L -f /etc/dirsrv/slapd-YOUR-IPA/pwdfile.txt 

# Manually update the Web certificate.  
mv /var/lib/ipa/certs/httpd.crt /var/lib/ipa/certs/httpd-old.crt 
mv /var/lib/ipa/private/httpd.key /var/lib/ipa/private/httpd-old.key 
mv <NEWCERT.PEM> /var/lib/ipa/certs/httpd.crt 
mv <NEWKEY.PEM> /var/lib/ipa/private/httpd.key 
chmod 600 /var/lib/ipa/private/httpd.key 
chmod 600 /var/lib/ipa/certs/httpd.crt 

# SELINUX has been known to bork the file, so make sure to restore defaults after replacement 
/sbin/restorecon -v /var/lib/ipa/certs/httpd.crt 

# Restart services 
ipactl restart 

# Run certinstaller to verify everything is squared up (basically you've already done this, but makes sure no steps are missed during manual process) 
ipa-server-certinstall -w --pin='' privkey.pem fullchain.pem 

# Run IPA certupdate to make sure systemwide CA database is good 
ipa-certupdate 
.. Systemwide CA database updated. 
.. Systemwide CA database updated. 
.. The ipa-certupdate command was successful 

# Restart once more 
ipactl restart 
.. Restarting Directory Service 
.. Restarting krb5kdc Service 
.. Restarting kadmin Service 
.. Restarting named Service 
.. Restarting httpd Service 
.. Restarting ipa-custodia Service 
.. Restarting pki-tomcatd Service 
.. Restarting smb Service 
.. Restarting winbind Service 
.. Restarting ipa-otpd Service 
.. Restarting ipa-dnskeysyncd Service 
.. ipa: INFO: The ipactl command was successful 

# Log into web portal or test connection using Openssl 
openssl s_client -connect ipa-s01.domain.name:389 -starttls ldap 
