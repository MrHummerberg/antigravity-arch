#!/usr/bin/env bash
set -euo pipefail

APT_BASE="https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev"
PKG_INDEX_URL="${APT_BASE}/dists/antigravity-debian/main/binary-amd64/Packages"

APP_DIR="/opt/antigravity"
VERSION_FILE="$APP_DIR/version"
BIN_LINK="/usr/local/bin/antigravity"
DESKTOP1="/usr/share/applications/antigravity.desktop"
DESKTOP2="/usr/share/applications/antigravity-url-handler.desktop"
ICON_PATH="/usr/share/icons/hicolor/512x512/apps/antigravity.png"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }

download_with_retry() {
  local url="$1"
  local output="$2"
  local retries=3
  local count=0

  until curl -fsSL "$url" -o "$output"; do
    count=$((count + 1))
    if [[ $count -ge $retries ]]; then
      log_error "Failed to download $url after $retries attempts."
      return 1
    fi
    log_warn "Download failed. Retrying ($count/$retries)..."
    sleep 2
  done
}

if [[ "${1-}" == "--uninstall" ]]; then
  log_info "Uninstalling Antigravity..."
  sudo rm -rf "$APP_DIR" || true
  sudo rm -f "$BIN_LINK" || true
  sudo rm -f "$DESKTOP1" "$DESKTOP2" || true
  sudo rm -f "$ICON_PATH" || true

  sudo rmdir -p "$(dirname "$ICON_PATH")" 2>/dev/null || true

  log_success "Done. Antigravity removed."
  exit 0
fi

FORCE_INSTALL=false
if [[ "${1-}" == "--force" ]]; then
  FORCE_INSTALL=true
fi

for cmd in curl bsdtar sha256sum awk; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command '$cmd' not found. Install it and retry: $cmd" >&2
    exit 1
  fi
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"

log_info "Fetching APT Packages index..."
if ! download_with_retry "$PKG_INDEX_URL" "Packages"; then
  exit 1
fi

log_info "Parsing latest antigravity entry..."
read -r DEBVER DEBFILENAME DEBSHA256 <<< "$(
  awk -v RS="" -v FS="\n" '
    /Package: antigravity/ {
      ver=""; file=""; sha="";
      for(i=1;i<=NF;i++) {
        if ($i ~ /^Version:/) { sub(/^Version: /, "", $i); ver=$i }
        if ($i ~ /^Filename:/) { sub(/^Filename: /, "", $i); file=$i }
        if ($i ~ /^SHA256:/) { sub(/^SHA256: /, "", $i); sha=$i }
      }
      if (ver != "" && file != "" && sha != "") {
        print ver, file, sha
      }
    }
  ' Packages | sort -V | tail -n 1
)"

if [[ -z "${DEBVER:-}" || -z "${DEBFILENAME:-}" || -z "${DEBSHA256:-}" ]]; then
  log_error "Failed to parse antigravity package info from Packages index" >&2
  exit 1
fi

log_success "Latest version:  $DEBVER"

if [[ "$FORCE_INSTALL" == "false" && -f "$VERSION_FILE" ]]; then
  INSTALLED_VER="$(cat "$VERSION_FILE")"
  if [[ "$INSTALLED_VER" == "$DEBVER" ]]; then
    log_success "Antigravity is already up to date ($INSTALLED_VER). Use --force to reinstall."
    exit 0
  else
    log_info "Updating from $INSTALLED_VER to $DEBVER..."
  fi
fi

log_info "Filename:        $DEBFILENAME"
log_info "SHA256:          $DEBSHA256"

DEB_URL="${APT_BASE}/${DEBFILENAME}"
DEB_FILE="antigravity.deb"

log_info "Downloading DEB..."
if ! download_with_retry "$DEB_URL" "$DEB_FILE"; then
  exit 1
fi

log_info "Verifying SHA256..."
echo "${DEBSHA256}  ${DEB_FILE}" | sha256sum -c -

log_info "Extracting DEB..."
bsdtar -xf "$DEB_FILE"
bsdtar -xf data.tar.xz

if [[ ! -d usr/share/antigravity ]]; then
  log_error "Unexpected DEB structure: usr/share/antigravity not found." >&2
  exit 1
fi

log_info "Installing into ${APP_DIR} (requires sudo)..."
sudo rm -rf "$APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo cp -r usr/share/antigravity/* "$APP_DIR/"

echo "$DEBVER" | sudo tee "$VERSION_FILE" >/dev/null

if [[ -f "$APP_DIR/chrome-sandbox" ]]; then
  sudo chown root:root "$APP_DIR/chrome-sandbox" || true
  sudo chmod 4755 "$APP_DIR/chrome-sandbox" || true
fi

log_info "Creating binary symlink ${BIN_LINK}..."
sudo mkdir -p "$(dirname "$BIN_LINK")"
sudo ln -sf "$APP_DIR/antigravity" "$BIN_LINK"

log_info "Installing .desktop files..."
if [[ -f usr/share/applications/antigravity.desktop ]]; then
  tmp1="$(mktemp)"
  sed 's|^Exec=.*|Exec=/opt/antigravity/antigravity %U|g' \
    usr/share/applications/antigravity.desktop > "$tmp1"
  sudo install -Dm644 "$tmp1" "$DESKTOP1"
fi

if [[ -f usr/share/applications/antigravity-url-handler.desktop ]]; then
  tmp2="$(mktemp)"
  sed 's|^Exec=.*|Exec=/opt/antigravity/antigravity %U|g' \
    usr/share/applications/antigravity-url-handler.desktop > "$tmp2"
  sudo install -Dm644 "$tmp2" "$DESKTOP2"
fi

log_info "Installing icon..."
if [[ -f usr/share/pixmaps/antigravity.png ]]; then
  sudo mkdir -p "$(dirname "$ICON_PATH")"
  sudo install -Dm644 usr/share/pixmaps/antigravity.png "$ICON_PATH"
fi

echo
log_success "Antigravity ${DEBVER} installed successfully."
log_info "Run:  antigravity"
log_info "To uninstall:  $0 --uninstall"
