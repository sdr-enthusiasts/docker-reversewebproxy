FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python

ENV GEOIP_RESPONSECODE=403
ENV BLOCKBOT_RESPONSECODE=403
ENV LOGROTATE_INTERVAL=3600
ENV LOGROTATE_MAXBACKUPS=24
ENV IPTABLES_JAILTIME=0

LABEL org.opencontainers.image.source = "https://github.com/sdr-enthusiasts/docker-reversewebproxy"

#hadolint ignore=DL3008,SC3054
RUN set -x && \
    # define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PACKAGES+=(nginx) && \
    KEPT_PACKAGES+=(python3-certbot-nginx) && \
    KEPT_PACKAGES+=(psmisc) && \
    KEPT_PACKAGES+=(libnginx-mod-http-geoip) && \
    KEPT_PACKAGES+=(geoip-database) && \
    KEPT_PACKAGES+=(iptables) && \
    KEPT_PACKAGES+=(jq) && \
    TEMP_PACKAGES+=(gpg) && \
    # added for debugging
    KEPT_PACKAGES+=(procps nano netcat-openbsd libnginx-mod-http-echo) && \
    #
    # Install all these packages:
    apt-get update && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends  --no-install-suggests\
    ${KEPT_PACKAGES[@]} \
    ${TEMP_PACKAGES[@]} && \
    # Added for GoAccess server report - see https://goaccess.io/
    mkdir -p /usr/share/keyrings && \
    curl -sSL https://deb.goaccess.io/gnugpg.key | gpg --dearmor > /usr/share/keyrings/goaccess.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/goaccess.gpg arch=$(dpkg --print-architecture)] https://deb.goaccess.io/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/goaccess.list && \
    apt-get update && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends  --no-install-suggests\
        goaccess && \
    #
    # Clean up:
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* /usr/share/keyrings/goaccess.gpg && \
    # remove pycache
    { find /usr | grep -E "/__pycache__$" | xargs rm -rf || true; } && \
    bash /scripts/clean-build.sh && \
    #
    # Do some other stuff
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc && \
    echo "PATH=/root:\$PATH" >> /root/.bashrc

# Copy the rootfs into place:
#
COPY rootfs/ /

EXPOSE 80
EXPOSE 443
