# Troubleshooting — LiteLLM Local Proxy

> Common issues and fixes for the LiteLLM proxy on WSL2 / ARM64 Windows.

---

## Proxy Won't Start

### `litellm: command not found`

```bash
# Verify the venv is activated:
source ~/litellm-env/bin/activate
which litellm
# Expected: /home/username/litellm-env/bin/litellm

# If still not found, reinstall:
pip install 'litellm[proxy]'
```

### `Error: config file not found`

```bash
# Check the path:
ls -lh ~/litellm/config.yaml
# If missing, copy from template:
cp /path/to/repo/config/config.yaml.example ~/litellm/config.yaml
nano ~/litellm/config.yaml   # add your API keys
```

### `Address already in use (port 4000)`

```bash
# Find what's using the port:
ss -tulpn | grep 4000
# Kill it:
kill $(lsof -ti:4000)
# Or restart the service:
systemctl --user restart litellm-proxy
```

---

## API Calls Return Errors

### `401 Unauthorized`

The master key in your request doesn't match `config.yaml`:

```bash
# Check your config:
grep "master_key" ~/litellm/config.yaml
# e.g. master_key: sk-local-vivo2

# Use the correct key in your requests:
curl http://localhost:4000/v1/models \
  -H "Authorization: Bearer sk-local-vivo2"
```

### `404 Model not found`

The model alias doesn't exist in `config.yaml`:

```bash
# List available aliases:
curl -s http://localhost:4000/v1/models \
  -H "Authorization: Bearer sk-local-vivo2" | \
  python3 -m json.tool | grep '"id"'
```

### `429 Too Many Requests` (cloud provider limit hit)

Normal behavior — LiteLLM will failover automatically. To check:

```bash
curl -s http://localhost:4000/health \
  -H "Authorization: Bearer sk-local-vivo2" | python3 -m json.tool
```

If the failover chain is also exhausted, use a local model explicitly:

```python
response = client.chat.completions.create(
    model="local-smart",   # always routes to Ollama, unlimited
    messages=[...]
)
```

---

## Systemd Service Issues

### Service fails to start

```bash
# Check the logs:
journalctl --user -u litellm-proxy -n 50 --no-pager

# Common cause: venv path wrong in the .service file
# Edit:
nano ~/.config/systemd/user/litellm-proxy.service
# Check ExecStart= path matches your actual venv location:
ls ~/litellm-env/bin/litellm
```

### Service starts but exits immediately

```bash
# Run manually to see the full error:
source ~/litellm-env/bin/activate
litellm --config ~/litellm/config.yaml --port 4000
# Read the error output directly
```

### Service not found after install

```bash
# Reload systemd user daemon after copying .service file:
systemctl --user daemon-reload
systemctl --user enable litellm-proxy
systemctl --user start litellm-proxy
systemctl --user status litellm-proxy
```

### Service doesn't start after WSL2 reboot

WSL2 systemd user services require `loginctl enable-linger` to run without an active session:

```bash
loginctl enable-linger $USER
# Verify:
loginctl show-user $USER | grep Linger
# Expected: Linger=yes
```

---

## Ollama / Local Model Issues

### `local-smart` or `local-fast` returns error

```bash
# Check Ollama is running:
curl http://localhost:11434/api/tags
# If no response:
ollama serve &

# Verify the model is pulled:
ollama list
# If model is missing:
ollama pull qwen2.5-coder:1.5b
```

### GenieAPIService (`local-npu`) not responding

```powershell
# Windows — check if GenieAPIService is running:
Get-Process -Name "GenieAPIService" -ErrorAction SilentlyContinue
# If not running, start it:
cd C:\AI\GenieAPIService_cpp
.\GenieAPIService.exe -c models\llama3.1-8b-8380-qnn2.38\config.json -l -d 3 -p 8912

# Test from WSL2:
curl http://host.docker.internal:8912/v1/models
# Or use Windows host IP directly from WSL2:
curl http://$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):8912/v1/models
```

---

## ARM64 / WSL2 Specific Issues

### `pip install litellm[proxy]` fails on ARM64

Some dependencies have no ARM64 wheel and must compile from source:

```bash
# Install build dependencies first:
sudo apt-get install -y python3-dev build-essential libssl-dev libffi-dev

# Then install:
pip install 'litellm[proxy]'
```

If a specific dependency fails, install without optional extras first:

```bash
pip install litellm
pip install uvicorn fastapi  # add proxy deps manually
```

### `ModuleNotFoundError: No module named 'tiktoken'`

```bash
pip install tiktoken
```

### Port 4000 not accessible from Windows host

WSL2 with `networkingMode=mirrored` (in `.wslconfig`) exposes WSL2 ports directly on Windows. If not configured:

```ini
# C:\Users\username\.wslconfig
[experimental]
networkingMode=mirrored
```

Restart WSL2: `wsl --shutdown` then reopen.

---

## Health Check Script

Run this to diagnose all components at once:

```bash
bash scripts/health-check.sh
```

Expected output:
```
[OK]  LiteLLM proxy responding (port 4000)
[OK]  Healthy providers: 9 | Unhealthy: 0
[OK]  fast    → groq/llama-3.1-8b-instant
[OK]  smart   → gemini/gemini-2.0-flash
[OK]  local-smart → ollama/qwen2.5:14b
[OK]  local-npu   → GenieAPIService (port 8912)
```

---

## Useful Debug Commands

```bash
# Live proxy logs:
journalctl --user -u litellm-proxy -f

# All active providers:
curl -s http://localhost:4000/health -H "Authorization: Bearer sk-local-vivo2" | python3 -m json.tool

# Test a specific model:
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-local-vivo2" \
  -d '{"model": "fast", "messages": [{"role": "user", "content": "ping"}], "max_tokens": 10}'

# LiteLLM version:
litellm --version

# Python + package versions:
python3 -c "import litellm; print(litellm.__version__)"
```
