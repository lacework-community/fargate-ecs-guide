# syntax=docker/dockerfile:1
### LW Agent (1) adding a build stage ######################
FROM lacework/datacollector:latest AS agent-build-image
############################################################

FROM ubuntu:latest
RUN apt-get update && apt-get install -y \
   curl \
   jq \
   sed \
   && rm -rf /var/lib/apt/lists/*

### LW Agent (2) copying the binary  #######################
COPY --from=agent-build-image  /var/lib/backup/*/datacollector /var/lib/lacework/datacollector
### LW Agent (3) setting up configurations  
RUN  --mount=type=secret,id=LW_AGENT_ACCESS_TOKEN   \
      mkdir -p /var/log/lacework                 && \
      mkdir -p /var/lib/lacework/config          && \
      echo '{"tokens": {"accesstoken": "'$( cat /run/secrets/LW_AGENT_ACCESS_TOKEN)'"}}' > /var/lib/lacework/config/config.json  
############################################################

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]