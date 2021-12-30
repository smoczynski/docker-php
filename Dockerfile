FROM php:8.1-fpm

MAINTAINER Radek Smoczynski <radek.smoczynski@gmail.com>

# INSTALL ESSENTIALS LIBS TO COMPILE PHP EXTENSTIONS
RUN apt-get update && apt-get install -y \
    # for zip ext
    zlib1g-dev libzip-dev\
    # for pg_pgsql ext
    libpq-dev \
    # for soap and xml related ext
    libxml2-dev \
    # for xslt ext
    libxslt-dev \
    # for gd ext
    libjpeg-dev libpng-dev \
    # for intl ext
    libicu-dev \
    # for mbstring ext
    libonig-dev \
    # openssl
    libssl-dev \
    git \
    htop \
    nano \
    iputils-ping \
    curl \
    sudo \
    procps \
    iproute2 \
    cron \
    supervisor

# INSTALL PHP EXTENSIONS VIA docker-php-ext-install SCRIPT
RUN docker-php-ext-install \
    bcmath \
    calendar \
    ctype \
    dba \
    dom \
    exif \
    fileinfo \
    ftp \
    gettext \
    gd \
    iconv \
    intl \
    mbstring \
    opcache \
    pcntl \
    pdo \
    pdo_pgsql \
    pdo_mysql \
    posix \
    session \
    simplexml \
    soap \
    sockets \
    xsl \
    zip

# INSTALL XDEBUG
RUN pecl install xdebug-beta
RUN bash -c 'echo -e "\n[xdebug]\nzend_extension=xdebug.so\nxdebug.client_host=\nxdebug.start_with_request=yes\nxdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/xdebug.ini'

# INSTALL XDEBUG AND ADD FUNCTIONS TO TURN ON/OFF XDEBUG
COPY xoff.sh /usr/bin/xoff
COPY xon.sh /usr/bin/xon

RUN set -x \
    && chmod +x /usr/bin/xoff \
    && chmod +x /usr/bin/xon \
    && mv /usr/local/etc/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/xdebug.off \
    && echo 'PS1="[\$(test -e /usr/local/etc/php/conf.d/xdebug.off && echo XOFF || echo XON)] $HC$FYEL[ $FBLE${debian_chroot:+($debian_chroot)}\u$FYEL: $FBLE\w $FYEL]\\$ $RS"' | tee /etc/bash.bashrc /etc/skel/.bashrc;

# Install blackfire extension
RUN apt-get install -y wget gnupg
RUN wget -q -O - https://packages.blackfire.io/gpg.key | apt-key add - \
    && echo "deb http://packages.blackfire.io/debian any main" | tee /etc/apt/sources.list.d/blackfire.list \
    && apt-get update \
    && apt-get install -y blackfire-agent

# INSTALL MONGODB
RUN pecl install mongodb
RUN bash -c 'echo extension=mongodb.so > /usr/local/etc/php/conf.d/mongodb.ini'

# COMPOSER
ENV COMPOSER_HOME /usr/local/composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php --install-dir=/usr/bin --filename=composer
RUN rm composer-setup.php
RUN bash -c 'echo -e "{ \"config\" : { \"bin-dir\" : \"/usr/local/bin\" } }\n" > /usr/local/composer/composer.json'
RUN echo "export COMPOSER_HOME=/usr/local/composer" >> /etc/bash.bashrc

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER 1

# DOWNLOAD SYMFONY INSTALLER
RUN curl -LsS https://symfony.com/installer -o /usr/local/bin/symfony && chmod a+x /usr/local/bin/symfony

# CLEAN APT AND TMP
RUN apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# COPY PHP.INI SUITABLE FOR DEVELOPMENT
COPY php.ini.development /usr/local/etc/php/php.ini

# CREATE PHP.INI FOR CLI AND TWEAK IT
RUN cp /usr/local/etc/php/php.ini /usr/local/etc/php/php-cli.ini && \
    sed -i "s|memory_limit.*|memory_limit = -1|" /usr/local/etc/php/php-cli.ini

# TWEAK MAIN PHP.INI CONFIG FILE
RUN sed -i "s|upload_max_filesize.*|upload_max_filesize = 128M|" /usr/local/etc/php/php.ini && \
    sed -i "s|post_max_size.*|post_max_size = 128M|" /usr/local/etc/php/php.ini && \
    sed -i "s|max_execution_time.*|max_execution_time = 300|" /usr/local/etc/php/php.ini && \
    sed -i "s|memory_limit.*|memory_limit = 3048M|" /usr/local/etc/php/php.ini

# PREPARE FILE FOR LOGS
RUN mkdir -p /var/log/php-fpm
RUN touch /var/log/php-fpm/access.log

ENV HOME_DIR=/var/www
ENV USER_LOGIN=www-data
ENV USER_ID=1000

RUN usermod -u $USER_ID $USER_LOGIN && \
    groupmod -g $USER_ID $USER_LOGIN && \
    usermod -aG sudo $USER_LOGIN && \
    echo "$USER_LOGIN ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN chown $USER_LOGIN:$USER_LOGIN /usr/local/composer -R

# SYMFONY TWEAK
RUN echo "alias sf='bin/console'" >> $HOME_DIR/.bashrc

# for CI test purposes
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# INSTALL LIBRARY FOR PDF GENERATION
RUN apt-get update && \
    apt-get install -y \
    yarn && \
    apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
