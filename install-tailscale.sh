#!/bin/sh

# Quit if not running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Refer to https://www.webosbrew.org/guides/rooting/ for more information."
    exit 1
fi

# Quit if not running on webOS
if [ ! -f /etc/starfish-release ]; then
    echo "This script is intended for webOS devices only."
    exit 1
fi

# Map uname -m output to Tailscale's arch naming
detect_arch() {
    case "$(uname -m)" in
        aarch64|arm64)        echo "arm64" ;;
        armv7l|armv6l|arm)    echo "arm" ;;
        x86_64|amd64)         echo "amd64" ;;
        i386|i686)            echo "386" ;;
        *)                     echo "" ;;
    esac
}

if [ -n "$2" ]; then
    TAILSCALE_ARCH="$2"
    echo "Using architecture from argument: ${TAILSCALE_ARCH}"
else
    TAILSCALE_ARCH=$(detect_arch)
    if [ -z "$TAILSCALE_ARCH" ]; then
        echo "Error: could not map 'uname -m' output ($(uname -m)) to a known Tailscale architecture."
        echo "Specify it manually: $0 [version] <arch>"
        echo "(known values: arm, arm64, amd64, 386)"
        exit 1
    fi
    echo "Detected architecture: ${TAILSCALE_ARCH} (uname -m: $(uname -m))"
fi

if [ -z "$1" ]; then
    echo "No version specified, checking latest available for ${TAILSCALE_ARCH}..."
    TAILSCALE_VERSION=$(curl -sSL "https://pkgs.tailscale.com/stable/" | grep -oE "tailscale_[0-9]+\.[0-9]+\.[0-9]+_${TAILSCALE_ARCH}\.tgz" | sed -E "s/tailscale_([0-9.]+)_.*/\1/" | awk -F. '{ printf "%05d%05d%05d %s\n", $1, $2, $3, $0 }' | sort | tail -n1 | awk '{print $2}')

    if [ -z "$TAILSCALE_VERSION" ]; then
        echo "Error: could not detect the latest version automatically for arch '${TAILSCALE_ARCH}'."
        echo "Specify one manually: $0 <version> [arch]"
        exit 1
    fi

    printf "Latest version found: %s (%s). Proceed? [y/N] " "$TAILSCALE_VERSION" "$TAILSCALE_ARCH"
    read -r ANSWER < /dev/tty
    case "$ANSWER" in
        y|Y|yes|Yes) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
else
    TAILSCALE_VERSION="$1"
fi

TAILSCALE_DIST="tailscale_${TAILSCALE_VERSION}_${TAILSCALE_ARCH}"
TAILSCALE_TARBALL="https://pkgs.tailscale.com/stable/${TAILSCALE_DIST}.tgz"
INSTALL_BINDIR=/media/developer/bin/

echo "Checking ${TAILSCALE_TARBALL}..."
if ! curl -sfI "$TAILSCALE_TARBALL" > /dev/null; then
    echo "Error: could not find ${TAILSCALE_DIST}.tgz on pkgs.tailscale.com/stable/"
    echo "Check the version/arch and try again."
    exit 1
fi

if pgrep tailscaled > /dev/null 2>&1; then
    echo "Stopping running tailscaled..."
    killall tailscaled
    sleep 1
fi

mkdir -p "$INSTALL_BINDIR"

echo "Downloading Tailscale ${TAILSCALE_VERSION} (${TAILSCALE_ARCH})..."
curl -sSL "$TAILSCALE_TARBALL" | tar -xz -C "$INSTALL_BINDIR" "$TAILSCALE_DIST/tailscaled" "$TAILSCALE_DIST/tailscale" --strip-components=1

echo "Adding tailscaled to init.d..."

cat <<EOF > /var/lib/webosbrew/init.d/tailscaled
#!/bin/sh
export PATH=/media/developer/bin:/usr/sbin:/usr/bin:/sbin:/bin
cp /etc/resolv.conf /tmp/resolv.conf
mount -o bind /tmp/resolv.conf /etc/resolv.conf
/media/developer/bin/tailscaled &> /tmp/tailscaled.log &
EOF
chmod +x /var/lib/webosbrew/init.d/tailscaled

echo "Setting up PATH..."
if ! grep -q "$INSTALL_BINDIR" /home/root/.profile 2>/dev/null; then
    echo "export PATH=\$PATH:$INSTALL_BINDIR" >> /home/root/.profile
fi

echo "Restarting tailscaled..."
/media/developer/bin/tailscaled &> /tmp/tailscaled.log &

echo "Done! Run 'tailscale status' to verify, or 'tailscale up' if re-authentication is needed."
