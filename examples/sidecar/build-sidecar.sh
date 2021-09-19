#!/bin/sh
source vars.env
# Build and Tag the image
docker build  --force-rm=true --tag "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-sidecar" -f sidecar.dockerfile .
exit 0
