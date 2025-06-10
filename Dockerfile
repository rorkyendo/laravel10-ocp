FROM php:8.2-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip git curl \
    && pecl install redis \
    && docker-php-ext-enable redis
    && docker-php-ext-install pdo pdo_mysql zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader \
 && chown -R www-data:www-data /var/www/html

EXPOSE 9000

CMD ["php-fpm"]

