FROM vaultwarden/server:latest

# Render stores the RSA key material in environment variables; Vaultwarden expects files.
CMD sh -c "echo $VW_RSA_KEY | base64 -d > /data/rsa_key.pem && echo $VW_RSA_PUB_KEY | base64 -d > /data/rsa_key.pub.pem && /vaultwarden"
