#!/bin/bash

USE_SSL=false

if [[ "$1" == "ssl" ]]; then
    USE_SSL=true
    echo "SSL installation and configuration enabled."
    shift  
fi

if [ -z "$1" ];then
    echo "MariaDB root password not provided."
    echo "Usage: $0 [ssl] <MariaDB root password> [<SSL certificate> <SSL key>]"
    exit 1
fi
mariadb_root_password=$1

if [ "$USE_SSL" = true ]; then
    if [ -z "$2" ] || [ -z "$3" ]; then
        echo "SSL certificate or key not provided."
        echo "Usage: $0 ssl <MariaDB root password> <SSL certificate> <SSL key>"
        exit 1
    fi
    ssl_certificate=$2
    ssl_key=$3
fi

echo "Ensuring sudo privileges..."
sudo -v

while true; do sudo -v; sleep 60; done &

sudo apt-get update
sudo apt-get install -y libcgroup-dev build-essential acl zip unzip mariadb-server apache2 \
     php php-fpm php-gd php-cli php-intl php-mbstring php-mysql \
     php-curl php-json php-xml php-zip composer ntp ssh pkg-config make

if [ "$USE_SSL" = true ]; then
    sudo apt-get install -y openssl
    sudo a2enmod ssl
    sudo sed -i "s|#Listen 443|Listen 443|" /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#<VirtualHost \*:443>|<VirtualHost *:443>|" /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#SSLEngine on|SSLEngine on|" /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#SSLCertificateFile.*|SSLCertificateFile $ssl_certificate|" /opt/domjudge/domserver/etc/apache.conf
    sudo sed -i "s|#SSLCertificateKeyFile.*|SSLCertificateKeyFile $ssl_key|" /opt/domjudge/domserver/etc/apache.conf
    sudo a2ensite default-ssl
fi

wget https://www.domjudge.org/releases/domjudge-8.3.1.tar.gz
tar -zxf domjudge-8.3.1.tar.gz
cd domjudge-8.3.1

./configure --prefix=/opt/domjudge --with-domjudge-user=root
make domserver
sudo make install-domserver

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

sudo /opt/domjudge/domserver/bin/dj_setup_database genpass
sudo /opt/domjudge/domserver/bin/dj_setup_database -u root -p"$mariadb_root_password" install

sudo ln -s /opt/domjudge/domserver/etc/apache.conf /etc/apache2/conf-available/domjudge.conf
sudo ln -s /opt/domjudge/domserver/etc/domjudge-fpm.conf /etc/php/8.3/fpm/pool.d/domjudge.conf

sudo a2enmod proxy_fcgi setenvif rewrite
sudo a2enconf php8.3-fpm domjudge
sudo service apache2 reload
sudo service php8.3-fpm reload

if [ "$USE_SSL" = true ]; then
    sudo service apache2 reload
fi

echo "DOMjudge installation completed!"

echo "Initial admin password is:"
sudo cat /opt/domjudge/domserver/etc/initial_admin_password.secret

echo "Rest API secret is:"
sudo cat /opt/domjudge/domserver/etc/restapi.secret

kill %%
