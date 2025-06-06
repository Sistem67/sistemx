#!/bin/bash
# Otomatik Web Sunucusu Kurulum Scripti

apt update && apt upgrade -y
apt install -y apache2 php php-mysql mariadb-server phpmyadmin vsftpd postfix dovecot-imapd dovecot-pop3d certbot python3-certbot-apache unzip

# Roundcube Kurulumu (örnek)
cd /var/www/html
wget https://github.com/roundcube/roundcubemail/releases/download/1.6.6/roundcubemail-1.6.6-complete.tar.gz
tar -xvzf roundcubemail-1.6.6-complete.tar.gz
mv roundcubemail-1.6.6 roundcube

# ElFinder Kurulumu (örnek)
wget https://github.com/Studio-42/elFinder/archive/refs/heads/master.zip -O elfinder.zip
unzip elfinder.zip -d /var/www/html/

echo "Kurulum tamamlandı."
