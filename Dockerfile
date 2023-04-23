FROM drupal:9-apache

LABEL org.opencontainers.image.source https://github.com/davidbarratt/davidwbarratt

# Dependencies
RUN apt-get update && apt-get install -y \
		git \
		unzip \
    imagemagick \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

# Extensions
RUN pecl install \
		APCu-5.1.19 \
		uploadprogress-1.1.3 \
	; \
	docker-php-ext-enable \
		apcu \
		uploadprogress \
	;

# Set the max upload size.
RUN { \
		echo 'upload_max_filesize = 32M'; \
		echo 'post_max_size = 32M'; \
	} > /usr/local/etc/php/conf.d/upload-filesize.ini

# Enable Apache modules
RUN a2enmod env headers

COPY ./ /opt/drupal

RUN composer --no-dev install

RUN mkdir -p /opt/drupal/tmp \
  && mkdir -p /opt/drupal/config \
  && mkdir -p /opt/drupal/web/sites/default/files

# Set the permissions.
RUN chown -R www-data:www-data /opt/drupal/web/sites/default/files \
  && chown -R www-data:www-data /opt/drupal/config \
  && chown -R www-data:www-data /opt/drupal/tmp
