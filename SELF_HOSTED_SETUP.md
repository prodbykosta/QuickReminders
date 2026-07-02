# Self-Hosted AI Backend for QuickReminders

Run your own AI model on your Mac and use it securely from anywhere with your iPhone.

**What you need:**
- Mac with Apple Silicon (M1/M2/M3) — 16GB+ RAM recommended
- iPhone with QuickReminders installed
- A domain managed by Cloudflare (or transfer DNS to Cloudflare — free)
- A Cloudflare account (free tier)

---

## Step 1 — Move DNS to Cloudflare (if not already)

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → **Add a site** → enter your domain → select **Free plan**
2. Cloudflare scans and imports all your existing DNS records automatically
3. You get two nameservers (e.g. `chloe.ns.cloudflare.com` and `osmar.ns.cloudflare.com`)
4. At your registrar (OVH, Namecheap, etc.) → update nameservers to the two Cloudflare ones
5. Wait 5–30 minutes for propagation

> Your existing hosting keeps working — Cloudflare just handles DNS now.

---

## Step 2 — Install Ollama + Pull a Model

```bash
brew install ollama
```

Then pull a model. Recommended for multilingual reminders:

```bash
ollama pull qwen2.5:7b
```

Other options:

| Model | RAM | Speed (M3) | Quality |
|-------|-----|-----------|---------|
| llama3.2:3b | ~2GB | ~100 tok/s | Good |
| llama3.1:8b | ~5GB | ~60 tok/s | Great |
| qwen2.5:7b | ~5GB | ~60 tok/s | Great (best multilingual) |
| qwen2.5:14b | ~9GB | ~35 tok/s | Excellent |

---

## Step 3 — Start Ollama Accepting All Connections

By default Ollama only accepts local connections. Start it with:

```bash
OLLAMA_HOST=0.0.0.0 ollama serve
```

> Add `export OLLAMA_HOST=0.0.0.0` to your `~/.zshrc` so it persists after restart.

---

## Step 4 — Install Cloudflare Tunnel

```bash
brew install cloudflare/cloudflare/cloudflared
cloudflared tunnel login
```

This opens a browser — log in to Cloudflare and authorize it.

---

## Step 5 — Create the Tunnel

```bash
cloudflared tunnel create quickreminders-ai
```

Copy the **Tunnel ID** it prints — you'll need it next.

---

## Step 6 — Configure the Tunnel

```bash
nano ~/.cloudflared/config.yml
```

Paste this (replace `YOUR_TUNNEL_ID` and `ai.yourdomain.com`):

```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /Users/YOUR_USERNAME/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: quickreminders.yourdomain.com
    service: http://localhost:11434
  - service: http_status:404
```

Save: `Ctrl+O` → Enter → `Ctrl+X`

---

## Step 7 — Create DNS Record

```bash
cloudflared tunnel route dns quickreminders-ai quickreminders.yourdomain.com
```

This automatically creates the CNAME in Cloudflare — no manual DNS editing needed.

---

## Step 8 — Start the Tunnel

```bash
cloudflared tunnel run quickreminders-ai
```

To auto-start on login:

```bash
cloudflared service install
```

---

## Step 9 — Secure It with Cloudflare WAF

This is important — without this, anyone who finds your URL can use your Mac's GPU.

1. Cloudflare dashboard → your domain → **Security** → **WAF** → **Custom Rules** → **Create rule**
2. Name it: `QuickReminders Block`
3. Click **Edit expression** and paste:

```
(http.request.uri.path contains "/v1/") and (http.request.headers["x-api-token"][0] ne "YOUR_SECRET_TOKEN_HERE")
```

Replace `YOUR_SECRET_TOKEN_HERE` with a strong random password. Generate one:

```bash
openssl rand -hex 32
```

4. Set action to **Block**
5. Save

This blocks all requests to `/v1/` that don't include your secret token header.

---

## Step 10 — Keep Mac Awake

**System Settings → Battery → Options → Prevent automatic sleeping when display is off** (on Power Adapter)

Or via terminal:
```bash
sudo pmset -c sleep 0 displaysleep 30
```

---

## Step 11 — Configure QuickReminders

Open the app → **Settings → AI Mode**:

1. Enable **AI Mode**
2. Select **Custom** as provider
3. **Base URL:** `https://quickreminders.yourdomain.com`
4. **Model:** `qwen2.5:7b`
5. **Secret Token:** the same token you put in the WAF rule

---

## Step 12 — Test It

```bash
curl https://quickreminders.yourdomain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-api-token: YOUR_SECRET_TOKEN_HERE" \
  -d '{"model":"qwen2.5:7b","messages":[{"role":"user","content":"hello"}]}'
```

You should get a JSON response. Without the `x-api-token` header, you get a 403.

---

## Troubleshooting

**403 without token:** WAF rule is working correctly.

**403 even with token:** Double-check the token matches exactly, no extra spaces.

**Empty response / connection refused:**
- Check Ollama is running: `curl http://localhost:11434/api/tags`
- Make sure you started it with `OLLAMA_HOST=0.0.0.0`
- Check the tunnel is active in the terminal where you ran `cloudflared tunnel run`

**Slow first response:** Normal — model loads on first request (~5–10s). Subsequent requests are fast.

**Model gives wrong output:** Try `qwen2.5:7b` — best instruction following for multilingual input.
