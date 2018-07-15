#!/usr/bin/env bash

# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive
# Jasmine Panel installer
JP_VERSION="0.0.1"

echo "Jasmine Panel client $JP_VERSION";

# Are we running as root?
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root. Please try like this:"
	echo
	echo "sudo $0"
	echo
	exit
fi

# Check if we have apt-get
command -v apt-get >/dev/null 2>&1 || { echo "I require apt-get but it's not installed.  Aborting." >&2; exit 1; }

echo "Updating repositories"

apt-get update -y

apt-get install lsb-release -y

# Check that we are running on Ubuntu 18.04 LTS (or 18.04.xx).
if [ "`lsb_release -d | sed 's/.*:\s*//' | sed 's/18\.04\.[0-9]/18.04/' `" != "Ubuntu 18.04 LTS" ]; then
	echo "Jasmine Panel only supports being installed on Ubuntu 18.04, sorry. You are running:"
	echo
	lsb_release -d | sed 's/.*:\s*//'
	echo
	echo "We can't write scripts that run on every possible setup, sorry."
	exit
fi

echo "Upgrading packages"

apt-get upgrade -y

echo "Installing necessary packages"

apt-get install wget whois sudo sed git unzip curl -y

# Remove apache2
apt-get purge apache2 -y
apt-get autoremove -y

# Install nginx
apt-get install nginx nginx-extras -y

# Install mariadb
apt-get install software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mirror.poliwangi.ac.id/mariadb/repo/10.3/ubuntu bionic main'
apt-get update -y

_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
debconf-set-selections <<< "mariadb-server-10.3 mysql-server/root_password password $_PASSWORD"
debconf-set-selections <<< "mariadb-server-10.3 mysql-server/root_password_again password $_PASSWORD"

echo "MySQL root password is $_PASSWORD the password is in ~/.mysql_pass"
echo $_PASSWORD > ~/.mysql_pass

apt-get install mariadb-server-10.3 -y

# Clearing
unset _PASSWORD
unset DEBIAN_FRONTEND

# Install PHP
apt-get install -y php7.2
apt-get install -y php7.2-cli
apt-get install -y php7.2-fpm
apt-get install -y php7.2-bz2
apt-get install -y php7.2-common
apt-get install -y php7.2-curl
apt-get install -y php7.2-gd
apt-get install -y php7.2-imap
apt-get install -y php7.2-json
apt-get install -y php7.2-mbstring
apt-get install -y php7.2-mysql
apt-get install -y php7.2-soap
apt-get install -y php7.2-sqlite3
apt-get install -y php7.2-sybase
apt-get install -y php7.2-xml
apt-get install -y php7.2-zip
apt-get install -y php-mongodb

sed -i -- 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/7.2/fpm/php.ini

# Remove apache2
apt-get purge apache2 -y
apt-get autoremove -y

# Install composer
EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('SHA384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    >&2 echo 'ERROR: Invalid installer signature'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
RESULT=$?
rm composer-setup.php

if [ $RESULT = "1" ]
then
    exit $RESULT
fi

mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer
chown -R $(whoami):$(whoami) ~/.composer

echo 'export PATH="$PATH:$HOME/.composer/vendor/bin"' >> ~/.bashrc
source ~/.bashrc

# Install node js
apt-get install -y nodejs
apt-get install -y npm

# Install yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update -y && sudo apt-get install yarn -y

# Install certbot
apt-get install certbot -y

# Setup dhparam
sudo apt-get install openssl -y
mkdir -p /etc/jasmine/ssl
openssl dhparam -out /etc/jasmine/ssl/dhparam.pem 4096


# Setup skel
mkdir -p /etc/jasmine/skel/apps
mkdir -p /etc/jasmine/skel/tmp
mkdir -p /etc/jasmine/skel/ssl
mkdir -p /etc/jasmine/skel/log


# Setup Jasmine Panel

# Create Jasmine Panel dirs
mkdir -p /var/jasmine/accounts

# Create jasmine user
useradd -mk /etc/jasmine/skel/ -b /var/jasmine jasmine

composer create-project laravel/laravel /var/jasmine/jasmine/apps/jasmine

chown -R jasmine:jasmine /var/jasmine/jasmine/

# setup php-fpm pool
cp jasmine.conf /etc/php/7.2/fpm/pool.d/

service php7.2-fpm reload

cp jasmine.nginx /etc/nginx/sites-available/jasmine

ln -s /etc/nginx/sites-available/jasmine /etc/nginx/sites-enabled/

service nginx reload

#useradd -mk /etc/jasmine/skel/ -b /var/jasmine/accounts/ username

