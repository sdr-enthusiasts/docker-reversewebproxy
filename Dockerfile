
FROM debian:buster-20211220-slim

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy needs to be here to prevent github actions from failing.
# SSL Certs are pre-loaded into the rootfs via a job in github action:
# See: "Copy CA Certificates from GitHub Runner to Image rootfs" in deploy.yml

COPY root_certs/ /

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PACKAGES+=(gawk) && \
    KEPT_PACKAGES+=(pv) && \
    TEMP_PACKAGES+=(gnupg2) && \
    TEMP_PACKAGES+=(file) && \
    TEMP_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    # KEPT_PACKAGES+=(procps nano aptitude netcat) && \
    KEPT_PACKAGES+=(nginx) && \
    KEPT_PACKAGES+=(python3-certbot-nginx) && \
    KEPT_PACKAGES+=(psmisc) && \
# Install all these packages:
    apt-get update && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends  --no-install-suggests\
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} && \
#
# install S6 Overlay
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
#
# Clean up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/*
#
# Copy the rootfs into place:
#
COPY rootfs/ /
#
ENTRYPOINT [ "/init" ]

EXPOSE 80
EXPOSE 443
