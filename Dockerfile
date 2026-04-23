FROM vaultwarden/server:latest

# This script runs every time the container boots
RUN echo '#!/bin/sh\n\
echo "$VW_RSA_KEY" | base64 -d > /data/rsa_key.pem\n\
echo "$VW_RSA_PUB_KEY" | base64 -d > /data/rsa_key.pub.pem\n\
/vaultwarden' > /start.sh

RUN chmod +x /start.sh

# This tells Render EXACTLY how to start, no guessing
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/bin/sh", "/start.sh"]
