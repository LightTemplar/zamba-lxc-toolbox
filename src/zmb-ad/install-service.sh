#!/bin/bash

# Authors:
# (C) 2021 Idea an concept by Christian Zengel <christian@sysops.de>
# (C) 2021 Script design and prototype by Markus Helmke <m.helmke@nettwarker.de>
# (C) 2021 Script rework and documentation by Thorsten Spille <thorsten@spille-edv.de>

source /root/functions.sh
source /root/zamba.conf
source /root/constants-service.conf

ZMB_DNS_BACKEND="SAMBA_INTERNAL"

for f in ${OPTIONAL_FEATURES[@]}; do
  if [[ "$f" == "wsdd" ]]; then
    ADDITIONAL_PACKAGES="wsdd $ADDITIONAL_PACKAGES"
    ADDITIONAL_SERVICES="wsdd $ADDITIONAL_SERVICES"
    if [[ LXC_TEMPLATE_VERSION == "debian-10-standard" ]] || [[ LXC_TEMPLATE_VERSION == "debian-11-standard" ]]; then
      apt-key adv --fetch-keys https://pkg.ltec.ch/public/conf/ltec-ag.gpg.key
      echo "deb https://pkg.ltec.ch/public/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/wsdd.list
    fi 
  elif [[ "$f" == "splitdns" ]]; then
    ADDITIONAL_PACKAGES="nginx-full $ADDITIONAL_PACKAGES"
    ADDITIONAL_SERVICES="nginx $ADDITIONAL_SERVICES"
  elif [[ "$f" == "bind9dlz" ]]; then
    ZMB_DNS_BACKEND="BIND9_DLZ"
    ADDITIONAL_PACKAGES="bind9 $ADDITIONAL_PACKAGES"
    ADDITIONAL_SERVICES="bind9 $ADDITIONAL_SERVICES"
  elif [[ "$f" == "webmin" ]]; then
    ADDITIONAL_PACKAGES="webmin $ADDITIONAL_PACKAGES"
    ADDITIONAL_SERVICES="webmin $ADDITIONAL_SERVICES"
    curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
    sh setup-repos.sh --force
  else
    echo "Unsupported optional feature $f"
  fi
done

echo "deb http://ftp.de.debian.org/debian $(lsb_release -cs)-backports main contrib" > /etc/apt/sources.list.d/$(lsb_release -cs)-backports.list

# update packages
apt update
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y -qq dist-upgrade
# install required packages
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt install -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" $LXC_TOOLSET $ADDITIONAL_PACKAGES rpl net-tools dnsutils
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt install -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" -t $(lsb_release -cs)-backports acl attr samba smbclient winbind libpam-winbind libnss-winbind krb5-user samba-dsdb-modules samba-vfs-modules lmdb-utils

if [[ "$ADDITIONAL_PACKAGES" == *"nginx-full"* ]]; then
  cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    server_name _;
    return 301 http://www.$LXC_DOMAIN\$request_uri;
}
EOF
fi

if  [[ "$ADDITIONAL_PACKAGES" == *"bind9"* ]]; then
  # configure bind dns service
  cat << EOF > /etc/default/bind9
#
# run resolvconf?
RESOLVCONF=no

# startup options for the server
OPTIONS="-4 -u bind"
EOF

  cat << EOF > /etc/bind/named.conf.local
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";
dlz "$LXC_DOMAIN" {
  database "dlopen /usr/lib/x86_64-linux-gnu/samba/bind9/dlz_bind9_11.so";
};
EOF

  cat << EOF > /etc/bind/named.conf.options
options {
  directory "/var/cache/bind";

  forwarders {
    $LXC_DNS;
  };

  allow-query {  any;};
  dnssec-validation no;

  auth-nxdomain no;    # conform to RFC1035
  listen-on-v6 { any; };
  listen-on { any; };

  tkey-gssapi-keytab "/var/lib/samba/bind-dns/dns.keytab";
  minimal-responses yes;
};
EOF

  mkdir -p /var/lib/samba/bind-dns/dns
fi



# stop + disable samba services and remove default config
systemctl disable --now smbd nmbd winbind systemd-resolved
rm -f /etc/samba/smb.conf
rm -f /etc/krb5.conf

# provision zamba domain
samba-tool domain provision --use-rfc2307 --realm=$ZMB_REALM --domain=$ZMB_DOMAIN --adminpass=$ZMB_ADMIN_PASS --server-role=dc --backend-store=mdb --dns-backend=$ZMB_DNS_BACKEND

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

add_line_under_section_to_conf "/etc/samba/smb.conf" "[global]" "ldap server require strong auth = No"

systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl restart samba-ad-dc $ADDITIONAL_SERVICES

exit 0