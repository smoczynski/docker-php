FROM php:8.4-fpm-bookworm

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
    gzip \
    unzip \
    ca-certificates \
    supervisor && \
    apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# INSTALL PHP EXTENSIONS VIA docker-php-ext-install SCRIPT
RUN docker-php-ext-install \
    gd \
    pdo_pgsql \
    session \
    opcache \
    zip

# INSTALL XDEBUG AND ADD FUNCTIONS TO TURN ON/OFF XDEBUG
RUN pecl install xdebug-3.4.3
RUN bash -c 'echo -e "\n[xdebug]\nzend_extension=xdebug.so\nxdebug.client_host=\nxdebug.start_with_request=yes\nxdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/xdebug.ini'

COPY xoff.sh /usr/bin/xoff
COPY xon.sh /usr/bin/xon

RUN set -x \
    && chmod +x /usr/bin/xoff \
    && chmod +x /usr/bin/xon \
    && mv /usr/local/etc/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/xdebug.off \
    && echo 'PS1="[\$(test -e /usr/local/etc/php/conf.d/xdebug.off && echo XOFF || echo XON)] $HC$FYEL[ $FBLE${debian_chroot:+($debian_chroot)}\u$FYEL: $FBLE\w $FYEL]\\$ $RS"' | tee /etc/bash.bashrc /etc/skel/.bashrc;

# INSTALL BLACKFIRE EXTENSION
ARG ARCH=amd64
RUN set -eux; \
    mkdir -p /tmp/bf-cli; \
    curl -fsSL -A "Docker" \
      "https://blackfire.io/api/v1/releases/cli/linux/${ARCH}" \
      | tar -xz -C /tmp/bf-cli; \
    mv /tmp/bf-cli/blackfire /usr/local/bin/blackfire; \
    chmod +x /usr/local/bin/blackfire; \
    rm -rf /tmp/bf-cli

RUN set -eux; \
    PHP_VER="$(php -r 'echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;')"; \
    PROBE_DEST="$(php -r 'echo ini_get("extension_dir");')/blackfire.so"; \
    curl -fsSL -A "Docker" \
      "https://blackfire.io/api/v1/releases/probe/php/linux/${ARCH}/${PHP_VER}" \
      -o /tmp/bf-probe.tgz; \
    tar -xzf /tmp/bf-probe.tgz -C /tmp; \
    mv /tmp/blackfire-*.so "$PROBE_DEST"; \
    echo "extension=blackfire.so" > "$PHP_INI_DIR/conf.d/99-blackfire.ini"; \
    rm -rf /tmp/bf-probe.tgz

# (opcjonalny test wersji – możesz skasować)
RUN blackfire version && php -m | grep blackfire

# COMPOSER
ENV COMPOSER_HOME=/usr/local/composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php --install-dir=/usr/bin --filename=composer
RUN rm composer-setup.php
RUN bash -c 'echo -e "{ \"config\" : { \"bin-dir\" : \"/usr/local/bin\" } }\n" > /usr/local/composer/composer.json'
RUN echo "export COMPOSER_HOME=/usr/local/composer" >> /etc/bash.bashrc

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

# COPY PHP.INI SUITABLE FOR DEVELOPMENT
COPY php.ini.development /usr/local/etc/php/php.ini
COPY php-fixture.ini /usr/local/etc/php/php-fixture.ini

# CREATE PHP.INI FOR CLI AND TWEAK IT
RUN cp /usr/local/etc/php/php.ini /usr/local/etc/php/php-cli.ini && \
    sed -i "s|memory_limit.*|memory_limit = -1|" /usr/local/etc/php/php-cli.ini

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

# INSTALL DEVELOPMENT UTILS FOR COVERAGE
RUN pecl install pcov && echo "extension=pcov.so\npcov.enabled=0" > /usr/local/etc/php/conf.d/pcov.ini

# INSTALL POSTGRES FOR PG_DUMP IN TESTS
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

RUN apt-get update && \
    apt-get install -y \
    gnupg2 \
    postgresql-client-15  && \
    apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# APPLY HARDENING
RUN set -eux; \
    git clone --depth 1 --branch v4.1-5 https://github.com/ovh/debian-cis.git /opt/cis-hardening && \
    cp /opt/cis-hardening/debian/default /etc/default/cis-hardening && \
    /opt/cis-hardening/bin/hardening.sh --set-version debian_12 && \
    /opt/cis-hardening/bin/hardening.sh --set-hardening-level 1 && \
    /opt/cis-hardening/bin/hardening.sh --apply
