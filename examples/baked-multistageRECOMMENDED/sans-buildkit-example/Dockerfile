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
RUN   LW_AGENT_ACCESS_TOKEN="ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6" && \
      mkdir -p /var/log/lacework                 && \
      mkdir -p /var/lib/lacework/config          && \
      echo '{"tokens": {"accesstoken": "'${LW_AGENT_ACCESS_TOKEN}'"}}' > /var/lib/lacework/config/config.json  
############################################################

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT [ "/docker-entrypoint.sh" ]