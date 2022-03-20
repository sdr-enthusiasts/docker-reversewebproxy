FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PACKAGES+=(nginx) && \
    KEPT_PACKAGES+=(python3-certbot-nginx) && \
    KEPT_PACKAGES+=(psmisc) && \
    KEPT_PACKAGES+=(libnginx-mod-http-geoip) && \
    KEPT_PACKAGES+=(geoip-database) && \
    # added for debugging
        KEPT_PACKAGES+=(procps nano aptitude netcat libnginx-mod-http-echo) && \
#
# Install all these packages:
    apt-get update && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends  --no-install-suggests\
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} && \
#
# Clean up:
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/*

# Copy the rootfs into place:
#
COPY rootfs/ /

EXPOSE 80
EXPOSE 443
