# FacturaScripts implementation notes

This standalone repository provides an experimental FacturaScripts LXC installer for testing. It is unofficial, is not production-ready, and is not maintained by community-scripts, FacturaScripts, or Proxmox Server Solutions GmbH.

## Implementation decisions

| Topic | Decision |
|---|---|
| Release | Install the official stable ZIP from `https://facturascripts.com/DownloadBuild/1/stable` with `fetch_and_deploy_from_url`. The endpoint is mutable and this project does not claim or pin a payload version. |
| Runtime | PHP 8.4 under Apache 2.4 using `PHP_VERSION="8.4" PHP_APACHE="YES" setup_php`. |
| PHP extensions | Verify the upstream-required bcmath, curl, fileinfo, gd, mbstring, openssl, SimpleXML and zip modules after the shared helper installs PHP. |
| Database | Install MariaDB from the Debian distribution and fail if the installed version is below the upstream 11.2 minimum. The shared helper provisions the `facturascripts` database and user. |
| Initial setup | Leave account and schema initialization to the official web assistant. The script only shows generated database credentials; users must follow the current assistant and replace any default credentials immediately. |
| Web server | Use a dedicated Apache virtual host, enable `mod_rewrite`, rename `htaccess-sample` to `.htaccess`, allow overrides, disable directory indexes and grant no world-write permissions. |
| Permissions and updates | Temporarily set the application root to `root:www-data` mode `770` so the web assistant can create `config.php`, then require the operator to run `/usr/local/sbin/facturascripts-harden-permissions`. The command restores root mode `750` and leaves only existing `Plugins`, `MyFiles` and `Dinamic` directories writable by Apache. This may block the built-in updater; the CT update command also refuses external replacement because it could bypass migrations. |
| Architecture | Leave `var_arm64` unset. The PHP source archive is architecture-neutral, but this installer has not been run on ARM64. |

## Source resolution

The public entry point is:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Habier/facturascripts-community-script/main/ct/facturascripts.sh)"
```

The CT script sets `_CS_DEFAULT_URL` to `https://raw.githubusercontent.com/Habier/facturascripts-community-script/main`, so the official engine resolves `install/facturascripts-install.sh` from this repository without a required environment variable. The engine itself still loads from `https://raw.githubusercontent.com/community-scripts/core/main` unless explicitly overridden. Core is not copied into this repository.

## Upstream requirements and sources

- Product and downloads: <https://facturascripts.com/>
- Installation documentation: <https://facturascripts.com/publicaciones/instalacion-de-facturascripts-2020-635>
- Source repository: <https://github.com/NeoRazorX/facturascripts>
- Stable download: <https://facturascripts.com/DownloadBuild/1/stable>
- Required stack: PHP 8.1 or newer, Apache 2.4 with `mod_rewrite`, `.htaccess` and `AllowOverride All`, and MySQL 8 or MariaDB 11.2 or newer.
- No authoritative checksum or immutable identifier was found for the stable download endpoint; immutable pinning remains a pre-production limitation.

## Files and persistence

| Path or resource | Purpose | Backup requirement |
|---|---|---|
| MariaDB database `facturascripts` | Business and application data | Required |
| `/opt/facturascripts/config.php` | Database and application configuration | Required |
| `/opt/facturascripts/Plugins` | Installed plugins | Required |
| `/opt/facturascripts/MyFiles` | User-managed files | Required |
| `/opt/facturascripts/Dinamic` | Writable runtime files | Include until restore behavior is verified |

Prefer a full Proxmox container backup before every application update. A file-only archive is insufficient because the primary data is in MariaDB.

## Required post-setup permission hardening

The installer cannot harden the application root automatically because the web assistant must first create `/opt/facturascripts/config.php`. Until the following procedure is completed, Apache can rename, delete, or replace entries directly under `/opt/facturascripts`.

1. Complete the web assistant on the trusted network.
2. Enter the container as `root`.
3. Run:

   ```bash
   /usr/local/sbin/facturascripts-harden-permissions
   ```

4. Verify the root is no longer writable by Apache:

   ```bash
   stat -c '%U:%G %a %n' /opt/facturascripts
   # Expected: root:www-data 750 /opt/facturascripts
   ```

The command first requires `config.php`, resets the tree to root ownership with directories mode `750` and files mode `640`, then grants write access back only to existing `Plugins`, `MyFiles`, and `Dinamic` directories. It does not run automatically and the deployment remains incomplete from a security perspective until the operator runs it.

## Standalone repository workflow

1. Make changes in this repository without copying Community Scripts core.
2. Run the local static validation commands below.
3. Test the exact raw `main` one-liner on a disposable Proxmox VE host after pushing.
4. Complete the manual checklist and record exact versions and outcomes.
5. Keep `main` usable because the published one-liner and installer source both target it.

## Manual Proxmox checklist

- [ ] Run the documented one-line command on a Proxmox VE host.
- [ ] Confirm it creates an unprivileged Debian 13 container with 2 CPU cores, 2048 MiB RAM and 20 GB disk.
- [ ] Confirm the installer completes without Docker or a privileged container.
- [ ] Confirm Apache serves `http://<container-ip>` and opens the official setup assistant.
- [ ] Confirm `rewrite_module` is enabled and the dedicated `facturascripts` site is active.
- [ ] Confirm PHP reports version 8.4 and the installer verifies every required extension.
- [ ] Confirm the installer verifies MariaDB 11.2 or newer.
- [ ] Complete the web assistant with host `localhost` and the generated database credentials.
- [ ] Run `/usr/local/sbin/facturascripts-harden-permissions` and confirm `/opt/facturascripts` is `root:www-data` mode `750`.
- [ ] Replace any default administrator credentials and verify login.
- [ ] Create a test company, customer and invoice, then verify the data survives a reboot.
- [ ] Verify `Plugins`, `MyFiles` and `config.php` survive a backup and restore.
- [ ] Clone or back up the container, determine the minimum temporary permissions needed by the built-in updater, restore hardened permissions, and verify migrations and login.
- [ ] Test on ARM64 before setting `var_arm64=yes` or adding `arm64` to JSON metadata.

No item above is claimed as executed on a real Proxmox host.

## Local validation

```bash
bash -n ct/facturascripts.sh install/facturascripts-install.sh
shellcheck ct/facturascripts.sh install/facturascripts-install.sh
jq empty json/facturascripts.json
git diff --check --no-index /dev/null <file>
```

## Known limits and risks

- The stable URL is mutable and does not provide an official checksum, version API or machine-readable release metadata.
- Installation trusts TLS and the official download host but cannot independently pin or verify the payload.
- The application is served over HTTP only. Keep it on a trusted network or place it behind a separately managed TLS reverse proxy.
- Root-owned core files may block the built-in updater. Updates are intentionally not automated and no safe temporary-permission procedure is claimed before real testing.
- The first-run assistant remains available until setup is completed. Complete it immediately on a trusted network.
- The scripts have only local static validation until the manual Proxmox checklist is executed.
- ARM64 support remains unverified.
