#!/bin/sh

set -e

# sudo access will be requested if the script was not run with sudo or under root user
sudo -k

# This causes the following error: ubuntu_18.04.sh: 24: [: =: unexpected operator
# Need to fix it, but the things work fine
if ! [ $(sudo id -u) = 0 ]; then
    echo "\033[31;1m"
    echo "Root password was not entered correctly!"
    exit 1;
fi

sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# Remove all custom app source lists. You must add them back manually if needed.
    printf "\n>>> Removing all custom repository sources! >>>\n"
sudo rm /etc/apt/sources.list.d/* || true

    printf "\n>>> Creating files and folders... >>>\n"
# "db" for dumps and "certs" for SSL certificates
mkdir -p ~/misc/apps ~/misc/certs ~/misc/db

# Install cUrl
    printf "\n>>> cUrl is going to be installed >>>\n"
sudo apt install curl -y

    printf "\n>>> Adding repositories and updating software list >>>\n"
# various PHP versions
sudo add-apt-repository ppa:ondrej/php -y
# Shutter screenshot tool
sudo add-apt-repository ppa:shutter/ppa -y
# Node
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
# Guake terminal
sudo add-apt-repository ppa:linuxuprising/guake -y

    printf "\n>>> Running Ubuntu upgrade >>>\n"
sudo apt update
sudo apt upgrade -y
# ifconfig since 18.04
sudo apt install net-tools -y

# Install Tilda
    printf "\n>>> Guake terminal is going to be installed >>>\n"
sudo apt install guake -y

# Install Sublime Text editor
    printf "\n>>> Sublime Text is going to be installed >>>\n"
sudo snap install sublime-text --classic

# Install Midnight Commander
    printf "\n>>> Midnight Commander is going to be installed >>>\n"
sudo apt install mc -y

# Install Vim text editor
    printf "\n>>> Vim is going to be installed >>>\n"
sudo apt install vim -y

# Install htop utility
    printf "\n>>> htop is going to be installed >>>\n"
sudo apt install htop -y

# Install Git and Git Gui
    printf "\n>>> Git and Git Gui are going to be installed >>>\n"
sudo apt install git git-gui -y

# Install Docker and docker-compose
    printf "\n>>> Docker and docker-compose are going to be installed >>>\n"
# 2020-04.29: Docker 19.03.8 and docker-compose 1.25.0. Using official repo to keep this updateable
sudo apt purge docker* -y
sudo apt install docker.io docker-compose -y
sudo systemctl enable docker
# This is to execute Docker command without sudo. Will work after logout/login because permissions should be refreshed
sudo usermod -aG docker ${USER}

# Install MySQL client and MySQL/MariaDB servers from Docker images
    printf "\n>>> Traefik, MySQL MySQL/MariaDB and phpMyAdmin are going to be installed via docker-compose - https://github.com/DefaultValue/docker_infrastructure >>>\n"
# Install MySQL for easy access to MySQL inside the container if needed
sudo apt install mysql-client -y

export PROJECTS_ROOT_DIR=${HOME}/misc/apps/
export SSL_CERTIFICATES_DIR=${HOME}/misc/certs/
export EXECUTION_ENVIRONMENT=development

if ! test -d "${PROJECTS_ROOT_DIR}docker_infrastructure"; then
    cd ${PROJECTS_ROOT_DIR}
    git clone https://github.com/DefaultValue/docker_infrastructure.git
fi

cd ${PROJECTS_ROOT_DIR}docker_infrastructure/
git config core.fileMode false
git reset --hard HEAD
cd ./local_infrastructure/

if ! test -f ./configuration/certificates.toml; then
    cp configuration/certificates.toml.dist configuration/certificates.toml
fi

# Run with sudo before logout, but use current user's value for SSL_CERTIFICATES_DIR
sudo su -c "export SSL_CERTIFICATES_DIR=$SSL_CERTIFICATES_DIR ; docker-compose down"

cd ${PROJECTS_ROOT_DIR}docker_infrastructure/
git pull origin master

# Refresh all images if outdated, pull if not yet present
sudo su -c 'docker pull traefik:v2.2'
sudo su -c 'docker pull mysql:5.6'
sudo su -c 'docker pull mysql:5.7'
sudo su -c 'docker pull mysql:8.0'
sudo su -c 'docker pull bitnami/mariadb:10.1'
sudo su -c 'docker pull bitnami/mariadb:10.2'
sudo su -c 'docker pull bitnami/mariadb:10.3'
sudo su -c 'docker pull bitnami/mariadb:10.4'
sudo su -c 'docker pull phpmyadmin/phpmyadmin'
sudo su -c 'docker pull mailhog/mailhog:v1.0.1'

# Run with sudo before logout, but use current user's value for SSL_CERTIFICATES_DIR
cd ${PROJECTS_ROOT_DIR}docker_infrastructure/local_infrastructure/
sudo su -c "export SSL_CERTIFICATES_DIR=$SSL_CERTIFICATES_DIR ; docker-compose up -d --force-recreate"

echo "
127.0.0.1 phpmyadmin.docker.local
127.0.0.1 traefik.docker.local
127.0.0.1 mailhog.docker.local" | sudo tee -a /etc/hosts

# Install PHP common packages
    printf "\n>>> Install common PHP packages (php-pear php-imagick php-memcached php-ssh2 php-xdebug) and composer >>>\n"
# Install PHP 8.1 and modules, enable modules. Anyway try installing all packages in case the dependencies change
    printf "\n>>> PHP 8.1 and common modules are going to be installed >>>\n"
sudo apt purge php* -y
sudo rm -rf /etc/php/ || true
sudo apt install \
    php8.1-bz2 \
    php8.1-cli \
    php8.1-common \
    php8.1-curl \
    php8.1-intl \
    php8.1-mbstring \
    php8.1-mysql \
    php8.1-opcache \
    php8.1-readline \
    php8.1-ssh2 \
    php8.1-xml \
    php8.1-xdebug \
    php8.1-zip \
    --no-install-recommends -y
sudo apt remove composer -y
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/bin/composer

    printf "\n>>> Creating ini files for the development environment >>>\n"
IniDirs=/etc/php/*/*/conf.d/
for IniDir in ${IniDirs};
do
    printf "Creating ${IniDir}999-custom-config.ini\n"
