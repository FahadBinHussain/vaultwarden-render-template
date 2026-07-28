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

POST to `https://api.render.com/v1/services/{id}/deploys` with body `{}` (empty JSON object). An empty body or no body returns "invalid JSON" — must send `{}`.