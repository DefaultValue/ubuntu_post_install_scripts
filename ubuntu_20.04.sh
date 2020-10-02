#!/bin/sh
# sudo access will be requested if the script was not run with sudo or under root user
sudo -k

# This causes the following error: ubuntu_18.04.sh: 24: [: =: unexpected operator
# Need to fix it, but the things work fine
if ! [ $(sudo id -u) = 0 ]; then
    echo "\033[31;1m"
    echo "Root password was not entered correctly!"
    exit 1;
fi

sudo apt-get update
sudo apt-get upgrade -y

    printf "\n>>> Creating files and folders... >>>\n"
# "db" for dumps and "certs" for SSL certificates
mkdir -p ~/misc/apps ~/misc/certs ~/misc/db

# Install cUrl
    printf "\n>>> cUrl is going to be installed >>>\n"
sudo apt-get install curl -y

    printf "\n>>> Adding repositories and updating software list >>>\n"
# various PHP versions
sudo add-apt-repository ppa:ondrej/php -y
# Chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
# Shutter screenshot tool
sudo add-apt-repository ppa:linuxuprising/shutter -y
# Node
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
# Guake terminal
sudo add-apt-repository ppa:linuxuprising/guake -y

    printf "\n>>> Running Ubuntu upgrade >>>\n"
sudo apt-get update
sudo apt-get upgrade -y
# ifconfig since 18.04
sudo apt-get install net-tools -y

# Install Tilda
    printf "\n>>> Guake terminal is going to be installed >>>\n"
sudo apt-get install guake -y

# Install Sublime Text editor
    printf "\n>>> Sublime Text is going to be installed >>>\n"
sudo snap install sublime-text --classic

# Install Midnight Commander
    printf "\n>>> Midnight Commander is going to be installed >>>\n"
sudo apt-get install mc -y

# Install Vim text editor
    printf "\n>>> Vim is going to be installed >>>\n"
sudo apt-get install vim -y

# Install htop utility
    printf "\n>>> htop is going to be installed >>>\n"
sudo apt-get install htop -y

# Install Git and Git Gui
    printf "\n>>> Git and Git Gui are going to be installed >>>\n"
sudo apt-get install git git-gui -y

# Install Docker and docker-compose
    printf "\n>>> Docker and docker-compose are going to be installed >>>\n"
sudo apt-get install mysql-client -y
# 2020-04.29: Docker 19.03.8 and docker-compose 1.25.0. Using official repo to keep this updateable
sudo apt-get install docker.io docker-compose -y
sudo systemctl enable docker
# This is to execute Docker command without sudo. Will work after logout/login because permissions should be refreshed
sudo usermod -aG docker ${USER}

# Install MySQL client and MySQL servers 5.6 + 5.7 from Docker images
    printf "\n>>> Traefik, MySQL 5.6, 5.7 and phpMyAdmin are going to be installed via docker-compose - https://github.com/DefaultValue/docker_infrastructure >>>\n"
export PROJECTS_ROOT_DIR=${HOME}/misc/apps/
export SSL_CERTIFICATES_DIR=${HOME}/misc/certs/
export EXECUTION_ENVIRONMENT=development
cd ~/misc/apps/
git clone https://github.com/DefaultValue/docker_infrastructure.git
cd ~/misc/apps/docker_infrastructure/
git config core.fileMode false
cd ~/misc/apps/docker_infrastructure/local_infrastructure/
cp configuration/certificates.toml.dist configuration/certificates.toml
# @TODO: extend infrastructure files with the enviromnent variables for project root and certificates folder to mount
sed -i "s/\/misc\/share\/ssl/\/home\/$USER\/misc\/certs/g" docker-compose.yml
# run docker-compose this way because we need not to log out in order to refresh permissions
sudo docker-compose up -d
echo "
127.0.0.1 phpmyadmin.docker.local
127.0.0.1 traefik.docker.local" | sudo tee -a /etc/hosts

# Install PHP common packages
    printf "\n>>> Install common PHP packages (php-pear php-imagick php-memcached php-ssh2 php-xdebug) and composer >>>\n"
# The following NEW packages will be installed:
# php-cli php-pear php-ssh2 php-xdebug php-xml php7.4-cli php7.4-common php7.4-json php7.4-opcache php7.4-readline php7.4-xml
sudo apt-get install php-pear php-ssh2 php-xdebug -y
# Install PHP 7.4 and modules, enable modules. Anyway try installing all packages in case the dependencies change
    printf "\n>>> PHP 7.4 and common modules are going to be installed >>>\n"
sudo apt-get install php7.4-cli php7.4-common php7.4-json --no-install-recommends -y
sudo apt-get install php7.4-bz2 php7.4-curl php7.4-mbstring php7.4-mysql php7.4-opcache php7.4-readline php7.4-xml php7.4-zip -y
sudo apt-get install composer -y

    printf "\n>>> Install composer package for paralell dependency downloads hirak/prestissimo globally >>>\n"
composer global require hirak/prestissimo

    printf "\n>>> Creating ini files for the development environment >>>\n"
IniDirs=/etc/php/*/*/conf.d/
for IniDir in ${IniDirs};
do
    printf "Creating ${IniDir}/999-custom-config.ini\n"
sudo rm ${IniDir}999-custom-config.ini
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

xdebug.remote_enable=1
xdebug.remote_handler=dbgp
xdebug.remote_mode=req
xdebug.remote_host=127.0.0.1
xdebug.remote_port=9000
xdebug.max_nesting_level=256
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
# XDEBUG_CONFIG is important for CLI debugging
echo "
force_color_prompt=yes
shopt -s autocd
set completion-ignore-case On

