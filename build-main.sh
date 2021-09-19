#!/bin/sh

source vars.env
# if already got the LW CLI && logged in, else see appendix
export LW_AGENT_ACCESS_TOKEN=$(lacework agent token list | grep dianademo | cut -d" " -f3)
# Store the LW Agent Token in a file (See Requirements to obtain one)
echo ${LW_AGENT_ACCESS_TOKEN} > token.key

# Build and Tag the image
DOCKER_BUILDKIT=1 docker build --secret id=LW_AGENT_ACCESS_TOKEN,src=token.key --force-rm=true --tag "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-main"  -f main.dockerfile .

exit 0