ARG DRUPAL_VERSION="9"
ARG PHP_VERSION="8.1"

FROM --platform=$BUILDPLATFORM "drupal:${DRUPAL_VERSION}-php${PHP_VERSION}-apache-buster" AS build

ENV COMPOSER_ALLOW_SUPERUSER="1"

COPY ./ /opt/drupal

RUN --mount=type=cache,target=/root/.composer/cache \
	composer --no-dev install

FROM "drupal:${DRUPAL_VERSION}-php${PHP_VERSION}-apache-buster" as server

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

COPY --from=build /opt/drupal /opt/drupal

RUN mkdir -p /opt/drupal/tmp \
  && mkdir -p /opt/drupal/config \
  && mkdir -p /opt/drupal/web/sites/default/files

# Set the permissions.
RUN chown -R www-data:www-data /opt/drupal/web/sites/default/files \
  && chown -R www-data:www-data /opt/drupal/config \
  && chown -R www-data:www-data /opt/drupal/tmp
