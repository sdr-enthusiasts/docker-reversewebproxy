# Copilot instructions

## Build, test, and lint

This repository builds a Docker image; it does not contain an application-language
unit-test suite.

- Enter the development environment with `nix develop`.
- Run the same lint checks as CI with `nix develop -c pre-commit run --all-files`.
- Run a single pre-commit hook against selected files with
  `nix develop -c pre-commit run <hook-id> --files path/to/file`.
- Validate the Compose file with `docker compose config`.
- Build a local image with `docker build --tag docker-reversewebproxy:test .`.
  The image startup sequence includes `99-test-webproxy`, which runs
  `nginx -t` after generated configuration has been installed.
- Run the flake checks with `nix flake check` when validating the Nix configuration.

The GitHub Actions lint job runs `nix develop -c pre-commit run --all-files`.
The test-build workflow builds `Dockerfile` through the shared
`sdr-enthusiasts/common-github-workflows` workflow. `buildnow.sh` is a
maintainer release helper: it checks out and pulls a branch, then pushes a
multi-architecture image, so do not use it for an ordinary local build.

## Architecture

- `Dockerfile` starts from the shared `docker-baseimage:base`, installs Nginx,
  Certbot, GeoIP, GoAccess, iptables, and supporting tools, then copies `rootfs/`
  into the image. Most product behavior is therefore implemented in the image
  filesystem rather than in a conventional application source tree.
- Nginx configuration lives under `rootfs/etc/nginx/`; default server templates
  include generated files from `/run/nginx`. Files under `rootfs/root/` are
  startup templates and helper utilities copied into the runtime filesystem.
- s6-overlay setup services are defined under
  `rootfs/etc/s6-overlay/s6-rc.d/` and delegate to scripts in
  `rootfs/etc/s6-overlay/scripts/`. The numbered setup stages establish the
  configuration in dependency order: SSL, the base webproxy configuration,
  bot filtering, GeoIP, IPv6 handling, iptables blocking, authentication, CORS,
  and finally the Nginx configuration test.
- `20-webproxy` is the central configuration generator. With
  `AUTOGENERATE=ON`, it parses the comma-separated `REVPROXY`, `SUBDOMAINS`,
  and `REDIRECT` values and writes Nginx snippets under `/run/nginx`; with
  `AUTOGENERATE=OFF`, a user-provided `locations.conf` must already exist.
  It also adjusts logging and proxy timeouts and injects subdomain routing into
  the server template.
- Later setup scripts mutate the generated Nginx configuration for SSL,
  GeoIP, BlockBot, authentication, CORS, and IPv6. The long-running services
  update remote bot lists, rotate logs, generate IP maps, and maintain the
  iptables block list.
- `/run/nginx` is the persistent working volume shown in `docker-compose.yml`.
  It contains user configuration, generated HTML/configuration, certificates,
  GeoIP cache data, and IP allow/block lists. Be careful not to overwrite these
  files during startup; the generator intentionally keeps timestamped
  `locations.conf` backups.
- `source-stubs/scripts/common` is only a lint-time stub for helpers supplied by
  the base image. It is excluded by `.dockerignore` and must not be treated as
  runtime code.

## Repository conventions

- Runtime scripts use Bash with the s6-overlay shebang
  `#!/command/with-contenv bash`, source `/scripts/common`, and log through the
  shared `s6wrap` command. Use the base-image helpers such as `chk_enabled`
  rather than reimplementing flag parsing.
- Environment flags are intentionally permissive and generally accept
  case-insensitive forms such as `ON`/`ENABLED`/`TRUE`; preserve that behavior
  when adding settings. User-facing syntax and defaults belong in `README.md`
  and `docker-compose.yml`.
- Generated Nginx files are rewritten at container startup. Keep generation
  idempotent, preserve the existing marker/placeholder approach, and make
  changes in the generator and its corresponding Nginx template together.
- The `REVPROXY`, `SUBDOMAINS`, and `REDIRECT` formats use commas as entry
  separators and pipes as field separators. Credentials are embedded in those
  values, so parsing must preserve destinations and credentials exactly and
  continue stripping only the whitespace the existing scripts strip.
- Nginx must be validated only after all setup mutations have run; the
  `99-test-webproxy` stage is the final gate and exits with status 78 on an
  invalid configuration.
- Keep s6 dependency files, service wrappers, and implementation scripts
  synchronized when adding or renaming a service. Numbered setup services are
  one-shot initialization; unnumbered services generally run continuously.
- GitHub Actions and Nix inputs are pinned to specific revisions. Follow that
  pattern when updating workflow actions or flake dependencies.
- Preserve the repository's existing shellcheck directives and formatting
  conventions. The Nix flake supplies Docker checks plus Markdown, spelling,
  JSON, and Nix formatting tools through the development shell.

For user-visible configuration behavior, consult the matching README section
before changing scripts; the README documents the supported environment
variables, persistence expectations, and operational troubleshooting.
