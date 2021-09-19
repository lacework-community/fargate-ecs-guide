FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
   curl \
   jq \
   sed \
   && rm -rf /var/lib/apt/lists/*
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

RUN  LW_AGENT_ACCESS_TOKEN="ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6" && for asset_url in $(curl -s https://api.github.com/repos/lacework/lacework-agent-releases/releases/latest | jq --raw-output '.assets[]."browser_download_url"'); do \
    curl -OL ${asset_url}; done && \
    md5sum -c checksum.txt      && \
    lwagent=$(cat checksum.txt | cut -d' ' -f3) && \
    tar zxf $lwagent -C /tmp    && \
    cd /tmp/${lwagent%.*}       && \
    mkdir -p /var/lib/lacework/config/          && \
    echo '{"tokens": {"accesstoken": "'${LW_AGENT_ACCESS_TOKEN}'"}}' > /var/lib/lacework/config/config.json            && \
    /usr/bin/sh install.sh      && \
    cd ~                        && \
    rm -rf /tmp/${lwagent%.*}

ENTRYPOINT [ "/docker-entrypoint.sh" ]