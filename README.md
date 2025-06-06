# Master Install Script – Web Hosting Otomatik Kurulum

Bu proje, Ubuntu tabanlı sunucular için **tam otomatik web hosting** kurulum scriptidir. Tek bir komutla aşağıdaki servis ve yazılımları kurar:

## 🚀 Kurulan Bileşenler

- Apache2 / Nginx (seçime göre)
- PHP (birden fazla sürüm destekli)
- MariaDB / MySQL
- phpMyAdmin
- Roundcube (Mail istemcisi)
- ElFinder (Dosya yöneticisi)
- FTP (vsftpd)
- Web tabanlı sistem izleme araçları (htop, netdata, vs.)
- SSL (Let's Encrypt ile)
- Fail2Ban ve güvenlik ayarları
- Tüm yapılandırmalar ve klasör yapısı

## ⚙️ Kurulum

1. Scripti indirin:
   ```bash
   git clone https://github.com/Sistem67/sistemx.git
   cd sistemx
   chmod +x master_install.sh
