FROM davidbarratt/drupal:9

LABEL org.opencontainers.image.source https://github.com/davidbarratt/davidwbarratt

COPY ./ /opt/drupal

RUN composer --no-dev install

RUN mkdir -p /opt/drupal/tmp \
  && mkdir -p /opt/drupal/config \
  && mkdir -p /opt/drupal/web/sites/default/files

# Set the permissions.
RUN chown -R www-data:www-data /opt/drupal/web/sites/default/files \
  && chown -R www-data:www-data /opt/drupal/config \
  && chown -R www-data:www-data /opt/drupal/tmp