sudo rm ${IniDir}999-custom-config.ini || true
echo "error_reporting=E_ALL & ~E_DEPRECATED
display_errors=On
display_startup_errors=On
ignore_repeated_errors=On
cgi.fix_pathinfo=1
max_execution_time=3600
session.gc_maxlifetime=84600

opcache.enable=1
opcache.validate_timestamps=1
opcache.revalidate_freq=1
opcache.max_wasted_percentage=10
opcache.memory_consumption=256
opcache.max_accelerated_files=20000

xdebug.mode=debug
xdebug.remote_handler=dbgp
xdebug.discover_client_host=0
xdebug.show_error_trace=1
xdebug.start_with_request=yes
xdebug.max_nesting_level=256
xdebug.log_level=0
" | sudo tee ${IniDir}999-custom-config.ini > /dev/null
done

IniDirs=/etc/php/*/cli/conf.d/
for IniDir in ${IniDirs};
do
echo "memory_limit=2G
" | sudo tee -a ${IniDir}999-custom-config.ini >> /dev/null
done

    printf "\n>>> Enabling php modules: xdebug >>>\n"
sudo phpenmod xdebug

    printf "\n>>> Creating aliases and enabling color output >>>\n"
if test -f ~/.bash_aliases; then
    mv ~/.bash_aliases ~/bash_aliases_$(date +%Y_%m_%d_%H.%M)
fi

echo "
force_color_prompt=yes
shopt -s autocd
set completion-ignore-case On

# PHP xDebug 3.x config
export XDEBUG_SESSION=PHPSTORM

export PROJECTS_ROOT_DIR=\${HOME}/misc/apps/
export SSL_CERTIFICATES_DIR=\${HOME}/misc/certs/
export EXECUTION_ENVIRONMENT=development

getContainerName()
{
    php -r '\$output = shell_exec(\"docker-compose ps -q | xargs docker inspect\");
        foreach (json_decode(\$output) as \$containerInfo) {
            if (\$containerInfo->Path === \"docker-php-entrypoint\") {
                echo ltrim(\$containerInfo->Name, \"/\");
                exit();
            }
        }'
}

alias MY56='mysql -uroot -proot -h127.0.0.1 --port=3356 --show-warnings'
alias MY57='mysql -uroot -proot -h127.0.0.1 --port=3357 --show-warnings'
alias MY80='mysql -uroot -proot -h127.0.0.1 --port=3380 --show-warnings'
alias MY101='mysql -uroot -proot -h127.0.0.1 --port=33101 --show-warnings'
alias MY102='mysql -uroot -proot -h127.0.0.1 --port=33102 --show-warnings'
alias MY103='mysql -uroot -proot -h127.0.0.1 --port=33103 --show-warnings'
alias MY104='mysql -uroot -proot -h127.0.0.1 --port=33104 --show-warnings'

alias BASH='docker exec -it \$(getContainerName) bash'
alias BASHR='docker exec -u root -it \$(getContainerName) bash'
alias CC='docker exec -it \$(getContainerName) php bin/magento cache:clean'
alias SU='docker exec -it \$(getContainerName) php bin/magento setup:upgrade'
alias DI='docker exec -it \$(getContainerName) php bin/magento setup:di:compile'
alias IR='docker exec -it \$(getContainerName) php bin/magento indexer:reindex'
alias URN='docker exec -it \$(getContainerName) php bin/magento dev:urn-catalog:generate .idea/misc.xml; sed -i \"s/\/var\/www\/html/\\\$PROJECT_DIR\\\$/g\" .idea/misc.xml'

alias DOCKERIZE='php \${PROJECTS_ROOT_DIR}dockerizer_for_php/bin/console dockerize '
alias SETUP='php \${PROJECTS_ROOT_DIR}dockerizer_for_php/bin/console magento:setup '
alias ENVADD='php \${PROJECTS_ROOT_DIR}dockerizer_for_php/bin/console env:add '
alias CR='rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* var/di/* var/generation/* generated/code/* generated/metadata/* pub/static/frontend/* pub/static/adminhtml/* pub/static/deployed_version.txt'
alias MCS='\${PROJECTS_ROOT_DIR}magento-coding-standard/vendor/bin/phpcs --standard=Magento2 --severity=1 '
alias MND='\${PROJECTS_ROOT_DIR}php-quality-tools/vendor/bin/phpmnd '" > ~/.bash_aliases

# Install a tool for PHP projects dockerization and fast Magento installation
    printf "\n>>> Installing Dockerizer for PHP tool - https://github.com/DefaultValue/dockerizer_for_php >>>\n"
if ! test -d "${PROJECTS_ROOT_DIR}dockerizer_for_php"; then
    cd ${PROJECTS_ROOT_DIR}
    git clone https://github.com/DefaultValue/dockerizer_for_php.git
fi

cd ${PROJECTS_ROOT_DIR}dockerizer_for_php/
git config core.fileMode false
git reset --hard HEAD
git checkout master
git pull origin master
composer install

# Install Node Package Manager and Grunt tasker
# NodeJS is needed to run JSCS and ESLint for M2 in PHPStorm
    printf "\n>>> NPM and Grunt are going to be installed >>>\n"
sudo apt purge nodejs -y
sudo apt install nodejs -y

# Install VirtualBox from the repository.
# 2020-04-29: Current version is 6.1 (latest one)
    printf "\n>>> VirtualBox are going to be installed >>>\n"
sudo apt install virtualbox -y
    printf "\n>>> Adding VirtualBox user to your group, so it can access USB devices >>>\n"
sudo usermod -aG vboxusers ${USER}

# Install Google Chrome
    printf "\n>>> Google Chrome is going to be installed >>>\n"
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb

# Install mkcert - https://github.com/FiloSottile/mkcert/releases
    printf "\n>>> Homebrew and mkcert are going to be installed -https://github.com/FiloSottile/mkcert >>>\n"
sudo apt install libnss3-tools -y
wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-amd64
chmod +x mkcert-v1.4.3-linux-amd64
sudo mv mkcert-v1.4.3-linux-amd64 /usr/bin/mkcert
mkcert -install

# Install Shutter
    printf "\n>>> Shutter is going to be installed >>>\n"
sudo apt purge shutter -y
sudo apt install shutter -y

# Install KeePassXC - free encrypted password storage
    printf "\n>>> KeePassXC is going to be installed >>>\n"
sudo snap install keepassxc

# Install Dropbox
    printf "\n>>> Dropbox is going to be installed >>>\n"
sudo apt install nautilus-dropbox -y

# Install Diodon clipboard manager because clipit is broken for now :(
    printf "\n>>> Diodon clipboard manager is going to be installed >>>\n"
sudo apt install diodon -y

# Install Slack messenger
    printf "\n>>> Slack messenger is going to be installed >>>\n"
sudo snap install slack

# Install PHPStorm EAP (Early Access Program) that is free. Use licensed version if you have it!
    printf "\n>>> PHPStorm EAP is going to be installed >>>\n"
sudo snap install phpstorm --classic
    printf "\n>>> Setting filesystem parameters for PHPStorm IDE: fs.inotify.max_user_watches = 524288 >>>\n"
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf > /dev/null

# Install Gnome Tweak Tool for tuning Ubuntu
    printf "\n>>> Gnome Tweak Tool is going to be installed >>>\n"
sudo apt install gnome-tweak-tool -y

    printf "\n>>> Magento 2 coding standards - https://github.com/magento/magento-coding-standard >>>\n"
if ! test -d "${PROJECTS_ROOT_DIR}magento-coding-standard"; then
    cd ${PROJECTS_ROOT_DIR}
    git clone https://github.com/magento/magento-coding-standard.git
fi
cd ${PROJECTS_ROOT_DIR}magento-coding-standard/
git config core.fileMode false
git reset --hard HEAD
git checkout master
git pull origin master
composer install
npm install

    printf "\n>>> Install PHPMD (Mess Detector), PHPStan (Static Analysis Tool) and PHPMND (Magic Number Detector) >>>\n"
if ! test -d "${PROJECTS_ROOT_DIR}php-quality-tools"; then
    mkdir ${PROJECTS_ROOT_DIR}php-quality-tools
fi

cd ${PROJECTS_ROOT_DIR}php-quality-tools/
composer require squizlabs/php_codesniffer # Integrates in PHPStorm
composer require phpmd/phpmd --with-all-dependencies # Integrates in PHPStorm, but requires configuration
composer require phpstan/phpstan --with-all-dependencies # Integrates in PHPStorm, but requires configuration
composer require vimeo/psalm --with-all-dependencies # Integrates in PHPStorm, but requires configuration
composer require povils/phpmnd --with-all-dependencies # Runs with the `MND` alias
composer upgrade

# File template to allow creating new documents from the context menu
touch ~/Templates/Untitled

# Cleanup unneeded packages
sudo apt autoremove -y

# System reboot
    printf "\033[31;1m"
read -p "/**********************
*
*    ATTENTION!
*
*    System is going to be restarted
*
*    More information is in the repositories:
*    - post-install script - https://github.com/DefaultValue/ubuntu_post_install_scripts
*    - dev infrastructure - https://github.com/DefaultValue/docker_infrastructure
*    - Dockerizer projects - https://github.com/DefaultValue/dockerizer_for_php
*    (open and save the URL to bookmarks)
*
*    PRESS ANY KEY TO CONTINUE
*
\**********************
" nothing

printf "\n*** Job done! Going to reboot in 5 seconds... ***\n"

sleep 5
sudo reboot