FROM php:5-apache

RUN apt-get update && apt-get install -y \
        git \
        vim \
        libpng-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
        libdbi-perl \
        libdbd-mysql-perl \
        gettext-base \
        cron
RUN rm -rfv /var/lib/apt/lists/*

RUN PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Geo::IP::PurePerl'

COPY php.ini.example /usr/local/etc/php/php.ini

RUN docker-php-ext-configure gd \
        --enable-gd-native-ttf \
        --with-freetype-dir=/usr/include/freetype2 \
        --with-png-dir=/usr/include \
        --with-jpeg-dir=/usr/include
RUN docker-php-ext-install gd opcache mysql
RUN docker-php-ext-enable opcache

RUN mkdir /noxus
COPY . /noxus/
WORKDIR /noxus

RUN chmod +x ./hlxce/scripts/run_hlstats ./hlxce/scripts/hlstats.pl ./hlxce/scripts/hlstats-awards.pl
RUN curl -L http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz |  \
    gunzip - > ./hlxce/scripts/GeoLiteCity/GeoLiteCity.dat
RUN cp -rv hlxce/web/* /var/www/html/ && chown -R www-data:www-data /var/www/html/
COPY crontab.example /etc/cron.d/daily-awards
RUN touch /var/log/cron.log