# vaultwarden-render-template — agent notes

## Render env-vars API replaces, does not append

`PUT https://api.render.com/v1/services/{id}/env-vars` **replaces the entire env-var set** with the array you send — it does not merge with existing vars. Sending only one var wipes all the others, and the next deploy fails (no DB, no RSA keys, etc.).

Always send the **full** env-var set in one PUT, not just the new/changed key.

```powershell
$body = '[
  {"key":"DOMAIN","value":"https://vaultwardenn.onrender.com"},
  {"key":"DATABASE_URL","value":"..."},
  {"key":"SIGNING_KEY","value":"..."},
  {"key":"VW_RSA_KEY","value":"..."},
  {"key":"VW_RSA_PUB_KEY","value":"..."}
]'
Invoke-RestMethod -Uri "https://api.render.com/v1/services/$srvId/env-vars" `
  -Method Put -Body $body -ContentType "application/json" -Headers $hdr
```

## DOMAIN must be set or sync breaks

Without `DOMAIN`, Vaultwarden's `/api/config` returns `environment.vault/api/identity/notifications = "http://localhost/..."`. The Bitwarden client then tries to hit localhost and sync fails silently from the user's perspective.

Required env vars: `DOMAIN`, `DATABASE_URL`, `SIGNING_KEY`, `VW_RSA_KEY`, `VW_RSA_PUB_KEY`.

## Deploy trigger

POST to `https://api.render.com/v1/services/{id}/deploys` with body `{}` (empty JSON object). An empty body or no body returns "invalid JSON" - must send `{}`.

## Keep-alive 403 is the edge, not the app

cron-job.org pings this service to stop the Render free instance spinning down. On 2026-09-27 22:40 UTC one run reported `Failed (403 Forbidden)`.

That 403 did not come from Vaultwarden. `onrender.com` sits behind Cloudflare (`Server: cloudflare`, `CF-RAY`, `x-render-origin-server: Rocket`) and no route here returns 403: `/`, `/alive`, `/api/config` and a disabled `/admin` all return 200, unknown paths return 404, rate limiting returns 429. A 403 therefore means Render's edge rejected that single request - check again before touching the app:

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" https://vaultwardenn.onrender.com/alive
```

Two things that make the failure look worse than it is:

- `/alive` returns a bare ISO timestamp wrapped in quotes, not `OK`. Judge runs by HTTP status, not by body text.
- cron-job.org sends no further failure emails until a run succeeds, so silence after a failure email means "unknown", not "recovered".


## Supabase connection drop & silent item disappearance (2026-10-28)

### Symptom
Every morning, the first item saved via the Bitwarden client (extension/mobile/web) appeared to save successfully, but then silently vanished after a few seconds or on subsequent sync.

### Root Cause
1. **Keep-alive decoupling:** `cron-job.org` pings `/alive` to keep the Render free web service container awake. However, `/alive` is an in-memory Rocket endpoint returning a static timestamp (`chrono::Utc::now()`) without querying PostgreSQL.
2. **Idle socket termination:** Over long idle gaps (overnight 6-8+ hours with zero queries), AWS stateful firewalls / NAT gateways and Supabase's Supavisor pooler prune idle TCP connections from their state tables without a clean TCP FIN/RST.
3. **Zombie pool connections:** Without TCP keepalives in `DATABASE_URL` (`keepalives=1`), the Linux socket on Render remains open in `ESTABLISHED`. When the client sends `POST /api/ciphers` in the morning, `r2d2` retrieves a dead connection and tries to ping (`SELECT 1`). Because the NAT state is gone, packets are silently dropped and retransmitted until `DATABASE_TIMEOUT` (30s) or the client's internal timeout aborts.
4. **Optimistic save & desync:** The Bitwarden extension UI dismisses the save prompt optimistically or assumes success before the request times out. When the client subsequently runs `GET /api/sync` (or reconnects WebSocket), `r2d2` has evicted the broken socket and opened a fresh connection. The sync fetches the database state which lacks the uncommitted item, overwriting the client cache and making the item vanish.

### Fix Applied
1. **TCP keepalives in `DATABASE_URL`:**
   Appended query parameters: `keepalives=1&keepalives_idle=30&keepalives_interval=10&keepalives_count=3&tcp_user_timeout=30000`. Keepalive probes every 30s ensure NAT tables never drop the session.
2. **Connection pool recycling env vars:**
   - `DATABASE_IDLE_TIMEOUT=120`: Closes idle connections after 2 minutes instead of default 600s.
   - `DATABASE_TIMEOUT=15`: Fails dead connection checkouts quickly (15s) so callers recover fast.
   - `DATABASE_MAX_CONNS=10`: Explicit connection cap for the Supabase session pooler.
3. **Reminder:** When updating env vars via `PUT https://api.render.com/v1/services/{id}/env-vars`, always send the complete array containing all 8 variables.
