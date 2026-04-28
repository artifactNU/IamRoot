ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-apache

RUN apt-get update && apt-get install -y \
        libpng-dev \
        libjpeg-dev \
        libzip-dev \
        zip \
        unzip \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        mbstring \
        gd \
        zip \
        opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*
