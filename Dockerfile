FROM vaultwarden/server:latest

# We use the Shell form of CMD which allows us to use variables directly
# This creates the keys from your Env Vars and then starts Vaultwarden
CMD sh -c "echo $VW_RSA_KEY | base64 -d > /data/rsa_key.pem && echo $VW_RSA_PUB_KEY | base64 -d > /data/rsa_key.pub.pem && /vaultwarden"
