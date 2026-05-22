FROM php:8.4-apache

# 1. Install required system tools and libraries
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zip \
    unzip \
    git \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql gd

# 2. Install Node.js & NPM natively (needed to compile Vite/Tailwind)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# 3. Enable Apache URL rewriting for Laravel routing rules
RUN a2enmod rewrite

# 4. Point Apache's root traffic directly into Laravel's public directory
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 5. Set container work directory and pull code files
WORKDIR /var/www/html
COPY . .

# 6. Install global Composer and pull PHP backend dependencies
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --optimize-autoloader

# 7. Install frontend dependencies and build assets
RUN npm install && npm run build

# 8. Set secure directory folder access permissions for Laravel
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# 9. Isolate a clean SQLite file container inside the database directory
RUN mkdir -p database && touch database/database.sqlite && chown -R www-data:www-data database

# 10. Run migrations/seeders, then launch Apache web worker process natively
CMD php artisan migrate:fresh --seed --force && apache2-foreground