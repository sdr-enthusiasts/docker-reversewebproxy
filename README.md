# Docker-ReverseWebProxy

## ATTENTION Raspberry Pi 3 / Buster users
This application has recently been updated to use a base image container based on Debian Bullseye.
Some older, Buster based host systems may need a patch to solve an issue related to the Real Time Clock or container log errors regarding `sleep`. See the Troubleshooting section below.

## What is it?

This application, further referred to as "Webproxy", enables to show a single website for multiple web services running on different machines and/or different ports.

The need for a solution is age-old, but what triggered the creation of this project was the deployment of Dockerized web services for a ADSB Feeder station. These web services are distributed over 1 or more Raspberry Pi's, and each of them provides a web interface on a different TCP port. As a result, the user has to remember a collection of seemingly random IP addresses and port numbers to get to these web services, which creates an awful user experience.

The Webproxy allows the user to map these web services to a single URL, differentiating them by assigning a virtual directory name for each.

The following example highlights this:

| Web Service | Original address              | New Address with Webproxy |
|-------------|-------------------------------|---------------------------|
| readsb      | http://10.0.0.191:8080        | http://myip/readsb        |
| piaware     | http://10.0.0.191:8081        | http://myip/piaware       |
| tar1090     | http://10.0.0.191:8082        | http://myip/tar1090       |
| planefence  | http://10.0.0.191:8083        | http://myip/planefence    |
| planefinder | http://10.0.0.191:8086        | http://myip/planefinder   |
| graphs      | http://10.0.0.191:8080/graphs | http://myip/graphs        |
| radar       | http://10.0.0.191:8080/radar  | http://myip/radar         |
| acarshub    | http://10.0.0.188             | http://myip/acarshub      |

## How do I get it?

