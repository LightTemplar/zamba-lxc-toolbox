#!/bin/bash

# Authors:
# (C) 2021 Idea an concept by Christian Zengel <christian@sysops.de>
# (C) 2021 Script design and prototype by Markus Helmke <m.helmke@nettwarker.de>
# (C) 2021 Script rework and documentation by Thorsten Spille <thorsten@spille-edv.de>

source /root/functions.sh
source /root/zamba.conf
source /root/constants-service.conf

webroot=/var/www/html

LXC_RANDOMPWD=20

apt update

DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt install -y -qq unzip sudo nginx-full php php-cli php-fpm php-mysql php-xml php-mbstring php-gd php-ldap

mkdir /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout /etc/nginx/ssl/phpldapadmin.key -out /etc/nginx/ssl/phpldapadmin.crt -subj "/CN=$LXC_HOSTNAME.$LXC_DOMAIN" -addext "subjectAltName=DNS:$LXC_HOSTNAME.$LXC_DOMAIN"

cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80;
    server_name _;

    return 301 https://$LXC_HOSTNAME.$LXC_DOMAIN;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $LXC_HOSTNAME.$LXC_DOMAIN;

    root $webroot;

    index index.php;

    ssl on;
    ssl_certificate /etc/nginx/ssl/phpldapadmin.crt;
    ssl_certificate_key /etc/nginx/ssl/phpldapadmin.key;

    location ~ .php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }
}

EOF



cd $webroot
https://github.com/leenooks/phpLDAPadmin/archive/refs/tags/1.2.6.7.zip
wget https://github.com/leenooks/phpLDAPadmin/archive/refs/tags/1.2.6.7.zip -O $webroot/phpldapadmin.zip
unzip phpldapadmin.zip
rm phpldapadmin.zip
chown -R www-data:www-data $webroot

systemctl enable --now php7.4-fpm
systemctl restart php7.4-fpm nginx

LXC_IP=$(ip address show dev eth0 | grep "inet " | cut -d ' ' -f6)

echo -e "Your phpldapadmin installation is now complete. Please continue with setup in your Browser:\nURL:\t\thttp://$(echo $LXC_IP | cut -d'/' -f1)"
