# webOS Tailscale Installer

A shell script to install and update [Tailscale](https://tailscale.com/) on rooted LG webOS TVs (via [Homebrew Channel](https://www.webosbrew.org/)).

## Requirements

- A rooted LG webOS TV with Homebrew Channel installed ([rooting guide](https://www.webosbrew.org/guides/rooting/))
- SSH access to the TV (enabled via Homebrew Channel settings)

## Usage

Over SSH on the TV (requires root access and Homebrew Channel installed):

```sh
curl -sSL https://raw.githubusercontent.com/GarmirFandel/webos-tailscale/main/install-tailscale.sh | sh
```

This auto-detects both the device architecture and the latest stable Tailscale version, and asks for confirmation before installing.

You can also specify a version and/or architecture explicitly:

```sh
curl -sSL https://raw.githubusercontent.com/GarmirFandel/webos-tailscale/main/install-tailscale.sh | sh -s -- 1.104.1 arm64
```

| Argument | Description | Default |
|---|---|---|
| `$1` (version) | Tailscale version to install. Leave empty (`""`) to auto-detect the latest. | auto-detect |
| `$2` (arch) | Target architecture (`arm`, `arm64`, `amd64`, `386`). | auto-detected via `uname -m` |

## What it does

1. Verifies it's running as root on a webOS device
2. Detects the device architecture (or uses the one explicitly provided)
3. Fetches the latest stable Tailscale version for that architecture, if none is specified
4. Downloads the `tailscale` and `tailscaled` binaries into `/media/developer/bin/`
5. Registers `tailscaled` as a Homebrew Channel init.d service, so it starts automatically on boot
6. Sets up a bind-mount for `/etc/resolv.conf`, needed because `/etc/` is read-only on webOS
7. Adds the install directory to `PATH` in `/home/root/.profile`

## First-time setup

After installing, authenticate the device on your tailnet:

```sh
export PATH=$PATH:/media/developer/bin
tailscale up --hostname=your-tv-name --netfilter-mode=off --accept-dns=false
```

- `--netfilter-mode=off` — avoids errors from missing iptables kernel modules on webOS
- `--accept-dns=false` — avoids errors from the read-only `/etc/` filesystem (MagicDNS isn't usable here anyway)

Open the printed login link on any other device's browser to complete authentication.

## Updating

Just re-run the same `curl | sh` command — it detects and stops any running `tailscaled` instance before overwriting the binaries. No need to re-authenticate: Tailscale's node state persists independently of the binaries.

## Notes

- Tested on webOS 6 (LG C1, arm64) and an older arm (32-bit) webOS model.
- SSH on Homebrew-rooted webOS devices typically runs on port **9922**, not 22.
- If `tailscale`/`tailscaled` aren't found right after install in an already-open SSH session, either run `export PATH=$PATH:/media/developer/bin` or reconnect — `.profile` is only read on new sessions.

## License

MIT
