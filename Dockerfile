FROM php:8.2-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip git curl \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && docker-php-ext-install pdo pdo_mysql zip

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy source code
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 777 storage bootstrap/cache

# RUN chown -R www-data:www-data storage bootstrap/cache && \
#     chmod -R ug+rwX storage bootstrap/cache

# Setup Laravel
RUN cp .env.example .env \
    && composer install --no-dev --optimize-autoloader \
    # && php artisan key:generate \
    && php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && chown -R www-data:www-data /var/www/html

# Prevent FPM warning about user/group directive
RUN sed -i 's/^user = .*/; user = www-data/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^group = .*/; group = www-data/' /usr/local/etc/php-fpm.d/www.conf

EXPOSE 9000

USER www-data

CMD ["php-fpm"]
