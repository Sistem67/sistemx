#!/bin/bash
# Tam Otomatik Web Hosting Platformu Kurulum Scripti
# Ubuntu 22.04 / 20.04 için hazırlandı
# Root veya sudo ile çalıştırılmalı!

set -e

# --- DEĞİŞKENLER (Burayı kendi bilgilerinizle değiştirin) ---
DOMAIN="example.com"
MAIL_DOMAIN="mail.example.com"
DB_ROOT_PASS="GucLuRootSifre123!"
FTP_USER="ftpuser"
FTP_PASS="ftpSifre123!"
FILEBROWSER_USER="admin"
FILEBROWSER_PASS="adminSifre123!"
ROUNDCUBE_DB_PASS="roundcubeDbSifre123!"
# ----------------------------------------------------------

echo "===== Sistem Güncelleniyor... ====="
apt update -y && apt upgrade -y

echo "===== Gerekli Temel Paketler Kuruluyor... ====="
apt install -y software-properties-common curl wget lsb-release apt-transport-https ca-certificates gnupg2 unzip git cron net-tools ufw fail2ban

echo "===== Ondrej PHP PPA Ekleme ve Güncelleme... ====="
add-apt-repository ppa:ondrej/php -y
apt update -y

echo "===== PHP 7.4, 8.1 ve 8.2 Kuruluyor... ====="
apt install -y \
php7.4 php7.4-fpm php7.4-mysql php7.4-curl php7.4-xml php7.4-mbstring php7.4-zip php7.4-gd php7.4-bcmath php7.4-cli \
php8.1 php8.1-fpm php8.1-mysql php8.1-curl php8.1-xml php8.1-mbstring php8.1-zip php8.1-gd php8.1-bcmath php8.1-cli \
php8.2 php8.2-fpm php8.2-mysql php8.2-curl php8.2-xml php8.2-mbstring php8.2-zip php8.2-gd php8.2-bcmath php8.2-cli

echo "===== Varsayılan PHP Sürümü 8.1 Olarak Ayarlanıyor... ====="
update-alternatives --set php /usr/bin/php8.1
update-alternatives --set phar /usr/bin/phar8.1
update-alternatives --set phar.phar /usr/bin/phar.phar8.1

echo "===== MariaDB Kuruluyor... ====="
apt install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

echo "===== MariaDB Root Parolası Ayarlanıyor... ====="
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;"

echo "===== Nginx Kuruluyor... ====="
apt install -y nginx
systemctl enable nginx
systemctl start nginx

echo "===== phpMyAdmin Kuruluyor... ====="
PHPMYADMIN_VER="5.3.1"
wget https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip -O /tmp/phpmyadmin.zip
unzip /tmp/phpmyadmin.zip -d /usr/share/
mv /usr/share/phpMyAdmin-${PHPMYADMIN_VER}-all-languages /usr/share/phpmyadmin
rm /tmp/phpmyadmin.zip
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin

echo "===== phpMyAdmin İçin Nginx Ayarları Yapılıyor... ====="
cat > /etc/nginx/conf.d/phpmyadmin.conf <<EOF
server {
    listen 8080;
    server_name _;
    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)\$ {
        expires max;
        log_not_found off;
    }
}
EOF
systemctl reload nginx

echo "===== FTP Server (vsftpd) Kuruluyor... ====="
apt install -y vsftpd
cat > /etc/vsftpd.conf <<EOF
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_min_port=40000
pasv_max_port=50000
pasv_address=127.0.0.1
secure_chroot_dir=/var/run/vsftpd/empty
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
EOF
systemctl enable vsftpd
systemctl restart vsftpd

echo "===== Postfix, Dovecot ve Spamassassin Kuruluyor... ====="
apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql spamassassin clamav clamav-daemon opendkim opendkim-tools

echo "===== Postfix Temel Yapılandırması Yapılıyor... ====="
postconf -e "myhostname = ${MAIL_DOMAIN}"
postconf -e "mydomain = ${DOMAIN}"
postconf -e "myorigin = /etc/mailname"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "relay_domains ="
postconf -e "home_mailbox = Maildir/"
postconf -e "smtpd_banner = \$myhostname ESMTP"
postconf -e "smtpd_use_tls = no"
postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination"

echo "===== Dovecot Temel Yapılandırması Yapılıyor... ====="
cat > /etc/dovecot/dovecot.conf <<EOF
protocols = imap pop3 lmtp
mail_location = maildir:~/Maildir
auth_mechanisms = plain login
!include conf.d/*.conf
EOF

cat > /etc/dovecot/conf.d/10-master.conf <<EOF
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = no
  }
}

service pop3-login {
  inet_listener pop3 {
    port = 110
  }
  inet_listener pop3s {
    port = 995
    ssl = no
  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

service auth {
  unix_listener auth-userdb {
    mode = 0600
    user = vmail
    group = vmail
  }

  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}

service auth-worker {
  user = dovecot
}

EOF

cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF
ssl = no
EOF

systemctl enable postfix dovecot spamassassin clamav-daemon opendkim
systemctl restart postfix dovecot spamassassin clamav-daemon opendkim

echo "===== Roundcube Webmail Kuruluyor... ====="
ROUNDCUBE_VER="1.6.0"
wget https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VER}/roundcubemail-${ROUNDCUBE_VER}.tar.gz -O /tmp/roundcube.tar.gz
tar -xzf /tmp/roundcube.tar.gz -C /var/www/
mv /var/www/roundcubemail-${ROUNDCUBE_VER} /var/www/roundcube
chown -R www-data:www-data /var/www/roundcube

echo "===== Roundcube İçin Nginx Ayarları Yapılıyor... ====="
cat > /etc/nginx/sites-available/roundcube.conf <<EOF
server {
    listen 8090;
    server_name _;
    root /var/www/roundcube;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }
}
EOF
ln -sf /etc/nginx/sites-available/roundcube.conf /etc/nginx/sites-enabled/
systemctl reload nginx

echo "===== Dosya Yöneticisi (FileBrowser) Kuruluyor... ====="
curl -fsSL https://filebrowser.org/install.sh | bash
filebrowser config init
filebrowser users add ${FILEBROWSER_USER} ${FILEBROWSER_PASS} --perm.admin
systemctl enable filebrowser
systemctl start filebrowser

echo "===== Sistem İzleme Aracı (Netdata) Kuruluyor... ====="
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --disable-telemetry

echo "===== Fail2ban ve UFW Firewall Ayarlanıyor... ====="
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw allow 21
ufw allow 25
ufw allow 110
ufw allow 143
ufw allow 587
ufw allow 993
ufw allow 995
ufw allow 3306
ufw allow 8080
ufw allow 8090
ufw enable

systemctl enable fail2ban
systemctl start fail2ban

echo "===== Let’s Encrypt ve Certbot Kuruluyor (SSL alımı için hazır)... ====="
apt install -y certbot python3-certbot-nginx

echo "===== Kurulum Tamamlandı! ====="
echo "MariaDB root şifresi: ${DB_ROOT_PASS}"
echo "FTP kullanıcı: ${FTP_USER} / ${FTP_PASS}"
echo "FileBrowser kullanıcı: ${FILEBROWSER_USER} / ${FILEBROWSER_PASS}"
echo "Roundcube DB şifresi: ${ROUNDCUBE_DB_PASS}"
echo ""
echo "Artık sisteminiz kullanılabilir."
echo "Certbot ile SSL almak için aşağıdaki komutu çalıştırabilirsiniz:"
echo "certbot --nginx -d ${DOMAIN} -d ${MAIL_DOMAIN}"
