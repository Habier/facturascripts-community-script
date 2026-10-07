# FacturaScripts Community Script (experimental)

> [!WARNING]
> This project is experimental and has not completed a real Proxmox installation test. It is not production-ready. Use it only in a disposable environment on a trusted network.

This unofficial Community Scripts-style project installs FacturaScripts in an unprivileged Debian 13 LXC container. It is not maintained, endorsed, or supported by community-scripts, FacturaScripts, or Proxmox Server Solutions GmbH.

## Install

Run this exact command on a Proxmox VE host as `root`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Habier/facturascripts-community-script/main/ct/facturascripts.sh)"
```

The application is installed at `/opt/facturascripts` and exposed over plain HTTP at `http://<container-ip>`.

### Security boundary

- There is **no TLS configuration**. Do not expose port 80 directly to the internet.
- Keep the container on a trusted, access-controlled network until TLS is terminated by a separately managed reverse proxy.
- Complete the web setup immediately. Follow the current FacturaScripts setup flow and replace any default or temporary credentials it creates.
- Provisioning executes code fetched from this repository, the Community Scripts core, and the official FacturaScripts download host.

## Requirements

- A Proxmox VE host with internet access
- Debian 13 LXC support
- Default resources: 2 CPU cores, 2048 MiB RAM, and 20 GB disk
- An unprivileged container (the default)

The script installs PHP 8.4, verifies the upstream-required PHP modules, and rejects MariaDB versions below the upstream 11.2 minimum.

## What it installs

The script preserves the Community Scripts CT/install layout and loads its official engine directly from `community-scripts/core`. It installs FacturaScripts without Docker using:

- PHP 8.4 with Apache
- MariaDB from the Debian distribution
- A database and database user created by the Community Scripts helper
- The mutable official FacturaScripts stable ZIP endpoint
- Apache `mod_rewrite` and the supplied `htaccess-sample`
- Root-owned application files; temporary root-directory write access during first setup must be removed with the documented hardening command, leaving only `Plugins`, `MyFiles`, and `Dinamic` writable

No Community Scripts core files are bundled in this repository.

## First-run setup

Open `http://<container-ip>` and complete the official setup assistant using the MariaDB credentials printed by the installer. Follow the current assistant prompts and immediately replace any default credentials.

### Required post-setup hardening

> [!CAUTION]
> Hardening is **not automatic**. During the web wizard, `/opt/facturascripts` is temporarily mode `770` and group-owned by `www-data` so Apache can create `config.php`. This also allows Apache to rename, delete, or replace root-owned files in that directory.

Immediately after the wizard completes, enter the container as `root` and run:

```bash
/usr/local/sbin/facturascripts-harden-permissions
```

The command refuses to run before `config.php` exists. It restores `/opt/facturascripts` to `root:www-data` mode `750`, makes application files non-writable by Apache, and retains Apache write access only in the existing `Plugins`, `MyFiles`, and `Dinamic` runtime directories. Verify the root boundary with:

```bash
stat -c '%U:%G %a %n' /opt/facturascripts
# Expected: root:www-data 750 /opt/facturascripts
```

## Updates

The container update command intentionally refuses to replace application files because doing so could bypass application migrations.

The hardened permissions make deployed core files read-only to Apache. This may prevent the built-in FacturaScripts updater from replacing core files. Until that flow is tested and a safe permission procedure is documented, test updates only in a disposable clone with a verified full backup. Do not permanently grant recursive `www-data` ownership as a workaround.

Neither updates nor rollback have been verified on Proxmox.

## Backup

A complete backup must include:

- The MariaDB `facturascripts` database
- `/opt/facturascripts/config.php`
- `/opt/facturascripts/Plugins`
- `/opt/facturascripts/MyFiles`

`/opt/facturascripts/Dinamic` is treated as writable runtime data by this installer. Prefer a full Proxmox container backup because a file-only archive does not include the database. Backup and restore have not yet been tested.

Until restore testing proves otherwise, include `Dinamic` in file-level backups rather than assuming it can be regenerated safely.

## Verification status

CI and local checks cover Bash syntax, ShellCheck, and JSON parsing only. They do not prove that provisioning works. Real installation, first-run setup, permissions, updates, backup/restore, reboot persistence, networking, and ARM64 remain unverified.

The stable download URL is mutable and no authoritative checksum or immutable release identifier is available to this project. A reproducible application pin therefore remains a pre-production blocker; this repository deliberately does not invent a version or digest.

See [docs/NOTES.md](docs/NOTES.md) for implementation details and the manual test checklist.

## Relationship to Community Scripts

The CT script loads the engine from `https://raw.githubusercontent.com/community-scripts/core/main` and defaults application scripts to `https://raw.githubusercontent.com/Habier/facturascripts-community-script/main`.

Both URLs track mutable `main` branches. Review upstream changes before each experimental run.

## Release expectations

Initial GitHub releases must remain clearly marked **experimental/pre-release** until the manual checklist is completed on real Proxmox hardware. A release tag does not imply production support, compatibility, or a tested upgrade path.

## License

MIT. See [LICENSE](LICENSE).