export XDEBUG_CONFIG=\"idekey=PHPSTORM\"

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
alias RE='docker exec -it \$(getContainerName) php bin/magento indexer:reindex'
alias URN='docker exec -it \$(getContainerName) php bin/magento dev:urn-catalog:generate .idea/misc.xml; sed -i \"s/\/var\/www\/html/\\\$PROJECT_DIR\\\$/g\" .idea/misc.xml'

alias DOCKERIZE='/usr/bin/php7.4 \${PROJECTS_ROOT_DIR}dockerizer_for_php/bin/console dockerize '
alias SETUP='/usr/bin/php7.4 \${PROJECTS_ROOT_DIR}dockerizer_for_php/bin/console magento:setup '
alias ENVADD='/usr/bin/php7.4 \${PROJECTS_ROOT_DIR}dockerizer_for_php/bin/console env:add '
alias CR='rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* var/di/* var/generation/* generated/code/* generated/metadata/* pub/static/frontend/* pub/static/adminhtml/* pub/static/deployed_version.txt'
alias MCS='\${PROJECTS_ROOT_DIR}magento-coding-standard/vendor/bin/phpcs --standard=Magento2 --severity=1 '" >> ~/.bash_aliases

# Install a tool for PHP projects dockerization and fast Magento installation
    printf "\n>>> Installing Dockerizer for PHP tool - https://github.com/DefaultValue/dockerizer_for_php >>>\n"
cd ~/misc/apps
git clone https://github.com/DefaultValue/dockerizer_for_php.git
cd ./dockerizer_for_php/
git config core.fileMode false
composer install

# Install Node Package Manager and Grunt tasker
# NodeJS is needed to run JSCS and ESLint for M2 in PHPStorm
    printf "\n>>> NPM and Grunt are going to be installed >>>\n"
sudo apt-get install nodejs -y

    printf "\n>>> LiveReload extension is going to be clonned and built - https://github.com/lokcito/livereload-extensions >>>\n"
cd ~/misc/apps/
git clone https://github.com/lokcito/livereload-extensions.git
cd ./livereload-extensions/
git config core.fileMode false
sudo npm install -g grunt-cli
grunt chrome

# Install VirtualBox from the repository.
# 2020-04-29: Current version is 6.1 (latest one)
    printf "\n>>> VirtualBox are going to be installed >>>\n"
sudo apt install virtualbox -y
    printf "\n>>> Adding VirtualBox user to your group, so it can access USB devices >>>\n"
sudo usermod -aG vboxusers ${USER}

# Install Google Chrome
    printf "\n>>> Google Chrome is going to be installed >>>\n"
sudo apt-get install google-chrome-stable -y

# Install Homebrew and mkcert
    printf "\n>>> Homebrew and mkcert are going to be installed - https://github.com/FiloSottile/mkcert >>>\n"
sudo apt-get install libnss3-tools -y
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" < /dev/null
test -d ~/.linuxbrew && eval $(~/.linuxbrew/bin/brew shellenv)
test -d /home/linuxbrew/.linuxbrew && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
test -r ~/.bash_profile && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.bash_profile
echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.profile
brew install mkcert
mkcert -install

# Install Shutter
    printf "\n>>> Shutter is going to be installed >>>\n"
sudo apt-get install shutter -y

# Install KeePassXC - free encrypted password storage
    printf "\n>>> KeePassXC is going to be installed >>>\n"
sudo snap install keepassxc

# Install Dropbox
    printf "\n>>> Dropbox is going to be installed >>>\n"
sudo apt-get install nautilus-dropbox -y
sudo nautilus --quit

# Install Diodon clipboard manager because clipit is broken for now :(
    printf "\n>>> ClipIt clipboard manager is going to be installed >>>\n"
sudo apt-get install diodon -y

# Install Slack messanger
    printf "\n>>> Slack messanger is going to be installed >>>\n"
sudo snap install slack --classic

# Install PHPStorm EAP (Early Access Program) that is free. Use licensed version if you have it!
    printf "\n>>> PHPStorm EAP is going to be installed >>>\n"
sudo snap install phpstorm --classic --edge
    printf "\n>>> Setting filesystem parameters for PHPStorm IDE: fs.inotify.max_user_watches = 524288 >>>\n"
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf > /dev/null

# Install Gnome Tweak Tool for tuning Ubuntu
    printf "\n>>> Gnome Tweak Tool is going to be installed >>>\n"
sudo apt-get install gnome-tweak-tool -y

    printf "\n>>> Magento 2 coding standards - https://github.com/magento/magento-coding-standard >>>\n"
cd ~/misc/apps/
git clone https://github.com/magento/magento-coding-standard.git
cd ./magento-coding-standard/
git config core.fileMode false
composer install

    printf "\n>>> Magento 1 coding standards - https://github.com/magento/marketplace-eqp >>>\n"
cd ~/misc/apps/
git clone https://github.com/magento/marketplace-eqp.git
cd ./marketplace-eqp/
git config core.fileMode false
composer install

# File template to allow creating new documents from the context menu
touch ~/Templates/Untitled

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
*    - dockerize projects - https://github.com/DefaultValue/dockerizer_for_php
*    (open and save the URL to bookmarks)
*
*    PRESS ANY KEY TO CONTINUE
*
\**********************
" nothing

printf "\n*** Job done! Going to reboot in 5 seconds... ***\n"

sleep 5
sudo reboot