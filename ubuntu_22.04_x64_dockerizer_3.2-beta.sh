#!/bin/sh

set -e

if [ "$(id -u)" = 0 ]; then
    echo '\033[31;1m'
    echo 'Installation script must not be run as root!'
    exit 1;
fi

# sudo access will be requested if the script was not run with sudo or under root user
sudo -k

# This causes the following error: ubuntu_18.04.sh: 24: [: =: unexpected operator
# Need to fix it, but the things work fine
if ! [ "$(sudo id -u)" = 0 ]; then
    echo '\033[31;1m'
    echo 'Root password was not entered correctly!'
    exit 1;
fi

sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# Remove all custom app source lists. You must add them back manually if needed.
    printf '\n>>> Removing all custom repository sources! >>>\n'
sudo rm /etc/apt/sources.list.d/* || true

    printf '\n>>> Creating files and folders... >>>\n'
# "db" for dumps and "certs" for SSL certificates
mkdir -p ~/misc/apps ~/misc/certs ~/misc/db

# Install cUrl
    printf '\n>>> cUrl is going to be installed >>>\n'
sudo apt install curl -y

# Install xclip - copy output to clipboard
    printf '\n>>> xclip is going to be installed >>>\n'
sudo apt install xclip -y

    printf '\n>>> Adding repositories and updating software list >>>\n'
# various PHP versions
sudo add-apt-repository ppa:ondrej/php -y
# Shutter screenshot tool
#sudo add-apt-repository ppa:shutter/ppa -y
# Node
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
# Guake terminal
#sudo add-apt-repository ppa:linuxuprising/guake -y

    printf '\n>>> Running Ubuntu upgrade >>>\n'
sudo apt update
sudo apt upgrade -y
# ifconfig since 18.04
sudo apt install net-tools -y

# Install Guake
    printf '\n>>> Guake terminal is going to be installed >>>\n'
    printf '\nAdd a custom shortcut for "guake-toggle": https://askubuntu.com/questions/1406716/function-keys-not-working-at-desktop-on-ubuntu-22-04\n'
sudo apt install guake -y

# Install Sublime Text editor
    printf '\n>>> Sublime Text is going to be installed >>>\n'
sudo snap install sublime-text --classic

# Install Midnight Commander
    printf '\n>>> Midnight Commander is going to be installed >>>\n'
sudo apt install mc -y

# Install Vim text editor
    printf '\n>>> Vim is going to be installed >>>\n'
sudo apt install vim -y

# Install htop utility
    printf '\n>>> htop is going to be installed >>>\n'
sudo apt install htop -y

# Install Git and Git Gui
    printf '\n>>> Git and Git Gui are going to be installed >>>\n'
sudo apt install git git-gui -y

# Install Docker and docker-compose
    printf '\n>>> Docker and docker-compose are going to be installed >>>\n'
# 2020-04.29: Docker 19.03.8 and docker-compose 1.25.0. Using official repo to keep this updatable
sudo apt purge docker* -y
sudo apt install docker.io docker-compose -y
sudo systemctl enable docker
# This is to execute Docker command without sudo. Will work after logout/login because permissions should be refreshed
sudo usermod -aG docker "${USER}"

export DOCKERIZER_PROJECTS_ROOT_DIR=${HOME}/misc/apps/
export DOCKERIZER_SSL_CERTIFICATES_DIR=${HOME}/misc/certs/
export SSL_CERTIFICATES_DIR=$DOCKERIZER_SSL_CERTIFICATES_DIR

# Add aliases and env variables BEFORE we install projects that use them
    printf '\n>>> Creating aliases and enabling color output >>>\n'
if test -f ~/.bash_aliases; then
    mv ~/.bash_aliases ~/bash_aliases_"$(date +%Y-%m-%d_%H:%M)"
fi

# shellcheck disable=SC2028
echo "
force_color_prompt=yes
shopt -s autocd
set completion-ignore-case On

# PHP xDebug 3.x config
export XDEBUG_SESSION=PHPSTORM

export DOCKERIZER_PROJECTS_ROOT_DIR=\${HOME}/misc/apps/
export DOCKERIZER_SSL_CERTIFICATES_DIR=\${HOME}/misc/certs/

COMPOSITIONS() {
    local info='{{.Label \"com.docker.compose.project\"}}\t{{.Label \"com.docker.compose.service\"}}\t{{.Status}}\t{{.Names}}\t{{.Label \"com.docker.compose.project.working_dir\"}}'

    docker container ls --all --filter label=com.docker.compose.project --format \"table \$info\"
}

# === docker-compose aliases ===
alias DOWN='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml down'
alias DOWNV='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml down --volumes'
alias PS='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml ps'
alias RESTART='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml restart'
alias START='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml start'
alias STOP='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml stop'
alias UP='docker-compose -f docker-compose.yaml -f docker-compose-dev-tools.yaml up -d --force-recreate'

# === Dockerizer V3 aliases ===

alias DOCKERIZER='php -d xdebug.mode=off \${DOCKERIZER_PROJECTS_ROOT_DIR}dockerizer_for_php/bin/dockerizer'
alias BUILD='DOCKERIZER composition:build-from-template'
alias SETUP='DOCKERIZER magento:setup'
alias REINSTALL='DOCKERIZER magento:reinstall'

getDockerContainerName()
{
    DOCKERIZER composition:get-container-name \$1
}

getDockerContainerIp()
{
    DOCKERIZER composition:get-container-ip \$1
}

#getMagentoMySQLDatabase()
#{
#    php -r '\$env = include \"../../app/etc/env.php\"; echo \$env[\"db\"][\"connection\"][\"default\"][\"dbname\"];'
#}

#getMagentoMySQLUser()
#{
#    php -r '\$env = include \"../../app/etc/env.php\"; echo \$env[\"db\"][\"connection\"][\"default\"][\"username\"];'
#}

#getMagentoMySQLPassword()
#{
#    php -r '\$env = include \"../../app/etc/env.php\"; echo \$env[\"db\"][\"connection\"][\"default\"][\"password\"];'
#}

alias PHP='docker exec -it \$(getDockerContainerName php) bash'
alias PHPROOT='docker exec -uroot -it \$(getDockerContainerName php) bash'
# DEPRECATED. Must get this data from env variables in MySQL/MariaDB OR write a Dockerizer command to do that
#alias MY='getMagentoMySQLPassword | xclip -selection clipboard ; mysql -h\$(getDockerContainerIp mysql) -u\$(getMagentoMySQLUser) -p \$(getMagentoMySQLDatabase)'
#alias MYROOT='docker exec -it \$(getDockerContainerName mysql) mysql -uroot -proot'

# === PHP aliases ===
alias CI='docker exec -it \$(getDockerContainerName php) composer install'

# === Magento aliases ===
magentoCli() {
    echo \"docker exec -it \$(getDockerContainerName php) php bin/magento\"
}
alias MAGENTO='\$(magentoCli)'
alias CC='\$(magentoCli) cache:clean'
alias CF='\$(magentoCli) cache:flush'
alias IR='\$(magentoCli) indexer:reindex'
alias SU='\$(magentoCli) setup:upgrade'
alias SDC='\$(magentoCli) setup:di:compile'
alias URN='\$(magentoCli) dev:urn-catalog:generate .idea/misc.xml; sed -i \"s/\/var\/www\/html/\\\$PROJECT_DIR\\\$/g\" ../../.idea/misc.xml'
alias MODEDEV='\$(magentoCli) deploy:mode:set developer'
alias MODEDEF='\$(magentoCli) deploy:mode:set default'
alias MODEPROD='\$(magentoCli) deploy:mode:set production'

alias CR='rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* var/di/* var/generation/* generated/code/* generated/metadata/* pub/static/frontend/* pub/static/adminhtml/* pub/static/deployed_version.txt'
alias MCS='php -d xdebug.mode=off \${DOCKERIZER_PROJECTS_ROOT_DIR}magento-coding-standard/vendor/bin/phpcs --standard=Magento2 --severity=1 '
alias MND='php -d xdebug.mode=off \${DOCKERIZER_PROJECTS_ROOT_DIR}php-quality-tools/vendor/bin/phpmnd '" > ~/.bash_aliases

# Install PHP common packages
    printf '\n>>> PHP 8.1 and common modules are going to be installed >>>\n'
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

    printf '\n>>> Creating ini files for the development environment >>>\n'
IniDirs="/etc/php/*/*/conf.d/"
for IniDir in ${IniDirs};
do
    printf 'Creating %s999-custom-config.ini\n' "${IniDir}"
    sudo rm -f "${IniDir}"999-custom-config.ini || true
    printf 'error_reporting=E_ALL & ~E_DEPRECATED
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
xdebug.log_level=0\n' | sudo tee "${IniDir}"999-custom-config.ini > /dev/null
done

