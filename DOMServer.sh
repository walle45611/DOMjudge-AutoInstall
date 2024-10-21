#!/bin/bash
#
# DOMjudge 安裝腳本
#
# 這個腳本會在 Ubuntu 上安裝並配置 DOMjudge 競賽系統，包括 MariaDB、Apache 和 PHP。
# 如果傳入 "ssl" 作為第一個參數，會同時安裝 SSL 並配置 HTTPS 支援。
#
# 用法：
#   ./install_domjudge.sh [ssl] <MariaDB root 密碼> [<SSL 證書> <SSL 私鑰>]
#
# 參數：
#   ssl                 （可選）啟用 SSL 安裝和配置
#   <MariaDB root 密碼>  （必須）為 MariaDB 的 root 使用者設定密碼
#   <SSL 證書>          （可選）當啟用 SSL 時，提供的 SSL 證書檔案路徑
#   <SSL 私鑰>          （可選）當啟用 SSL 時，提供的 SSL 私鑰檔案路徑
#
# 作者：
#   Ho,Kuo-Wei
#   Campion (Supervisor)
#
# 版本：
#   1.0.0 - 初版
#

# 預設為不使用 SSL
USE_SSL=false

# 分隔線顯示函數
function print_separator {
    echo -e "\e[33m========================================\e[0m"
}

# 如果第一個參數是 "ssl"，啟用 SSL 並移除該參數
if [[ "$1" == "ssl" ]]; then
    USE_SSL=true
    echo -e "\e[36mSSL installation and configuration enabled.\e[0m"
    shift  
fi

# 檢查 MariaDB root 密碼是否傳入
if [ -z "$1" ];then
    echo -e "\e[31mMariaDB root password not provided.\e[0m"
    echo -e "\e[33mUsage: $0 [ssl] <MariaDB root password> [<SSL certificate> <SSL key>]\e[0m"
    exit 1
fi
mariadb_root_password=$1

# 如果啟用了 SSL，檢查是否傳入了 SSL 證書和密鑰
if [ "$USE_SSL" = true ]; then
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo -e "\e[31mSSL certificate or key not provided.\e[0m"
        echo -e "\e[33mUsage: $0 ssl <MariaDB root password> <SSL certificate> <SSL key>\e[0m"
        exit 1
    fi
    ssl_certificate=$2
    ssl_key=$3
fi

echo -e "\e[36mEnsuring sudo privileges...\e[0m"
sudo -v

# 設定 sudo 保持權限
while true; do sudo -v; sleep 60; done &

# 開始安裝，並顯示分隔線
print_separator
echo -e "\e[36mStarting DOMjudge installation...\e[0m"
print_separator

# 更新系統並安裝必要的軟體包
echo -e "\e[36mInstalling required packages...\e[0m"
sudo apt-get update
sudo apt-get install -y libcgroup-dev build-essential acl zip unzip mariadb-server apache2 \
    php php-fpm php-gd php-cli php-intl php-mbstring php-mysql php-curl php-json php-xml \
    php-zip composer ntp ssh pkg-config make
print_separator

# 如果啟用了 SSL，安裝 openssl 並啟用 SSL 模組
if [ "$USE_SSL" = true ]; then
    echo -e "\e[36mInstalling and configuring SSL...\e[0m"
    sudo apt-get install -y openssl
    sudo a2enmod ssl

    # 修改 /opt/domjudge/domserver/etc/apache.conf 文件
    sudo sed -i "s|#Listen 443|Listen 443|" /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#<VirtualHost \*:443>|<VirtualHost *:443>|" \
        /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#SSLEngine on|SSLEngine on|" /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#SSLCertificateFile.*|SSLCertificateFile $ssl_certificate|" \
        /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#SSLCertificateKeyFile.*|SSLCertificateKeyFile $ssl_key|" \
        /opt/domjudge/domserver/etc/apache.conf

    # 啟用 SSL 配置
    sudo a2ensite default-ssl
    print_separator
fi

# 下載並解壓 DOMjudge
echo -e "\e[36mDownloading and extracting DOMjudge...\e[0m"
wget https://www.domjudge.org/releases/domjudge-8.3.1.tar.gz
tar -zxf domjudge-8.3.1.tar.gz
cd domjudge-8.3.1
print_separator

# 配置並安裝 domserver
echo -e "\e[36mConfiguring and installing DOMjudge domserver...\e[0m"
./configure --prefix=/opt/domjudge --with-domjudge-user=root
make domserver
sudo make install-domserver
print_separator

# MariaDB 安全性設置
echo -e "\e[36mSecuring MariaDB installation...\e[0m"
sudo mysql_secure_installation <<EOF

y
y
$mariadb_root_password
$mariadb_root_password
y
y
y
y
EOF
print_separator

# 配置 DOMjudge 資料庫
echo -e "\e[36mSetting up DOMjudge database...\e[0m"
sudo /opt/domjudge/domserver/bin/dj_setup_database genpass
sudo /opt/domjudge/domserver/bin/dj_setup_database -u root -p"$mariadb_root_password" install
print_separator

# 建立 Apache 和 PHP FPM 配置文件的符號連結
echo -e "\e[36mConfiguring Apache and PHP FPM...\e[0m"
sudo ln -s /opt/domjudge/domserver/etc/apache.conf /etc/apache2/conf-available/domjudge.conf
sudo ln -s /opt/domjudge/domserver/etc/domjudge-fpm.conf /etc/php/8.3/fpm/pool.d/domjudge.conf

# 啟用 Apache 模組和配置
sudo a2enmod proxy_fcgi setenvif rewrite
sudo a2enconf php8.3-fpm domjudge
sudo service apache2 reload
sudo service php8.3-fpm reload

# 如果啟用了 SSL，重新加載 Apache 配置
if [ "$USE_SSL" = true ]; then
    sudo service apache2 reload
fi
print_separator

# 安裝完成訊息，顯示紅色並用分隔線分隔
echo -e "\e[31mDOMjudge installation completed!\e[0m"
print_separator

# 顯示初始管理員密碼，並加上顏色，同時顯示在同一行
echo -e "\e[32mInitial admin password is:\e[0m $(sudo cat /opt/domjudge/domserver/etc/initial_admin_password.secret)"

# 顯示 Rest API 密鑰，只顯示 "default" 一行，並加上顏色，在同一行輸出
echo -e "\e[34mRest API secret is:\e[0m $(sudo grep '^default' /opt/domjudge/domserver/etc/restapi.secret)"

# 結束保持 sudo 的循環
kill %%
