# Docker-ReverseWebProxy

<img align="right" src="https://raw.githubusercontent.com/sdr-enthusiasts/sdr-enthusiast-assets/main/SDR%20Enthusiasts.svg" height="300">

## Table of Contents

- [Docker-ReverseWebProxy](#docker-reversewebproxy)
  - [Table of Contents](#table-of-contents)
  - [What is it?](#what-is-it)
  - [How do I get it?](#how-do-i-get-it)
  - [How do I configure it?](#how-do-i-configure-it)
    - [General parameters](#general-parameters)
    - [Configuration of the Webproxy](#configuration-of-the-webproxy)
    - [Configuration of SSL](#configuration-of-ssl)
    - [GeoIP Filtering](#geoip-filtering)
    - [BlockBot Filtering](#blockbot-filtering)
    - [`iptables` blocking](#iptables-blocking)
    - [Basic Authentication](#basic-authentication)
    - [Advanced Setup](#advanced-setup)
    - [Host your own web pages](#host-your-own-web-pages)
      - [Access Report Page using `goaccess`](#access-report-page-using-goaccess)
      - [Automatic creation of web pages with geographic map of visitors](#automatic-creation-of-web-pages-with-geographic-map-of-visitors)
    - [Extras](#extras)
  - [Troubleshooting](#troubleshooting)
  - [Acknowledgements](#acknowledgements)
  - [License](#license)

## What is it?

This application, further referred to as "Webproxy", enables to show a single website for multiple web services running on different machines and/or different ports.

The need for a solution is age-old, but what triggered the creation of this project was the deployment of Dockerized web services for a ADSB Feeder station. These web services are distributed over 1 or more Raspberry Pi's, and each of them provides a web interface on a different TCP port. As a result, the user has to remember a collection of seemingly random IP addresses and port numbers to get to these web services, which creates an awful user experience.

The Webproxy allows the user to map these web services to a single URL, differentiating them by assigning a virtual directory name for each.

The following example highlights this:

| Web Service | Original address              | New Address with Webproxy |
| ----------- | ----------------------------- | ------------------------- |
| readsb      | <http://10.0.0.191:8080>        | <http://myip/readsb>        |
| piaware     | <http://10.0.0.191:8081>        | <http://myip/piaware>       |
| tar1090     | <http://10.0.0.191:8082>        | <http://myip/tar1090>       |
| planefence  | <http://10.0.0.191:8083>        | <http://myip/planefence>    |
| planefinder | <http://10.0.0.191:8086>        | <http://myip/planefinder>   |
| graphs      | <http://10.0.0.191:8080/graphs> | <http://myip/graphs>        |
| radar       | <http://10.0.0.191:8080/radar>  | <http://myip/radar>         |
| acarshub    | <http://10.0.0.188>             | <http://myip/acarshub>      |

## How do I get it?

Prerequisite for this to work, is that you have a working `Docker` and `Docker-compose` setup.
This is less than 5 minutes of work -- use [this script](https://github.com/sdr-enthusiasts/docker-install) or follow all 3 steps of the "Setting up the Host System" section at [this GitBook](https://sdr-enthusiasts.gitbook.io/ads-b/setting-up-the-host-system/install-docker).

Once this is done, create a working directory and download the `docker-compose.yml` file:

```bash
sudo mkdir -p -m 777 /opt/webproxy && cd /opt/webproxy
wget https://raw.githubusercontent.com/sdr-enthusiasts/docker-reversewebproxy/main/docker-compose.yml
```

You should EDIT the `docker-compose.yml` file included in this repository and configure it to your liking. See below for options.
(Note - CAREFUL. YML is based on indentation levels, so make sure you keep each line at the correct indent level!)

Now, you can either run it as-is, or, if you already have another `docker-compose.yml`, you can copy the data of the `services:` section to your existing `docker-compose.yml`.

With that, you are ready to run the proxy!

## How do I configure it?

The Webproxy can be entirely configured in the `docker-compose.yml`, or, optionally, you can create a more advanced setup manually. You can also start with the `docker-compose.yml` configuration and then add to this manually in the future. Here's how:

### General parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `AUTOGENERATE` | `ON`, `OFF` | Determines if the system will use the `REVPROXY` and `REDIRECT` settings of the `docker-compose.yml` file (`ON`), or a manually generated `locations.conf` file (`OFF`). |
| `VERBOSELOG` | `ON`, `OFF` | Determines if the internal web service Access and Error logs will be written to the Docker log (accessible with `docker logs webproxy`) (`ON`), or that logging will be switched `OFF` |
| `CORSHOSTS` | hostname(s), or `_`, or empty | Set CORS* via the `Access-Control-Allow-Origin` header. If using a single hostname, only that hostname will be set. If using multiple comma-separated hostnames, the header will be set for "`*`" all hosts, not just those listed. If using "`_`", CORS will be hard-disabled |
| `PROXY_READ_TIMEOUT` | time (secs) or `ON` | This parameter controls the `proxy_read_timeout` parameter for `nginx`. This parameter is an inactivity timeout for reverse-proxied websites. This is needed if you want to keep a connection going with a proxied website, even if this website doesn't send any information for some period of time. An example of this is the [Portainer Container Console](https://github.com/portainer/portainer/issues/2953). If set to a value, it will use this value (in seconds) for timeout. If set to `ON` or `true`, the timeout is set to `3600` seconds (1 hour). If omitted, the default timeout value of 60 secs is used. |

* CORS prevents third-party websites from including linked data (API calls, images, etc.) from your own websites. This is implemented by the browser to prevent theft of your IP or properties. Sometimes, it is desirable to allow specific (or all, or no) third-party websites to access data from your sites, for example when adding the RainViewer API to VRS.
Note - for VRS, if you are instructed to add CORS exceptions to your VRS Admin, please add those also to the `CORSHOSTS` parameter of the webproxy container.

You may have to adjust your `port:` and your `volumes:` mapping to your liking, especially if you are not running on the Raspberry Pi standard `pi` account.

### Configuration of the Webproxy

If `AUTOGENERATE=ON`, the system will build a Webproxy based on the `REVPROXY` and `REDIRECT` parameter values.

`REVPROXY` defines the proxy-pairs to serve the `destination` target when the user browses to `urltarget`. The user's browser will never be redirected to an internal IP address for service, all web pages are being served from the Webproxy. As such, the process of going to the correct website/port to get the web page is completely hidden from the user.

`REVPROXY` has the following format: `urltarget|destination[|user1|pass1[|user2|pass2[|...|...]]]`
For example, for REVPROXY=readsb|<http://10.0.0.191:8080>, a user browsing to <http://mydomain/readsb> will be proxied to a service located at <http://10.0.0.191:8080>. The user's browser will _never_ see the internal IP address.
Note - both the `urltarget` and the `destination` must be URLs or directories, and cannot be a file name.
You can provide a comma separated list of `urltarget|destination` pairs, similar to the example in the default `docker-compose.yml`.
The optional `|user1|pass1|user2|pass2|...|...` addons define the allowed username/password combination for this specific revproxy.

`REDIRECT` redirects the user's browser to a specific address. In contrast to `REVPROXY`, the Webproxy does NOT "front" the rendering of the website. This can be useful if there is information that you want to be available within your own subnet, but not to the outside world.
The format for `REDIRECT` is similar to that of `REVPROXY`: `urltarget|redirection`
For example, for `REDIRECT=/planefinder/setup.html|http://10.0.0.191:8086/setup.html`
Note - for `REDIRECT`, both the urltarget and the redirection MAY BE a URL or a file names.
Similar to `REVPROXY`, `REDIRECT` can contain comma separated entries. See example in the default `docker-compose.yml`.

### Configuration of SSL

SSL can only be enabled if you have a domain name (a real one or a Dynamic DNS name) that currently points at your WebProxy instance. This means that your WebProxy must be accessible from the internet (forward of port 80 and port 443 required if behind a router).

The following settings will enable SSL to be part of the reverse proxy.
SSL certificates are provided by Lets Encrypt.

A "_" means that this is the default value
| Parameter | Values | Description |
|-----------|--------|-------------|
| `SSL` | `DISABLED`_, `ENABLED` | Enable the installation of SSL certificates |
| `SSL_EMAIL` | your email address | A valid email address is needed to get a certificate |
| `SSL_DOMAIN` | A list of web domains | We will enabled SSL for these. Note - they must be reachable domains at this container for the SSL certificate to be successfully installed! |
| `SSL_TOS` | `REJECT`_, `ACCEPT` | Indicates your acceptance of the T&S's for the SSL certificateset forth at <https://letsencrypt.org/repository/#let-s-encrypt-subscriber-agreement> |
| `SSL_REDIRECT` | `DISABLED`, `ENABLED` | When set to ENABLED, all incoming non-SSL traffic is redirected to use SSL |

Note: your SSL certificates are valid for 90 days. The container will check daily if they need renewing, and will do so of there's less than a month before the expiration date.
**LetsEncrypt will start sending you emails about the pending expiration about 45 days before the deadline. Sometimes, the expiration date in this email doesn't correspond to the real expiration date of the certificates. You can safely ignore these emails as long as your container is running.**
If you want to check the official expiration date of your certificates, this command will show you:

```bash
docker exec -it webproxy certbot certificates
```

### GeoIP Filtering

The Reverse Webproxy can filter incoming requests by originating IP. It uses an external GeoIP database that maps IP addresses to countries. This database is updated regularly with the latest mappings. Note - this GeoIP IP to Location mapping is not perfect, and users with a VPN can circumvent GeoIP filtering without much problems.

| Parameter            | Values                           | Description                                                                                                                                                                                                                                                                                                                  |
| -------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GEOIP_DEFAULT`      | \<empty\>\*, `ALLOW`, `BLOCK` | Empty: GeoIP filtering is disabled; `ALLOW`: ***allow** all* except for the listed countries in `GEOIP_COUNTRIES`, which are blocked; `BLOCK`: ***block** all* except for the listed countries in `GEOIP_COUNTRIES`, which are allowed.                                                                                                                               |
| `GEOIP_COUNTRIES`    |                                  | Comma-separated list of 2-letter country abbreviations, for example `RU,CN,BY,RS` (which means Russia, China, Bielorus, Serbia).                                                                                                                                                                                             |
| `GEOIP_RESPONSECODE` | 3-digit HTTP response code       | Default if omitted: `403` ("Forbidden"). Other codes that may be useful: `402` (payment required), `404` (doesn't exist), `418` (I am a teapot - used to tell requesters to go away), `410` (Gone), `500` (Internal Server Error), `503` (service unavailable). See <https://developer.mozilla.org/en-US/docs/Web/HTTP/Status> |

### BlockBot Filtering

The BlockBot feature filters out HTTP requests based on a fuzzy match of the HTTP User Agent field against a list of potential matches. This can be used to somewhat effectively filter out bots that are trying to scrape your website. The `BLOCKBOT` parameter included `docker-compose.yml` file has an example of a bot filter.

| Parameter               | Values                               | Description                                                                                                                                                                                                                                                                                                                  |
| ----------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BLOCKBOT`              | string snippets of User Agent fields | Comma-separated strings, for example `google,bing,yandex,msnbot`. If the element is a URL (starting with `http`), it will try to download a list from that URL. You can mix UA snippets and URLs to your liking. If this parameter is empty, the BlockBot functionality is disabled. |
| `BLOCKBOT_RESPONSECODE` | 3-digit HTTP response code           | Default if omitted: `403` ("Forbidden"). Other codes that may be useful: `402` (payment required), `404` (doesn't exist), `418` (I am a teapot - used to tell requesters to go away), `410` (Gone), `500` (Internal Server Error), `503` (service unavailable). See <https://developer.mozilla.org/en-US/docs/Web/HTTP/Status> |
| `BLOCKBOT_UPDATETIME` | Time (in secs) | Time (in secs) between checks to see if (URL-based) remote lists of `BLOCKBOT` user agent snippets have been updated. Default value is `21600` (secs = 6 hours) |

### `iptables` blocking

As an option, the system can use `iptables` to block any IP match of GeoIp or BlockBot. If a request comes from an ip address that is blocked via `iptables`, the server will simply not respond at all to the request - as if the tcp/ip address simply wasn't available. This decreases the load on the system, and mostly slows down or prevents DDOS attacks.

The system will scan the logs for any BlockBot or GeoIP filtered request, and adds any IP address for which a return value of `$BLOCKBOT_RESPONSECODE` or `$GEOIP_RESPONSECODE` to the `iptables` blocked list, unless the IP is part of a value or range specified in the `ip-allowlist` (see below). The `iptables` blocker is updated in batches every 60 seconds.
To enable this behavior, set `IPTABLES_BLOCK` to `ENABLED` or `ON`. You can also specify the time an IP address should stay on the `iptables` block list with the `IPTABLES_JAILTIME` parameter. Additionally, you must add the `NET_ADMIN` capacity to the container; see the [`docker-compose.yml`](docker-compose.yml) for an example.

```yaml
     cap_add:
       - NET_ADMIN
```

Note that it will block all IP address that received a response code of `GEOIP_RESPONSECODE` or `BLOCKBOT_RESPONSECODE`. If you are concerned that this may include occasional IP addresses that incidentally received any of this response codes but were not GeoIP or Bot restricted, then either use unique response codes for GeoIP/Bots or don't enable this feature.

As long as the `/run/nginx` volume is mapped (see example in [`docker-compose.yml'](docker-compose.yml)), the blocked IP list is persistent across restarts and recreation of the container.

If you want to remove IP addresses from the blocked list, you can do so manually by removing them with a text editor from the file `ip-blocklist` in the mapped volume. Alternatively, you can use a simple utility to do this while running the container:

```bash
docker exec -it webproxy manage_ipblock
```

Note that the `IPTABLES_BLOCK` feature enables logging to disk (specifically, `/var/log/nginx/access.log`). You may want to map this directory to a `tmpfs` volume \(see example in [`docker-compose.yml`](docker-compose.yml)\). Log rotation keeps 24 files of 1 hour each around; the 1 hour log rotation intervals and number of retained backups are configurable with the`LOGROTATE_INTERVAL` and `LOGROTATE_MAXBACKUPS` docker environment variable.

| Parameter              | Values                                            | Description                                                                                                                                                                                                 |
| ---------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `IPTABLES_BLOCK`       | `ON`/`ENABLED` or `OFF`/`DISABLED`/blank          | If enabled, any IP address match to `GEOIP_RESPONSECODE` or `BLOCKBOT_RESPONSECODE` will be blocked using `iptables`. If disabled or omitted, `iptables` blocking won't be used                            |
| `IPTABLES_BLOCK_NO_USERAGENT` | `ON`/`ENABLED` or `OFF`/`DISABLED`/blank | If enabled, requests from IP addresses that don't contain a User Agent will be blocked |
| `IPTABLES_JAILTIME`    | time in seconds; `0` (default) means forever      | The time that an IP Address will remain blocked. If omitted or set to `0`, blocked IP addresses will be blocked in perpetuity, or at least until the IP address is manually removed from the IP Block List |
| `LOGROTATE_INTERVAL`   | time in seconds; default value `3600`             | The time between each run of of log rotation for `/var/log/nginx/access.log` and `/var/log/nginx/error.lo`g                                                                                                 |
| `LOGROTATE_MAXBACKUPS` | integer between `0` and `100`; default value `24` | The number of backup files for `/var/log/nginx/access.log` and `/var/log/nginx/error.log`                                                                                                                   |

### Basic Authentication

The container supports a "basic" implementation of Basic Authentication. This is not inherently super-secure, and it exposes the usernames/passwords in clear text to the host system. We are planning to make this more secure in the future, but for now, please use with caution.

The container supports basic authentication for the local web page through the `LOCAL_CREDS` variable, as well as credentials for each of the `REVPROXY`d entries via the `REVPROXY` variable.

| Parameter     | Values                | Description |
| ------------- | --------------------- | -------------- |
| `AUTH`        | `on`/`1`/`enabled`/`true` or anything else | If set to `on`, Basic Authentication is enabled. If set to anything else or omitted, Basic Authentication is disabled. |
| `LOCAL_CREDS` |                       | A list of credentials in the format `username1\|password1,username2\|password2,...` |
| `LOCAL_CREDS_ALL_REVPROXIES` | `on`/`1`/`enabled`/`true` or anything else | If set to `on`, the local creds will also be assigned to all of the reverse proxy addresses defined with the `REVPROXY` parameter. Note - if the same username is defined for a `REVPROXY` parameter as for `LOCAL_CREDS`, only the password in `REVPROXY` will be used.|
| `REVPROXY`    |                       | A comma separated list in this format:                                                                                 |

```yaml
REVPROXY=origin1|http://destination1|username1|password1|username2|password2,
         origin2|http://destination2|username3|password3|username4|password4|username5|password5,
         origin3|http://destination3,
         ...
```

### Advanced Setup

After you run the container the first time, it will create a directory named `~/.webproxy`. If `AUTOGENERATE=ON`, there will be a `locations.conf` file. There will also be a `locations.conf.example` file that contains setup examples. If you know how to write a `nginx` configuration file, feel free to edit the `locations.conf` and add any options to your liking.

BEFORE restarting the container (important!!) edit `docker-compose.yml` and set `AUTOGENERATE=OFF`. If you don't do this, your newly created `locations.conf` file will be overwritten by the auto-generated one based on the `REVPROXY` and `REDIRECT` settings. (There will be a time-stamped backup file of your `locations.conf` file, so not everything is lost!)

In some systems where IPV6 is disabled or not available, you may have to add this environment parameter: `IPV6=DISABLED`.

### Host your own web pages

You can place HTML and other web files in `~/.webproxy/html`. An example `index.html` is already provided, and can be reached by browsing to the root URL of your system.
At this time, features like `php` are not enabled. If you are interested in this, please file a feature request at [issues](https://github.com/sdr-enthusiasts/docker-reversewebproxy/issues).
Note -- the web server inside the container does NOT run as `root`, so you must make sure that there are read permissions for "all" (`chmod a+r`) for any files you place in the `html` directory.
Feel free to create additional subdirectories if needed for your project.
Also note -- the website may not be reachable if you redirected or proxied `/` to some other service.

#### Access Report Page using `goaccess`

The container can create a publicly available Access Report, controlled by the following parameter:
| Parameter     | Values                | Description |
| ------------- | --------------------- | -------------- |
| `ACCESS_REPORT_PAGE` | `on`/`1`/`true`/`yes`<br/>`off`/`0`/`false`/`no`/<blank><br/>`pagename.html` | If set to `on` or an equivalent value, an Access Report will be generated at `http(s)://myservername/access-report.html`. If set to a page name, an Access Report will be generated at `http(s)://myservername/pagename.html`. If set to `off` or an equivalent value (or if left empty (default)), then no Access Reports will be generated. |
| `ACCESS_REPORT_FREQUENCY` | `300` (secs, default) | Value, in seconds, of refresh frequency of the Access Report. To reduce CPU effort and Disk IO, it's recommended not to set this to less than 60 secs |
| `ACCESS_REPORT_RESOLVE` | `on`/`1`/`true`/`yes`/<blank><br/>`off`/`0`/`false`/`no` | If left blank (default) or set to `on` or an equivalent value, the Access Report will attempt to resolve any external IP addresses to a domain name. If set to `off` or an equivalent value, the Access Report will not try to resolve any IP addresses. If you have a busy webserver and run on a machine that is either not too fast, or has a slow DNS resolver, you may see that your Access Report page refreshes very slowly or not at all. In this case, please set this parameter to `off` |

This access report is created using a tool called [GoAccess](https://goaccess.io/)

#### Automatic creation of web pages with geographic map of visitors

If you set `IPMAPS=true`, the container will try to automatically create IP maps of the visitors to your website. This includes any visit that goes to a URL that is handled by the WebProxy, regardless if it's rendering a local page, being sent to a reverse proxy address, or being redirected somewhere else. The website will automatically generate the following pages that are updated every 15 minutes. You can change the defaults by defining the parameters below.

The system uses <http://iponfo.io/tools/map> to create these maps from the webserver's access logs.

If `IPMAPS` is not enabled, the pages will not exist. Any previously generated map redirects will be deleted.

| URL | Map Type |
| --- | -------- |
| `/ipmap-all.html` | Redirection to a map with **all** visitors |
| `/ipmap-filtered.html` | Redirection to a map with only visitors who were denied access due to Geo-IP block or BotBlock |
| `/ipmap-accepted.html` | Redirection to a map with only those visitors that passed the filtering and that were allowed to browse to the resource they tried to access |

The following related parameters can be set:

| Parameter | Values | Description |
| --------- | ------ | ---------------- |
| `IPMAPS`        | `on`/`enabled`/`true`/`1` or <br/>`off`/`disabled`/`false`/`0`<br/>or empty | If enabled, IPMAPS will be generated as described above. If disabled or empty (default), maps aren't generated |
| `IPMAPS_INTERVAL`        | value in secs or empty | Interval of generation of the IP Maps. Default if omitted is `900` seconds |
| `IPMAPS_BASENAME` | partial file name | Base file name of the map URL. Default value is `ipmap-`, which would correspond to `http://ip_addr/ipmap-all.html` / `http://ip_addr/ipmap-filtered.html` / `http://ip_addr/ipmap-allowed.html` |

### Extras

- Get a URL to a geographic map of all IPs that hit your WebProxy by typing:
  
  ```bash
  docker exec -it webproxy ipmap
  ```

(Prerequisites: either of these parameters must be set: `IPTABLES_BLOCK=ENABLED` (recommended) or `VERBOSELOG=file` (works but not recommended)

## Troubleshooting

- Issue: the container log (`docker logs webproxy`) shows error messages like this: `sleep: cannot read realtime clock: Operation not permitted`
  - Solution: you must upgrade `libseccomp2` on your host system to version 2.4 or later. If you are using a Raspberry Pi with Buster based OS, [here](https://github.com/fredclausen/Buster-Docker-Fixes) is a repo with a script that can automatically fix this for you
- Issue: `docker-compose up -d` exits with an error
  - Solution: you probably have a typo in `docker-compose.yml`. Make sure that all lines are at the exact indentation level, and that the last entry in the `REVPROXY` and `REDIRECT` lists do not end on a comma
- Issue: The container complaints about port mappings during start-up
  - Solution: you probably are already running another service on the same port on your host machine. The port exposed to the world is the first `80` in `- PORTS: 80:80` in `docker-compose.yml`. You can do one of two things: scour your system for other web services on that port (another container? `lighttpd`? `nginx`?) and disable that service (or put it on another port), or change the first `80` to some other port number. For `docker` containers, you can check the ports that are used by each container with this command: `docker ps`
- Issue: Everything starts up fine, but the website doesn't render any pages
  - Solution: Please take a look at the container log (`docker logs webproxy`) to see if there are any errors. The log will be explicit about some of the more obvious issues
- Issue: I have troubles getting the Webproxy to work with VRS (Virtual Radar Server)
  - Solution: in VRS, make sure to configure this: VRS Options -> Website -> Website Customisation -> Proxy Type = Reverse
- Issue: Planefinder doesn't work correctly
  - Solution: make sure that you have added the following to the `REVPROXY` variable (replace ip address and port with whatever is appropriate for your system):

    ```yaml
    planefinder|http://10.0.0.191:8086,
    ajax|http://10.0.0.191:8086/ajax,
    assets|http://10.0.0.191:8086/assets,
    ```

- Issue: The docker logs show an error like this on start up:

  ```text
  nginx: [emerg] socket() [::]:80 failed (97: Address family not supported)
  nginx: configuration file /etc/nginx/nginx.conf test failed
  ```

  - Solution: Your system doesn't support IPV6 while the container expects this. Solve it by adding this parameter to your `docker-compose.yml`: `IPV6=DISABLED`
- Issue: with `IPTABLES_BLOCK` switched on, it looks like the webproxy is trying to block large lists of ip addresses, even though none (or few) of these addresses have hit the system in the last 60 seconds
  - Solution: You probably didn't add the `NET_ADMIN` capacity to the container. You need to do this in your `docker-compose.yml` file and then recreate the container. See above and see [`docker-compose.yml`](docker-compose.yml) for an example.
- Issue: I'm getting emails from `letsencrypt.com` about the pending expiration of my SSL certificates
  - Solution: ignore them. As long as the container is running and SSL is enabled, the certificates are checked daily for pending expiration and will be renewed 1 month before that date. Sometimes, letsencrypt.com gets confused about the expiration dates and thinks it's earlier than is really the case. You can always check this for yourself by looking at the container logs, or by running this command: `docker exec -it certbot certificates`
- Issue: when adding new URLs to a system that deployment has SSL certifications, the logs show messages that requesting a certificate for the new URL failed because the user should indicate which of (multiple) accounts should be used.
  - Solution: This is caused by certificates that have been added to `webproxy` at different points in time. To fix it, back up any web pages that are directly served by the container, and recreate the entire setup. Please note that doing this more than 5 times in a week will lock you out and prevent you from recreating existing certificates for up to a week, so USE THIS SOLUTION SPARINGLY. The solution assumes that the container name is `webproxy` and that its mapped working volume is `/opt/webproxy/webproxy` . If this is different, you may have to adapt the commands accordingly. It's preferable to feed the script line by line rather than all at once, so you can monitor the outcome.

    ```bash
    cd /top/webproxy  # go to the home directory
    docker stop webproxy    # stop the webproxy container
    
    # Back up the web pages and any custom configuration. Sudo is used to ensure also closed directories are backed up
    # Only of the backup is successful, delete the working directory
    sudo tar zcvf web-backup.tgz webproxy/html webproxy/locations.conf && sudo rm -rf webproxy
    
    # Recreate the webproxy. Adapt the location of your "docker-compose.yml" as needed
    docker compose up -d --force-recreate webproxy
    
    # Check in the logs that the issue is fixed:
    sleep 30 && docker logs webproxy
    
    # Restore the files and restart the container once more to ensure the locations.conf file is applied
    sudo tar zxvf web-backup.tgz
    docker restart webproxy
    
    # You can now remove the "web-backup.tgz" file, or save it as a backup of your website.
    ```

## Acknowledgements

- @Mikenye for encouraging me to look into Docker, and to suggest we need a Reverse Web Proxy to solve our web service issues. He also wrote the Github Actions scripts and taught me how to work with the `s6` service layer.
- @Wiedehopf for helping me get my initial installation of nginx configured and working. Without his help, everything would have taken many weeks (!) instead of a few hours.

## License

The software packages and OS layers included in this project are used with permission under license terms that are distributed with these packages.

The combination of these packages and any additional software written to combine and configure the Webproxy are Copyright 2021-2024 by Ramon F. Kolb (kx1t), and licensed under the GNU General Public License, version 3 or later. If you desire to use this software with a different license, please contact the author.

Summary of License Terms
This program is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.
If not, see <https://www.gnu.org/licenses/>.
