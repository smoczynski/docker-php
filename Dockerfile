FROM smokarz/php:8.1-v1

RUN bash -c 'echo -e "\n[xdebug]\nzend_extension=xdebug.so\nxdebug.client_host=\nxdebug.start_with_request=yes\nxdebug.mode=coverage" >> /usr/local/etc/php/conf.d/xdebug.ini'
RUN mv /usr/local/etc/php/conf.d/xdebug.off /usr/local/etc/php/conf.d/xdebug.ini

RUN curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash && \
    . /root/.bashrc && \
    nvm install 13.7.0 && \
    npm install --global yarn