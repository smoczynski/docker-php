FROM php:8.1-fpm

MAINTAINER Radek Smoczynski <radek.smoczynski@gmail.com>

RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list.d/debian.list

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
    wget \
    gnupg \
    x11vnc \
    xvfb \
    fluxbox \
    wmctrl \
    fonts-liberation \
    libasound2 \
    libnspr4 \
    libnss3 \
    xdg-utils \
    # google chrome dep start
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libgtk-3-0 \
    # google chrome dep end
    wkhtmltopdf \
    libxkbcommon0 \
    supervisor && \
    apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

# INSTALL XDEBUG AND ADD FUNCTIONS TO TURN ON/OFF XDEBUG
RUN pecl install xdebug-beta
RUN bash -c 'echo -e "\n[xdebug]\nzend_extension=xdebug.so\nxdebug.client_host=\nxdebug.start_with_request=yes\nxdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/xdebug.ini'

COPY xoff.sh /usr/bin/xoff
COPY xon.sh /usr/bin/xon

RUN set -x \
    && chmod +x /usr/bin/xoff \
    && chmod +x /usr/bin/xon \
    && mv /usr/local/etc/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/xdebug.off \
    && echo 'PS1="[\$(test -e /usr/local/etc/php/conf.d/xdebug.off && echo XOFF || echo XON)] $HC$FYEL[ $FBLE${debian_chroot:+($debian_chroot)}\u$FYEL: $FBLE\w $FYEL]\\$ $RS"' | tee /etc/bash.bashrc /etc/skel/.bashrc;

# INSTALL BLACKFIRE EXTENSION
RUN wget -q -O - https://packages.blackfire.io/gpg.key | apt-key add - \
    && echo "deb http://packages.blackfire.io/debian any main" | tee /etc/apt/sources.list.d/blackfire.list \
    && apt-get update \
    && apt-get install -y blackfire-agent \
    && apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# INSTALL BLACKFIRE CLIENT
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && mkdir -p /tmp/blackfire \
    && curl -A "Docker" -L https://blackfire.io/api/v1/releases/client/linux_static/amd64 | tar zxp -C /tmp/blackfire \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
    && mv /tmp/blackfire/blackfire /usr/bin/blackfire \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

# COMPOSER
ENV COMPOSER_HOME /usr/local/composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php --install-dir=/usr/bin --filename=composer
RUN rm composer-setup.php
RUN bash -c 'echo -e "{ \"config\" : { \"bin-dir\" : \"/usr/local/bin\" } }\n" > /usr/local/composer/composer.json'
RUN echo "export COMPOSER_HOME=/usr/local/composer" >> /etc/bash.bashrc

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER 1

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

# INSTALL GOOGLE CHROME
COPY lib/google-chrome-stable_90.0.4430.72-1_amd64.deb /tmp/google-chrome-stable_90.0.4430.72-1_amd64.deb
RUN dpkg -i /tmp/google-chrome-stable_90.0.4430.72-1_amd64.deb

# INSTALL wkhtmltopdf strict 0.12.4 version, 0.12.5 does not exist in github, 0.12.6 break styles in certificates
RUN OLD_DIR=$(pwd) && \
    mkdir wkhtmltopdf-temp && \
    cd wkhtmltopdf-temp && \
    wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz && \
    tar -xf wk* && \
    cp wkhtmltox/bin/wkhtmltopdf $(which wkhtmltopdf) && \
    cp wkhtmltox/bin/wkhtmltoimage $(which wkhtmltoimage) && \
    cd $OLD_DIR && \
    rm -rf wkhtmltopdf-temp


# INSTALL POSTGRES FOR PG_DUMP IN TESTS
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

RUN apt-get update && \
    apt-get install -y \
    gnupg2 \
    postgresql-15  && \
    apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
