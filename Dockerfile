# Shopware — LOCAL DEV image on the production base image.
#
# Production and local development both inherit from the central FrankenPHP
# base image base/shopware (repo base-image-shopware, xebro account). This file
# only adds local development tooling on top: Xdebug, Node, Composer and dev PHP
# overrides. The application path stays /app, matching production.
#
ARG BASE_ECR_REGISTRY=local

# ---------------------------------------------------------------------------
FROM ${BASE_ECR_REGISTRY}/base/shopware:base-web AS dev

COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions @composer \
    && (install-php-extensions xdebug || echo "WARN: xdebug not available for this PHP version, skipping")

# Node for the storefront/admin watchers and asset builds
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs git unzip rsync \
    && rm -rf /var/lib/apt/lists/*

# development overrides — revalidate opcache, Xdebug on demand
ENV XDEBUG_MODE=off
RUN { \
        echo 'opcache.validate_timestamps = 1'; \
        echo 'expose_php = On'; \
    } > /usr/local/etc/php/conf.d/zz-dev.ini \
    && { \
        echo 'xdebug.client_host = host.docker.internal'; \
        echo 'xdebug.start_with_request = trigger'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini || true

WORKDIR /app
