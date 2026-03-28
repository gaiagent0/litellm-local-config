#!/usr/bin/env bash
# install.sh — LiteLLM proxy one-shot install for WSL2 / Linux ARM64
# Usage: bash install.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
fail() { echo -e "${RED}[-]${NC} $*" >&2; exit 1; }

log "=== LiteLLM Local Proxy — Install Script ==="
echo

# ── 1. Prereqs ───────────────────────────────────────────────────────────────
log "Checking prerequisites..."
command -v python3 >/dev/null || fail "python3 not found — install Python 3.11+"
python3 -c "import sys; assert sys.version_info >= (3,11), 'Python 3.11+ required'" \
  || fail "Python 3.11+ required"

ARCH=$(uname -m)
log "Architecture: $ARCH"
[[ "$ARCH" == "aarch64" || "$ARCH" == "x86_64" ]] || warn "Untested architecture: $ARCH"

# ── 2. Virtualenv ─────────────────────────────────────────────────────────────
VENV_DIR="$HOME/litellm-env"
log "Creating virtualenv at $VENV_DIR..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

log "Installing LiteLLM..."
pip install --quiet --upgrade pip
pip install --quiet 'litellm[proxy]'
LITELLM_VERSION=$(litellm --version 2>/dev/null | head -1)
log "Installed: $LITELLM_VERSION"

# ── 3. Config directory ───────────────────────────────────────────────────────
LITELLM_DIR="$HOME/litellm"
mkdir -p "$LITELLM_DIR"

if [[ ! -f "$LITELLM_DIR/config.yaml" ]]; then
  log "Copying config template to $LITELLM_DIR/config.yaml..."
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$SCRIPT_DIR/../config/config.yaml.example" "$LITELLM_DIR/config.yaml"
  warn "config.yaml created — EDIT IT NOW and add your API keys:"
  warn "  nano $LITELLM_DIR/config.yaml"
else
  warn "config.yaml already exists — skipping copy (not overwriting)"
fi

# ── 4. systemd user service ───────────────────────────────────────────────────
if systemctl --user is-active --quiet litellm-proxy 2>/dev/null; then
  warn "litellm-proxy service already running — stopping for reinstall..."
  systemctl --user stop litellm-proxy
fi

SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$SERVICE_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/litellm-proxy.service" "$SERVICE_DIR/"

systemctl --user daemon-reload
systemctl --user enable litellm-proxy
log "systemd user service installed and enabled"

# ── 5. Log directory ──────────────────────────────────────────────────────────
mkdir -p "$LITELLM_DIR/logs"

# ── 6. Summary ───────────────────────────────────────────────────────────────
echo
log "=== Installation Complete ==="
echo
echo "  Next steps:"
echo "  1. Add API keys:   nano $LITELLM_DIR/config.yaml"
echo "  2. Start service:  systemctl --user start litellm-proxy"
echo "  3. Check status:   systemctl --user status litellm-proxy"
echo "  4. Health check:   bash $(dirname "$0")/health-check.sh"
echo
warn "IMPORTANT: config.yaml contains API keys — never commit it to git!"
