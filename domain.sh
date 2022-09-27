#!/bin/bash

clear

ip=$(wget -qO- http://ipecho.net/plain | xargs echo)

echo "Penting!!! Pastikan domain sudah mengarah Ke IP VPS"
echo "----------------------"
read -p "Domain(1) atau Subdomain(2) [1/2] = " tipedomain
read -p "Nama Domain = " domain
read -p "Versi PHP [7.4/8.0/8.1] = " vphp
read -p "Masukkan Email Untuk Notifikasi SSL = " emailssl
read -p "Nama Website = " wptitle
read -p "Username Wordpress = " wpadmin
read -p "Email Wordpress = " wpemail
echo "----------------------"

echo "Memulai instalasi dan konfigurasi ..."
echo "----------------------"
echo "Set TimeZone Asia/Jakarta"
timedatectl set-timezone Asia/Jakarta
echo

echo "Membuat document root"
mkdir /var/www/${domain}
echo "<?php phpinfo(); ?>" > /var/www/${domain}/index.php
echo

echo "Membuat konfigurasi server block ${domain}"
if [ $tipedomain == 1  ]
then
cat > /etc/nginx/conf.d/${domain}.conf << EOF
server {
    listen 80;
    server_name ${domain} www.${domain};
    root /var/www/${domain};
    index index.php index.html index.htm;

    location / {
      try_files \$uri \$uri/ /index.php?\$args;
      client_max_body_size 100M;
    }

    location ~ \.php\$ {
      try_files \$fastcgi_script_name =404;
      include fastcgi_params;
      fastcgi_pass    unix:/run/php/php$vphp-fpm.sock;
      fastcgi_index   index.php;
      fastcgi_param DOCUMENT_ROOT   \$realpath_root;
      fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
      client_max_body_size 100M;
    }

    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
}
EOF
else
cat > /etc/nginx/conf.d/${domain}.conf << EOF
server {
    listen 80;
    server_name ${domain};
    root /var/www/${domain};
    index index.php index.html index.htm;

    location / {
      try_files \$uri \$uri/ /index.php?\$args;
      client_max_body_size 100M;
    }

    location ~ \.php\$ {
      try_files \$fastcgi_script_name =404;
      include fastcgi_params;
      fastcgi_pass    unix:/run/php/php$vphp-fpm.sock;
      fastcgi_index   index.php;
      fastcgi_param DOCUMENT_ROOT   \$realpath_root;
      fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
      client_max_body_size 100M; 
    }

    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
}
EOF
fi
echo

echo "Restart Nginx"
systemctl enable nginx
systemctl restart nginx
echo

echo "Request SSL untuk ${domain}"
if [ $tipedomain == 1  ]
then
certbot --non-interactive -m ${emailssl} --agree-tos --no-eff-email --nginx -d ${domain} -d www.${domain} --redirect
else
certbot --non-interactive -m ${emailssl} --agree-tos --no-eff-email --nginx -d ${domain} --redirect
fi
echo

echo "Membuat User & Database"
dbname="db_${domain//./}"
dbuser="usr_${domain//./}"
dbpass=$(pwgen 20 1)
mysql << EOF
CREATE DATABASE ${dbname};
CREATE USER '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}';
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';
FLUSH PRIVILEGES;
EOF
echo

echo "Install WordPress"
wppass=$(pwgen 20 1)
cd /var/www/${domain}
rm -f index.php
wp core download --allow-root
wp config create --dbname=${dbname} --dbuser=${dbuser} --dbpass=${dbpass} --dbhost=localhost --allow-root
wp core install --url=https://${domain} --title="${wptitle}" --admin_user="${wpadmin}" --admin_password=${wppass} --admin_email="${wpemail}" --allow-root
chown -R www-data:www-data /var/www/${domain}
chmod -R 755 /var/www/${domain}
cd
echo

cat > /root/${domain}-conf.txt << EOF
IP Server = ${ip}
Domain = ${domain}
Email Let's Encrypt = ${emailssl}

Document Root = /var/www/${domain}
Server Block Conf = /etc/nginx/conf.d/${domain}.conf

Nama Database = ${dbname}
User Database = ${dbuser}
Password Database = ${dbpass}

WP Admin User = ${wpadmin}
WP Admin Email = ${wpemail}
WP Admin Password = ${wppass}
EOF

echo
echo "Instalasi WordPress dengan LEMP sudah selesai"
echo "Informasi konfigurasi tersimpan di /root/${domain}-conf.txt"
echo
cat /root/${domain}-conf.txt
echo

echo "Restart Nginx"
systemctl enable nginx
systemctl restart nginx
