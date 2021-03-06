#!/bin/bash

HOSTNAME=`hostname -s`
LOCATION=`ifconfig eth0 | grep inet | awk -F: '{ print $2 }' | awk -F. '{ print $3 }'`

case "${LOCATION}" in
	# UKDC01
	0) DOMAIN="tream360.cloud"
		PRE1="192.168.0"
		PRE2="192.168.4"
		NS1="c1001"
		NS2="c1002"
		NS3="dc1001"
		NS4="dc1002"
		;;
	# UKDC02
	4) DOMAIN="tream360.cloud"
		PRE1="192.168.4"
		PRE2="192.168.0"
		NS1="dc1001"
		NS2="dc1002"
		NS3="c1001"
		NS4="c1002"
		;;
	# USDC01
	28) DOMAIN="tream360.cloud"
		PRE1="192.168.28"
		PRE2="192.168.32"
		NS1="dc1001"
		NS2="dc1002"
		NS3="dc1001"
		NS4="dc1002"
		;;
	# USDC02
	32) DOMAIN="tream360.cloud"
		PRE1="192.168.32"
		PRE2="192.168.28"
		NS1="dc1001"
		NS2="dc1002"
		NS3="dc1001"
		NS4="dc1002"
		;;
	# USDC03
	60 | 61) DOMAIN="tream360.cloud"
		PRE1="192.168.60"
		PRE2="192.168.28"
		NS1="dc1001"
		NS2="dc1002"
		NS3="dc1001"
		NS4="dc1002"
		;;
esac

REALM=`echo ${DOMAIN} | tr '[:lower:]' '[:upper:]'`
WORKGROUP=`echo ${REALM} | awk -F. '{ print $1 }'`

# Install required packages
yum install samba samba-winbind oddjob-mkhomedir

# update resolv.conf
mv /etc/resolv.conf /etc/resolv.conf.orig
cat <<RESOLV >> /etc/resolv.conf
domain ${DOMAIN}
search ${DOMAIN}
nameserver ${PRE1}.132
nameserver ${PRE1}.135
RESOLV

# update smb.conf
PWSERVER="${NS1}.${DOMAIN} ${NS2}.${DOMAIN} ${NS2}.${DOMAIN} ${NS3}.${DOMAIN} ${NS4}.${DOMAIN}"
mv /etc/samba/smb.conf /etc/samba/smb.conf.orig
cp smb.conf.winbind /etc/samba/smb.conf
sed -i "s/HOSTNAME/${HOSTNAME}/g" /etc/samba/smb.conf
sed -i "s/DOMAIN/${DOMAIN}/g" /etc/samba/smb.conf
sed -i "s/WORKGROUP/${WORKGROUP}/g" /etc/samba/smb.conf
sed -i "s/PWSERVER/${PWSERVER}/g" /etc/samba/smb.conf

# update nsswitch.conf
cp /etc/nsswitch.conf /etc/nsswitch.conf.orig
sed -i 's/passwd:\s*files/& winbind/' /etc/nsswitch.conf
sed -i 's/group:\s*files/& winbind/' /etc/nsswitch.conf

# update krb5.conf
mv /etc/krb5.conf /etc/krb5.conf.orig
cp krb5.conf.winbind /etc/krb5.conf
sed -i "s/REALM/${REALM}/g" /etc/krb5.conf
sed -i "s/DOMAIN/${DOMAIN}/g" /etc/krb5.conf
sed -i "s/NS1/${NS1}/g" /etc/krb5.conf
sed -i "s/NS2/${NS2}/g" /etc/krb5.conf
sed -i "s/NS3/${NS3}/g" /etc/krb5.conf
sed -i "s/NS4/${NS4}/g" /etc/krb5.conf

# start samba
service smb start; chkconfig smb on

# join domain
echo "Enter your username (user@domain format):"
read USERNAME
net ads join -U ${USERNAME}

# start winbind & messagebus
service winbind start; chkconfig winbind on
service messagebus start; chkconfig messagebus on

# update passwd-auth
mv /etc/pam.d/password-auth-ac /etc/pam.d/password-auth-ac.orig
cp password-auth-ac.winbind /etc/pam.d/password-auth-ac

# update system-auth
mv /etc/pam.d/system-auth /etc/pam.d/system-auth.orig
cp system-auth.winbind /etc/pam.d/system-auth

# update oddjobd-mkhomedir.conf
mv /etc/oddjobd.conf.d/oddjobd-mkhomedir.conf /etc/oddjobd.conf.d/oddjobd-mkhomedir.conf.orig
cp oddjobd-mkhomedir.conf.winbind /etc/oddjobd.conf.d/oddjobd-mkhomedir.conf

# start oddjob
service oddjobd start; chkconfig oddjobd on

# edit sudoers
cp /etc/sudoers /etc/sudoers.orig
cp /etc/sudoers /tmp/sudoers
sed -i "/%wheel\s*ALL=(ALL)\s*ALL$/a\%Linux_Admins    ALL=(ALL)       ALL" /tmp/sudoers
visudo -c -f /tmp/sudoers
if [ $? -eq "0" ]; then
	cp /tmp/sudoers /etc/sudoers
fi
rm -f /tmp/sudoers

# lock out localadm
passwd -l localadm
