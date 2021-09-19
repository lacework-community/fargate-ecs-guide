FROM ubuntu:latest

COPY docker-entrypoint.sh /

RUN --mount=type=secret,id=LW_AGENT_ACCESS_TOKEN \ 
    apt-get update                     && \
    apt-get install -y                    \
      curl                                \
      jq                                  \
      sed                              && \
    rm -rf /var/lib/apt/lists/*        && \
    for asset_url in $(curl -s https://api.github.com/repos/lacework/lacework-agent-releases/releases/latest | jq --raw-output '.assets[]."browser_download_url"'); do \
      curl -OL ${asset_url}; done      && \
    md5sum -c checksum.txt             && \
    lwagent=$(cat checksum.txt | cut -d' ' -f3) && \
    tar zxf $lwagent -C /tmp           && \
    cd /tmp/${lwagent%.*}              && \
    mkdir -p /var/lib/lacework/config/ && \
    echo '{"tokens": {"accesstoken": "'$( cat /run/secrets/LW_AGENT_ACCESS_TOKEN)'"}}' > /var/lib/lacework/config/config.json && \
    sh install.sh                      && \
    cd ~                               && \
    rm -rf /tmp/${lwagent%.*}          && \ 
    chmod +x /docker-entrypoint.sh

ENTRYPOINT [ "/docker-entrypoint.sh" ]