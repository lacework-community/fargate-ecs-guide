#!/bin/sh
source vars.env
# Log in to ECR and Push the image
aws ecr get-login-password --region ${AWS_ECR_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_URI}
docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-baked"