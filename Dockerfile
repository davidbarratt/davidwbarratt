ARG DRUPAL_VERSION="11"
ARG PHP_VERSION="8.3"
ARG APCU_VERSION="5.1.28"
ARG UPLOADPROGRESS_VERSION="2.0.2"

FROM --platform=$BUILDPLATFORM drupal:${DRUPAL_VERSION}-php${PHP_VERSION}-fpm-alpine AS build

ENV COMPOSER_ALLOW_SUPERUSER="1"
ENV COMPOSER_EXIT_ON_PATCH_FAILURE="1"

# Remove the Drupal install that is in the image to prevent conflicts with the
# version being added with Composer.
RUN rm -rf /opt/drupal

RUN apk add --no-cache \
    patch \
		git \
		unzip

COPY ./ /opt/drupal

RUN --mount=type=cache,target=/root/.composer/cache \
	composer --no-dev install

FROM  nginx:1.27-alpine AS ingress

ENV NGINX_ROOT="/opt/drupal/web"
ENV NGINX_PORT="80"

# Use a .template in order to set environment variables.
COPY ./etc/nginx/templates/default.conf.template /etc/nginx/templates/default.conf.template

COPY --from=build /opt/drupal/web /opt/drupal/web

CMD ["nginx", "-g", "daemon off;", "-p", "/opt/drupal"]

FROM drupal:${DRUPAL_VERSION}-php${PHP_VERSION}-fpm-alpine AS server

# Remove the Drupal install that is in the image to prevent conflicts with the
# version being copied from the `build` layer.
RUN rm -rf /opt/drupal

# Dependencies
RUN apk add --no-cache \
    $PHPIZE_DEPS \
    imagemagick

# Extensions
#
# Pass the release archives instead of package names. `pecl install <name>`
# resolves the latest release through the channel's REST API, and
# https://pecl.php.net/rest/r/<package>/info.xml currently returns 404 (the site
# now sits behind BunnyCDN), so name-based installs fail immediately with
# `No releases available for package "pecl.php.net/apcu"`. The /get/<pkg>-<ver>.tgz
# download path and the build itself are unaffected.
#
# Consequence: these versions are pinned and must be bumped by hand. Drop the
# URLs back to plain package names once PECL restores its REST endpoints:
# https://github.com/php/web-pecl
RUN pecl install \
        "https://pecl.php.net/get/apcu-${APCU_VERSION}.tgz" \
        "https://pecl.php.net/get/uploadprogress-${UPLOADPROGRESS_VERSION}.tgz" \
    && docker-php-ext-enable \
        apcu \
        uploadprogress

RUN apk del $PHPIZE_DEPS

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
