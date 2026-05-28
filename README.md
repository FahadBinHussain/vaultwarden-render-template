# vaultwarden-render-template

Minimal Render-ready wrapper for the official `vaultwarden/server` image.

## What This Does

- Uses the upstream Vaultwarden container directly.
- Keeps generated RSA keys in Render environment variables.
- Writes keys into `/data` before Vaultwarden starts.
- Leaves persistent data to the Render disk mounted at `/data`.

## Required Environment Variables

Set these as secret environment variables in Render:

```text
VW_RSA_KEY=base64-encoded-private-key
VW_RSA_PUB_KEY=base64-encoded-public-key
```

Vaultwarden still supports its normal environment variables, such as `DOMAIN`, `ADMIN_TOKEN`, `SIGNUPS_ALLOWED`, and SMTP settings. Add only the ones your deployment needs.

## Generate Keys

On a local machine with OpenSSL:

```powershell
openssl genrsa -out rsa_key.pem 2048
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub.pem
[Convert]::ToBase64String([IO.File]::ReadAllBytes("rsa_key.pem"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("rsa_key.pub.pem"))
```

Paste the two base64 outputs into `VW_RSA_KEY` and `VW_RSA_PUB_KEY`.

## Render

Create a Web Service from this repository, add a persistent disk mounted at `/data`, and use the default Docker build settings. Render will start the container with the `CMD` in this repository.
