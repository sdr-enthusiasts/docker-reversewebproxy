# Docker-ReverseWebProxy

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
This is less than 5 minutes of work -- follow the instructions at [this GitBook](https://mikenye.gitbook.io/ads-b/setting-up-the-host-system/install-docker); you need to do all 3 steps of the "Setting up the Host System" section.

Once this is done, create a working directory and download the `docker-compose.yml` file:
```
mkdir ~/myproxy && cd ~/myproxy
wget https://raw.githubusercontent.com/kx1t/docker-reversewebproxy/main/docker-compose.yml
```
You should EDIT this `docker-compose.yml` file and configure it to your liking. See below for options.
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
| `VERBOSELOG` | `ON`*, `OFF` | Determines if the internal web service Access and Error logs will be written to the Docker log (accessible with `docker logs -f webproxy`) (`ON`), or that logging will be switched `OFF`.

You may have to adjust your `port:` and your `volumes:` mapping to your liking, especially if you are not running on the Raspberry Pi standard `pi` account.

### Configuration of the Webproxy
If `AUTOGENERATE=ON`, the system will build a Webproxy based on th `REVPROXY` and `REDIRECT` parameter values.

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

### Advanced Setup
After you run the container the first time, it will create a directory named `~/webproxy`. If `AUTOGENERATE=ON`, there will be a `locations.conf` file. There will also be a `locations.conf.example` file that contains setup examples. If you know how to write a `nginx` configuration file, feel free to edit the `locations.conf` and add any options to your liking.

BEFORE restarting the container (important!!) edit `docker-compose.yml` and set `AUTOGENERATE=OFF`. If you don't do this, your newly created `locations.conf` file will be overwritten by the auto-generated one based on the `REVPROXY` and `REDIRECT` settings. (There will be a time-stamped backup file of your `locations.conf` file, so not everything is lost!)

### Host your own web pages
You can place HTML and other web files in `~/.webproxy/html`. An example `index.html` is already provided, and can be reached by browsing to the root URL of your system.
At this time, features like `php` are not enabled. If you are interested in this, please file a feature request at [issues](https://github.com/kx1t/docker-reversewebproxy/issues).
Note -- the web server inside the container does NOT run as `root`, so you must make sure that there are read permissions for "all" (`chmod a+r`) for any files you place in the `html` directory.
Feel free to create additional subdirectories if needed for your project.
Also note -- the website may not be reachable if you redirected or proxied `/` to some other service.

## Troubleshooting

- Issue: `docker-compose up -d` exits with an error
- Solution: you probably have a typo on `docker-compose.yml`. Make sure that all lines are at the exact indentation level, and that the last entry in the `REVPROXY` and `REDIRECT` lists do not end on a comma.

- Issue: The container complaints about port mappings during start-up
- Solution: you probably are already running another service on the same port on your host machine. The port exposed to the world is the first `80` in `- PORTS: 80:80` in `docker-compose.yml`. You can do one of two things: scour your system for other web services on that port (another container? `lighttpd`? `nginx`?) and disable that service (or put it on another port), or change the first `80` to some other port number.

- Issue: Everything starts up fine, but the website doesn't render any pages
- Solution: Please take a look at the container log (`docker logs webproxy`) to see if there are any errors. The log will be explicit about some of the more obvious issues.

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
