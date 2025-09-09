#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# --- Check if we were effectively run as root ---
[ "${EUID:-$(id -u)}" = 0 ] || { echo "This script needs to be run as root!"; exit 1; }
totalk=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
if [ "$totalk" -lt "2000000" ]; then echo "XOCE Requires at least 2GB Memory!"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

# --- OS detection ---
if [ -f /etc/os-release ]; then
  . /etc/os-release
  distro="$ID"
  version="$VERSION_ID"
else
  echo "Unable to detect OS via /etc/os-release"; exit 1
fi

# Deb Point Release Check
if [ "$distro" = "debian" ] && [ -r /etc/debian_version ]; then
  deb_point=$(sed -E 's/^([0-9]+(\.[0-9]+)?).*/\1/' /etc/debian_version)
  version="${deb_point:-$version}"
fi

echo "Detected: $distro $version"

# --- Version compare helper ---
version_ge() { dpkg --compare-versions "$1" ge "$2"; }

# --- Minimum supported versions ---
case "$distro" in
  debian)
    version_ge "$version" "12.5" || { echo "Debian $version too old (min 12.5)"; exit 1; }
    ;;
  ubuntu)
    version_ge "$version" "24.04" || { echo "Ubuntu $version too old (min 24.04)"; exit 1; }
    ;;
  *)
    echo "Unsupported distribution: $distro"; exit 1
    ;;
esac

# --- Helper: apt install if available ---
apt_install_if_available() {
  local pkg="$1"
  /usr/bin/apt-get update -qq
  if /usr/bin/apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate:'; then
    echo "Installing $pkg"
    /usr/bin/apt-get --yes install "$pkg"
    return 0
  else
    return 1
  fi
}

# --- FUSE runtime install ---
install_fuse_runtime() {
  echo "Ensuring FUSE runtime (libfuse.so.2)..."
  for p in libfuse2 libfuse2t64; do
    apt_install_if_available "$p" && break
  done
  /sbin/ldconfig -v 2>/dev/null || true
  if ! /sbin/ldconfig -p | grep -Fq 'libfuse.so.2'; then
    echo "ERROR: libfuse.so.2 not found. XO requires FUSE2 runtime."
    exit 1
  fi
  echo "libfuse.so.2 verified."
}

# --- Install dependencies ---
install_deps() {
  echo "Installing general dependencies..."
  /usr/bin/apt-get update
  /usr/bin/apt-get --yes install git curl apt-transport-https gnupg ca-certificates

  case "$distro" in
    debian)
      echo "Installing Debian-specific dependencies..."
      install_fuse_runtime
      /usr/bin/apt-get --yes install libnbd-bin nbdkit nbdkit-plugin-vddk || true
      ;;
    ubuntu)
      echo "Installing Ubuntu-specific dependencies..."
      /usr/bin/apt-get --yes install software-properties-common
      /usr/bin/add-apt-repository -y multiverse || true
      /usr/bin/apt-get update
      install_fuse_runtime
      /usr/bin/apt-get --yes install libnbd-bin nbdkit || true
      ;;
  esac

  echo "Installing XOCE common dependencies..."
  /usr/bin/apt-get --yes install \
    build-essential redis-server libpng-dev python3-minimal \
    libvhdi-utils nfs-common lvm2 cifs-utils openssl || true
}

install_deps

# --- Script variables ---
xo_branch="master"
xo_server="https://github.com/vatesfr/xen-orchestra"
n_repo="https://raw.githubusercontent.com/tj/n/master/bin/n"
yarn_repo="deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main"
yarn_gpg="https://dl.yarnpkg.com/debian/pubkey.gpg"
n_location="/usr/local/bin/n"
xo_server_dir="/opt/xen-orchestra"
systemd_service_dir="/lib/systemd/system"
xo_service="xo-server.service"

# --- Install Yarn ---
cd /opt
/usr/bin/curl -sSL "$yarn_gpg" | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "$yarn_repo" | tee /etc/apt/sources.list.d/yarn.list
/usr/bin/apt-get update
/usr/bin/apt-get install --yes yarn

# --- Install Node via n ---
/usr/bin/curl -o "$n_location" "$n_repo"
/bin/chmod +x "$n_location"
/usr/local/bin/n lts

# Ensure new Node is used
export PATH="/usr/local/bin:$PATH"
hash -r

node_version=$(node -v | sed 's/v//')
dpkg --compare-versions "$node_version" lt "20.18" && {
  echo "ERROR: Node version $node_version too old. XO requires >=20.18"
  exit 1
}

# --- Clone & build XO ---
/usr/bin/git clone -b "$xo_branch" "$xo_server" "$xo_server_dir" 2>/dev/null || true
cd "$xo_server_dir"
/usr/bin/yarn
/usr/bin/yarn build

cd packages/xo-server
cp -f sample.config.toml .xo-server.toml

dest=/usr/local/lib/node_modules/
mkdir -p "$dest"

ignoreplugins=("xo-server-test")
for source in $(ls -d /opt/xen-orchestra/packages/xo-server-* 2>/dev/null || true); do
  plugin=$(basename "$source")
  [[ " ${ignoreplugins[*]} " == *" $plugin "* ]] && continue
  ln -sfn "$source" "$dest"
done

# --- systemd service ---
if [[ -e "$systemd_service_dir/$xo_service" ]]; then
  rm -f "$systemd_service_dir/$xo_service"
fi

/bin/cat << 'EOF' > "$systemd_service_dir/$xo_service"
[Unit]
Description= XO Server
After=network-online.target

[Service]
WorkingDirectory=/opt/xen-orchestra/packages/xo-server/
ExecStart=/usr/local/bin/node ./dist/cli.mjs
Restart=always
SyslogIdentifier=xo-server

[Install]
WantedBy=multi-user.target
EOF

/bin/systemctl daemon-reload
/bin/systemctl enable "$xo_service"
/bin/systemctl start "$xo_service" || (sleep 2 && /bin/systemctl start "$xo_service")

echo
echo "Installation complete, open a browser to:" && hostname -I
echo
echo 'Default Login: "admin@admin.net"  Password: "admin"'
echo
echo "Don't forget to change your password!"
