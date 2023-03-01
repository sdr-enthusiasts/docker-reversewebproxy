FROM ghcr.io/sdr-enthusiasts/docker-baseimage:python

ENV GEOIP_RESPONSECODE=403
ENV BLOCKBOT_RESPONSECODE=403
ENV LOGROTATE_INTERVAL=3600
ENV LOGROTATE_MAXBACKUPS=24
ENV IPTABLES_JAILTIME=0

LABEL org.opencontainers.image.source = "https://github.com/sdr-enthusiasts/docker-reversewebproxy"

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
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* && \
#
# Enable env module:
    sed -i '/load_module/ a\    load_module modules/ngx_http_env_module.so;' /etc/nginx/nginx.conf && \
# Do some other stuff
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc && \
    echo "PATH=/root:\$PATH" >> /root/.bashrc

# Copy the rootfs into place:
#
COPY rootfs/ /

EXPOSE 80
EXPOSE 443
