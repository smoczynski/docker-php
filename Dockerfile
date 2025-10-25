FROM smokarz/php:8.4-v4

RUN curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash && \
    . /root/.bashrc && \
    nvm install 22.14.0 && \
    npm install --global yarn