IniDirs="/etc/php/*/cli/conf.d/"
for IniDir in ${IniDirs};
do
    printf 'memory_limit=2G\n' | sudo tee -a "${IniDir}"999-custom-config.ini >> /dev/null
done

    printf '\n>>> Enabling php modules: xdebug >>>\n'
sudo phpenmod xdebug

# Install a tool for PHP projects dockerization and fast Magento installation
    printf '\n>>> Installing Dockerizer for PHP tool - https://github.com/DefaultValue/dockerizer_for_php >>>\n'
if ! test -d "${DOCKERIZER_PROJECTS_ROOT_DIR}dockerizer_for_php"; then
    cd "${DOCKERIZER_PROJECTS_ROOT_DIR}"
    git clone https://github.com/DefaultValue/dockerizer_for_php.git
fi

cd "${DOCKERIZER_PROJECTS_ROOT_DIR}"dockerizer_for_php/
git fetch origin
git checkout 3.2.0-development
git config core.fileMode false
git reset --hard HEAD
git pull origin 3.2.0-development --no-rebase
composer install

# @TODO: reinstall for upgrade
if ! test -d "${DOCKERIZER_PROJECTS_ROOT_DIR}traefik-reverse-proxy"; then
    cd "${DOCKERIZER_PROJECTS_ROOT_DIR}"
    mkdir ./traefik-reverse-proxy
    cd ./traefik-reverse-proxy/
    php "${DOCKERIZER_PROJECTS_ROOT_DIR}"dockerizer_for_php/bin/dockerizer composition:build-from-template --template=traefik
    mv ./.dockerizer/reverse-proxy/* ./
    rm -rf ./.dockerizer/
    printf '\nDOCKERIZER_TRAEFIK_SSL_CONFIGURATION_FILE=%straefik-reverse-proxy/traefik/configuration/certificates.toml' "${DOCKERIZER_PROJECTS_ROOT_DIR}" >> ${DOCKERIZER_PROJECTS_ROOT_DIR}dockerizer_for_php/.env.local
    sudo su -c "export DOCKERIZER_SSL_CERTIFICATES_DIR=$DOCKERIZER_SSL_CERTIFICATES_DIR ; docker-compose up -d --force-recreate"
fi

# Allow Dockerizer to write to `/etc/hosts` without asking for password
sudo setfacl -m "${USER}":rw /etc/hosts
# Append Traefik Dashboard domain to `/etc/hosts`
printf '\n127.0.0.1 traefik.docker.local' | tee -a /etc/hosts

# Install Node Package Manager and Grunt tasker
# NodeJS is needed to run JSCS and ESLint for M2 in PHPStorm
    printf '\n>>> NPM and Grunt are going to be installed >>>\n'
sudo apt purge nodejs -y
sudo apt install nodejs -y

# Install VirtualBox from the repository.
# 2020-04-29: Current version is 6.1 (latest one)
    printf '\n>>> VirtualBox are going to be installed >>>\n'
sudo apt install virtualbox -y
    printf '\n>>> Adding VirtualBox user to your group, so it can access USB devices >>>\n'
sudo usermod -aG vboxusers "${USER}"

# Install Google Chrome
    printf '\n>>> Google Chrome is going to be installed >>>\n'
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb

# Install mkcert - https://github.com/FiloSottile/mkcert/releases
    printf '\n>>> Mkcert is going to be installed -https://github.com/FiloSottile/mkcert >>>\n'
sudo apt install libnss3-tools -y
sudo wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
sudo chmod +x mkcert-v1.4.4-linux-amd64
sudo mv mkcert-v1.4.4-linux-amd64 /usr/bin/mkcert
mkcert -install

# Install Shutter
    printf '\n>>> Shutter is going to be installed >>>\n'
sudo apt purge shutter -y
# Shutter may still not work with Wayland, but can be used to easily edit screenshots in Ubuntu 22.04
sudo apt install shutter -y

# Install Diodon clipboard manager because clipit is broken for now :(
    printf '\n>>> Diodon clipboard manager is going to be installed >>>\n'
sudo apt install diodon -y

# Install Slack messenger
    printf '\n>>> Slack messenger is going to be installed >>>\n'
sudo snap install slack

# Install PHPStorm
    printf '\n>>> PHPStorm is going to be installed >>>\n'
sudo snap install phpstorm --classic
    printf '\n>>> Setting filesystem parameters for PHPStorm IDE: fs.inotify.max_user_watches = 524288 >>>\n'
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf > /dev/null

# Install Gnome Tweak Tool for tuning Ubuntu
    printf '\n>>> Gnome Tweak Tool is going to be installed >>>\n'
sudo apt install gnome-tweaks -y

    printf '\n>>> Magento 2 coding standards - https://github.com/magento/magento-coding-standard >>>\n'
if ! test -d "${DOCKERIZER_PROJECTS_ROOT_DIR}magento-coding-standard"; then
    cd "${DOCKERIZER_PROJECTS_ROOT_DIR}"
    git clone https://github.com/magento/magento-coding-standard.git
fi
cd "${DOCKERIZER_PROJECTS_ROOT_DIR}"magento-coding-standard/
git config core.fileMode false
git reset --hard HEAD
git checkout master
git pull origin master --no-rebase
composer install
npm install

    printf '\n>>> Install PHPMD (Mess Detector), PHPStan (Static Analysis Tool) and PHPMND (Magic Number Detector) >>>\n'
if ! test -d "${DOCKERIZER_PROJECTS_ROOT_DIR}php-quality-tools"; then
    mkdir "${DOCKERIZER_PROJECTS_ROOT_DIR}"php-quality-tools
fi

cd "${DOCKERIZER_PROJECTS_ROOT_DIR}"php-quality-tools/
composer require squizlabs/php_codesniffer --dev # Integrates in PHPStorm
composer require phpmd/phpmd # Integrates in PHPStorm, but requires configuration
composer require phpstan/phpstan --dev # Integrates in PHPStorm, but requires configuration
composer require vimeo/psalm --dev # Integrates in PHPStorm, but requires configuration
composer require povils/phpmnd # Runs with the `MND` alias
composer upgrade

# File template to allow creating new documents from the context menu
touch ~/Templates/Untitled

# Cleanup unneeded packages
sudo apt autoremove -y

# System reboot
printf '\033[31;1m/**********************
*
*    ATTENTION!
*
*    System is going to be restarted
*
*    More information is in the repositories:
*    - Ubuntu post-install scripts - https://github.com/DefaultValue/ubuntu_post_install_scripts
*    - Dockerizer projects - https://github.com/DefaultValue/dockerizer_for_php
*    - Development infrastructure - https://github.com/DefaultValue/docker_infrastructure
*    (open and save the URL to bookmarks)
*
*    PRESS ANY KEY TO CONTINUE
*
\**********************
'
read -r

printf '\n*** Job done! Going to reboot in 5 seconds... ***\n'

sleep 5
sudo reboot