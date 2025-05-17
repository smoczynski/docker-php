FROM smokarz/php:8.4-v1

RUN curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash && \
    . /root/.bashrc && \
    nvm install 13.7.0 && \
    npm install --global yarn
