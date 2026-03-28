#!/usr/bin/env bash
# health-check.sh — LiteLLM proxy health diagnostic
# Usage: bash health-check.sh [--verbose]

PROXY_URL="${LITELLM_URL:-http://localhost:4000}"
API_KEY="${LITELLM_KEY:-sk-local-vivo2}"
VERBOSE="${1:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  OK${NC}  $*"; }
fail() { echo -e "${RED}  FAIL${NC} $*"; }
warn() { echo -e "${YELLOW}  WARN${NC} $*"; }

echo -e "\n${CYAN}=== LiteLLM Proxy Health Check ===${NC}"
echo "Endpoint: $PROXY_URL"
echo

# ── 1. Service reachability ───────────────────────────────────────────────────
if curl -sf --max-time 3 "$PROXY_URL/health" \
    -H "Authorization: Bearer $API_KEY" -o /tmp/litellm_health.json 2>/dev/null; then
  HEALTHY=$(python3 -c "import json; d=json.load(open('/tmp/litellm_health.json')); print(d.get('healthy_count',0))" 2>/dev/null)
  UNHEALTHY=$(python3 -c "import json; d=json.load(open('/tmp/litellm_health.json')); print(d.get('unhealthy_count',0))" 2>/dev/null)
  ok "Proxy reachable — Healthy: $HEALTHY | Unhealthy: $UNHEALTHY"
  if [[ "$UNHEALTHY" != "0" ]]; then
    warn "Some providers are unhealthy — check config.yaml API keys"
  fi
else
  fail "Proxy not reachable at $PROXY_URL"
  echo "  → Is the service running? systemctl --user status litellm-proxy"
  exit 1
fi

# ── 2. Model list ─────────────────────────────────────────────────────────────
echo
echo "Available models:"
curl -sf --max-time 5 "$PROXY_URL/v1/models" \
    -H "Authorization: Bearer $API_KEY" 2>/dev/null | \
  python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for m in d.get('data', []):
        print(f'  - {m[\"id\"]}')
except:
    print('  (could not parse model list)')
"

# ── 3. Quick inference test (local model only — no cloud quota used) ──────────
echo
echo "Testing local inference (local-fast → Ollama)..."
RESPONSE=$(curl -sf --max-time 15 "$PROXY_URL/v1/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"local-fast","messages":[{"role":"user","content":"Reply with exactly: OK"}],"max_tokens":10}' 2>/dev/null)

if echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null | grep -q "OK"; then
  ok "local-fast inference working"
else
  warn "local-fast inference failed or slow — is Ollama running?"
  if [[ "$VERBOSE" == "--verbose" ]]; then
    echo "  Response: $RESPONSE"
  fi
fi

# ── 4. systemd service status ─────────────────────────────────────────────────
echo
if systemctl --user is-active --quiet litellm-proxy 2>/dev/null; then
  ok "systemd service: active"
else
  warn "systemd service: not active (manual start or not installed)"
fi

echo -e "\n${CYAN}=================================${NC}\n"
