ARG DRUPAL_VERSION="10"
ARG PHP_VERSION="8.2"

FROM --platform=$BUILDPLATFORM drupal:${DRUPAL_VERSION}-php${PHP_VERSION}-fpm-alpine AS build

ENV COMPOSER_ALLOW_SUPERUSER="1"

COPY ./ /opt/drupal

RUN --mount=type=cache,target=/root/.composer/cache \
	composer --no-dev install

FROM  nginx:1.27-alpine AS ingress

# Use a .template in order to set environment variables.
COPY ./etc/nginx/default.conf /etc/nginx/templates/default.conf.template

COPY --from=build /opt/drupal/web /opt/drupal/web

FROM drupal:${DRUPAL_VERSION}-php${PHP_VERSION}-fpm-alpine AS server

# Dependencies
RUN apk add --no-cache \
    gcc \
    g++ \
    make \
		git \
		unzip \
    imagemagick \
    autoconf

# Extensions
RUN pecl install \
		apcu \
		uploadprogress \
	&& docker-php-ext-enable \
		apcu \
		uploadprogress

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN { \
		  echo 'upload_max_filesize = 32M'; \
		  echo 'post_max_size = 32M'; \
      echo 'output_buffering = On'; \
      echo 'session.cookie_samesite = "Lax"'; \
    } > "$PHP_INI_DIR/conf.d/custom.ini"

COPY --from=build /opt/drupal /opt/drupal

RUN mkdir -p /opt/drupal/tmp \
  && mkdir -p /opt/drupal/config \
  && mkdir -p /opt/drupal/web/sites/default/files

# Set the permissions.
RUN chmod a-w /opt/drupal/web/sites/default \
  && chmod a-w /opt/drupal/web/sites/default/services.yml \
  && chown -R www-data:www-data /opt/drupal/web/sites/default/files \
  && chown -R www-data:www-data /opt/drupal/config \
  && chown -R www-data:www-data /opt/drupal/tmp
