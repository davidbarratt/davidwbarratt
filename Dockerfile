ARG UPSTREAM="drupal:9-php8.1-apache-buster"

FROM --platform=$BUILDPLATFORM ${UPSTREAM} AS build

ENV COMPOSER_ALLOW_SUPERUSER="1"

COPY ./ /opt/drupal

RUN composer --no-dev install

FROM ${UPSTREAM} as dev

# Dependencies
RUN apt-get update && apt-get install -y \
		git \
		unzip \
    imagemagick \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

# Extensions
RUN pecl install \
		apcu \
		uploadprogress \
	&& docker-php-ext-enable \
		apcu \
		uploadprogress

# Set the max upload size.
RUN { \
		echo 'upload_max_filesize = 32M'; \
		echo 'post_max_size = 32M'; \
	} > /usr/local/etc/php/conf.d/upload-filesize.ini

# Enable Apache modules
RUN a2enmod env headers

FROM dev as server

COPY --from=build /opt/drupal /opt/drupal

RUN mkdir -p /opt/drupal/tmp \
  && mkdir -p /opt/drupal/config \
  && mkdir -p /opt/drupal/web/sites/default/files

# Set the permissions.
RUN chown -R www-data:www-data /opt/drupal/web/sites/default/files \
  && chown -R www-data:www-data /opt/drupal/config \
  && chown -R www-data:www-data /opt/drupal/tmp