Prerequisite for this to work, is that you have a working `Docker` and `Docker-compose` setup.
This is less than 5 minutes of work -- use [this script](https://github.com/sdr-enthusiasts/docker-install) or follow all 3 steps of the "Setting up the Host System" section at [this GitBook](https://sdr-enthusiasts.gitbook.io/ads-b/setting-up-the-host-system/install-docker).

Once this is done, create a working directory and download the `docker-compose.yml` file:
```
sudo mkdir -p -m 777 /opt/webproxy && cd /opt/webproxy
wget https://raw.githubusercontent.com/kx1t/docker-reversewebproxy/main/docker-compose.yml
```
You should EDIT the `docker-compose.yml` file included in this repository and configure it to your liking. See below for options.
(Note - CAREFUL. YML is based on indentation levels, so make sure you keep each line at the correct indent level!)

Now, you can either run it as-is, or, if you already have another `docker-compose.yml`, you can copy the data of the `services:` section to your existing `docker-compose.yml`.

With that, you are ready to run the proxy!

## How do I configure it?
The Webproxy can be entirely configured in the `docker-compose.yml`, or, optionally, you can create a more advanced setup manually. You can also start with the `docker-compose.yml` configuration and then add to this manually in the future. Here's how:

### General parameters:
A "*" means that this is the default value
| Parameter | Values | Description |
|-----------|--------|-------------|
| `AUTOGENERATE` | `ON`*, `OFF` | Determines if the system will use the `REVPROXY` and `REDIRECT` settings of the `docker-compose.yml` file (`ON`), or a manually generated `locations.conf` file (`OFF`). |
| `VERBOSELOG` | `ON`*, `OFF` | Determines if the internal web service Access and Error logs will be written to the Docker log (accessible with `docker logs webproxy`) (`ON`), or that logging will be switched `OFF`.

You may have to adjust your `port:` and your `volumes:` mapping to your liking, especially if you are not running on the Raspberry Pi standard `pi` account.

### Configuration of the Webproxy
If `AUTOGENERATE=ON`, the system will build a Webproxy based on the `REVPROXY` and `REDIRECT` parameter values.

`REVPROXY` defines the proxy-pairs to serve the `destination` target when the user browses to `urltarget`. The user's browser will never be redirected to an internal IP address for service, all web pages are being served from the Webproxy. As such, the process of going to the correct website/port to get the web page is completely hidden from the user.

`REVPROXY` has the following format: `urltarget|destination`
For example, for REVPROXY=readsb|http://10.0.0.191:8080, a user browsing to http://mydomain/readsb will be proxied to a service located at http://10.0.0.191:8080. The user's browser will *never* see the internal IP address.
Note - both the `urltarget` and the `destination` must be URLs or directories, and cannot be a file name.
You can provide a comma separated list of `urltarget|destination` pairs, similar to the example in the default `docker-compose.yml`.

`REDIRECT` redirects the user's browser to a specific address. In contrast to `REVPROXY`, the Webproxy does NOT "front" the rendering of the website. This can be useful if there is information that you want to be available within your own subnet, but not to the outside world.
The format for `REDIRECT` is similar to that of `REVPROXY`: `urltarget|redirection`
For example, for `REDIRECT=/planefinder/setup.html|http://10.0.0.191:8086/setup.html`
Note - for `REDIRECT`, both the urltarget and the redirection MAY BE a URL or a file names.
Similar to `REVPROXY`, `REDIRECT` can contain comma separated entries. See example in the default `docker-compose.yml`.

### Configuration of SSL

SSL can only be enabled if you have a domain name (a real one or a Dynamic DNS name) that currently points at your WebProxy instance. This means that your WebProxy must be accessible from the internet (forward of port 80 and port 443 required if behind a router).

The following settings will enable SSL to be part of the reverse proxy.
SSL certificates are provided by Lets Encrypt.

A "*" means that this is the default value
| Parameter | Values | Description |
|-----------|--------|-------------|
| `SSL` | `DISABLED`*, `ENABLED` | Enable the installation of SSL certificates |
| `SSL_EMAIL` | your email address | A valid email address is needed to get a certificate |
| `SSL_DOMAIN` | A list of web domains | We will enabled SSL for these. Note - they must be reachable domains at this container for the SSL certificate to be successfully installed! |
| `SSL_TOS` | `REJECT`*, `ACCEPT` | Indicates your acceptance of the T&S's for the SSL certificateset forth at https://letsencrypt.org/repository/#let-s-encrypt-subscriber-agreement |
| ` SSL_REDIRECT` | `DISABLED`, `ENABLED`* | When set to ENABLED, all incoming non-SSL traffic is redirected to use SSL


Note: your SSL certificates are valid for 90 days. The container will check daily if they need renewing, and will do so of there's less than a month before the expiration date.
**LetsEncrypt will start sending you emails about the pending expiration about 45 days before the deadline. Sometimes, the expiration date in this email doesn't correspond to the real expiration date of the certificates. You can safely ignore these emails as long as your container is running.**
If you want to check the official expiration date of your certificates, this command will show you:
```
docker exec -it webproxy certbot certificates
```

### GeoIP Filtering
The Reverse Webproxy can filter incoming requests by originating IP. It uses an external GeoIP database that maps IP addresses to countries. This database is updated regularly with the latest mappings. Note - this GeoIP IP to Location mapping is not perfect, and users with a VPN can circumvent GeoIP filtering without much problems.

| Parameter | Values | Description |
|-----------|--------|-------------|
| `GEOIP_DEFAULT` |\<empty\>*, `ALLOW`, `DISALLOW`|Empty: GeoIP filtering is disabled; `ALLOW`: only those countries listed in the `GEOIP_COUNTRIES` parameter are permitted; `DISALLOW`: the countries listed in `GEOIP_COUNTRIES` are filtered.|
| `GEOIP_COUNTRIES` | | Comma-separated list of 2-letter country abbreviations, for example `RU,CN,BY,RS` (which means Russia, China, Bielorus, Serbia).|
| `GEOIP_RESPONSECODE` | 3-digit HTTP response code | Default if omitted: `403` ("Forbidden"). Other codes that may be useful: `402` (payment required), `404` (doesnt exist), `418` (I am a teapot - used to tell requestors to go away), `410` (Gone), `500` (Internal Server Error), `503` (service unavailable). See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status |

### BlockBot Filtering
The BlockBot feature filters out HTTP requests based on a fuzzy match of the HTTP User Agent field against a list of potential matches. This can be used to somewhat effectively filter out bots that are trying to scrape your website. The `BLOCKBOT` parameter included `docker-compose.yml` file has an example of a bot filter.

| Parameter | Values | Description |
|-----------|--------|-------------|
| `BLOCKBOT` | string snippets of User Agent fields | Comma-separated strings, for example `google,bing,yandex,msnbot`. If this parameter is empty, the BlockBot functionality is disabled.
| `BLOCKBOT_RESPONSECODE` | 3-digit HTTP response code | Default if omitted: `403` ("Forbidden"). Other codes that may be useful: `402` (payment required), `404` (doesnt exist), `418` (I am a teapot - used to tell requestors to go away), `410` (Gone), `500` (Internal Server Error), `503` (service unavailable). See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status |

### `iptables` blocking
As an option, the system can use `iptables` to block any IP match of GeoIp or BlockBot. This is done in batches every 60 seconds.
To enable this behavior, set `IPTABLES_BLOCK` to `ENABLED` or `ON`. Additionally, you must add the `NET_ADMIN` capacity to the container; see the [`docker-compose.yml`](docker-compose.yml) for an example.

```
     cap_add:
       - NET_ADMIN
```

Note that it will block all IP address that received a response code of `GEOIP_RESPONSECODE` or `BLOCKBOT_RESPONSECODE`. If you are concerned that this may include occasional IP addresses that incidentally received any of this reponse codes but were not GeoIP or Bot restricted, then either use unique response codes for GeoIP/Bots or don't enable this feature.

As long as the `/run/nginx` volume is mapped (see example in [`docker-compose.yml'](docker-compose.yml)), the blocked IP list is persistent across restarts and recreation of the container.

If you want to remove IP addresses from the blocked list, you can do so manually by removing them with a text editor from the file `ip-blocklist` in the mapped volume.

| Parameter | Values | Description |
|-----------|--------|-------------|
| `IPTABLES_BLOCK` | `ON`/`ENABLED` or `OFF`/`DISABLED`/blank | If enabled, any IP address match to `GEOIP_RESPONSECODE` or `BLOCKBOT_RESPONSECODE` will be blocked using `iptables`. If disabled or omitted, `iptables` blocking won't be used.|

### Advanced Setup
After you run the container the first time, it will create a directory named `~/.webproxy`. If `AUTOGENERATE=ON`, there will be a `locations.conf` file. There will also be a `locations.conf.example` file that contains setup examples. If you know how to write a `nginx` configuration file, feel free to edit the `locations.conf` and add any options to your liking.

BEFORE restarting the container (important!!) edit `docker-compose.yml` and set `AUTOGENERATE=OFF`. If you don't do this, your newly created `locations.conf` file will be overwritten by the auto-generated one based on the `REVPROXY` and `REDIRECT` settings. (There will be a time-stamped backup file of your `locations.conf` file, so not everything is lost!)

In some systems where IPV6 is disabled or not available, you may have to add this environment parameter: `IPV6=DISABLED".

### Host your own web pages
You can place HTML and other web files in `~/.webproxy/html`. An example `index.html` is already provided, and can be reached by browsing to the root URL of your system.
At this time, features like `php` are not enabled. If you are interested in this, please file a feature request at [issues](https://github.com/kx1t/docker-reversewebproxy/issues).
Note -- the web server inside the container does NOT run as `root`, so you must make sure that there are read permissions for "all" (`chmod a+r`) for any files you place in the `html` directory.
Feel free to create additional subdirectories if needed for your project.
Also note -- the website may not be reachable if you redirected or proxied `/` to some other service.

## Troubleshooting

- Issue: the container log (`docker logs webproxy`) shows error messages like this: `sleep: cannot read realtime clock: Operation not permitted`
- Solution: you must upgrade `libseccomp2` on your host system to version 2.4 or later. If you are using a Raspberry Pi with Buster based OS, [here](https://github.com/fredclausen/Buster-Docker-Fixes) is a repo with a script that can automatically fix this for you.

- Issue: `docker-compose up -d` exits with an error
- Solution: you probably have a typo in `docker-compose.yml`. Make sure that all lines are at the exact indentation level, and that the last entry in the `REVPROXY` and `REDIRECT` lists do not end on a comma.

- Issue: The container complaints about port mappings during start-up
- Solution: you probably are already running another service on the same port on your host machine. The port exposed to the world is the first `80` in `- PORTS: 80:80` in `docker-compose.yml`. You can do one of two things: scour your system for other web services on that port (another container? `lighttpd`? `nginx`?) and disable that service (or put it on another port), or change the first `80` to some other port number. For `docker` containers, you can check the ports that are used by each container with this command: `docker ps`

- Issue: Everything starts up fine, but the website doesn't render any pages
- Solution: Please take a look at the container log (`docker logs webproxy`) to see if there are any errors. The log will be explicit about some of the more obvious issues.

- Issue: I have troubles getting the Webproxy to work with VRS (Virtual Radar Server)
- Solution: in VRS, make sure to configure this: VRS Options -> Website -> Website Customisation -> Proxy Type = Reverse

- Issue: Planefinder doesn't work correctly
- Solution: make sure that you have added the following to the `REVPROXY` variable:
   ```
   planefinder|http://10.0.0.191:8086,
   ajax|http://10.0.0.191:8086/ajax,
   assets|http://10.0.0.191:8086/assets,
   ```

- Issue: The docker logs show an error like this on start up:
```
nginx: [emerg] socket() [::]:80 failed (97: Address family not supported)
nginx: configuration file /etc/nginx/nginx.conf test failed
```
- Solution: Your system doesn't support IPV6 while the container expects this. Solve it by adding this parameter to your `docker-compose.yml`: `IPV6=DISABLED`

- Issue: I'm getting emails from `letsencrypt.com` about the pending expiration of my SSL certificates
- Solution: ignore them. As long as the container is running and SSL is enabled, the certificates are checked daily for pending expiration and will be renewed 1 month before that date. Sometimes, letsencrypt.com gets confused about the expiration dates and thinks it's earlier than is really the case. You can always check this for yourself by looking at the container logs, or by running this command: `docker exec -it certbot certificates`

- Issue: when adding new URLs to a system that deployment has SSL certifications, the logs show messages that requesting a certificate for the new URL failed because the user should indicate which of (multiple) accounts should be used.
- Solution: This is caused by certificates that have been added to `webproxy` at different points in time. To fix it, back up any web pages that are directly served by the container, and recreate the entire setup. Please note that doing this more than 5 times in a week will lock you out and prevent you from recreating existing certificates for up to a week, so USE THIS SOLUTION SPARINGLY.
The solution assumes that the container name is `webproxy` and that its working directory is `~/.webproxy` . If this is different, you may have to adapt the commands accordingly. It's preferable to feed the script line by line rather than all at once, so you can monitor the outcome.
```
cd ~  # go to the home directory
docker stop webproxy    # stop the webproxy container

# Back up the web pages and any custom configuration. Sudo is used to ensure also closed directories are backed up
# Only of the backup is successful, delete the working directory
sudo tar zcvf web-backup.tgz .webproxy/html .webproxy/locations.conf && sudo rm -rf .webproxy

# Recreate the webproxy. Adapt the location of your "docker-compose.yml" as needed
docker-compose -f /opt/webproxy/docker-compose.yml up -d

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

The combination of these packages and any additional software written to combine and configure the Webproxy are Copyright 2021 by kx1t, and licensed under the GNU General Public License, version 3 or later. If you desire to use this software with a different license, please contact the author.

Summary of License Terms
This program is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.
If not, see https://www.gnu.org/licenses/.
