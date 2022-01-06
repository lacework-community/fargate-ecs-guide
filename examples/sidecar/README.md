# Use a Sidecar (alternative installation)

While the [baked option](../baked-multistageRECOMMENDED/README.md) is **preferred**, a sidecar alternative is possible with additional effort.  
## Best practices

With this approach, the original application images stay in tact; therefore, users should modify the `TaskDefinition` to interpolate the Lacework agent and Lacework agent token. This is achieved by using a sidecar containing the Lacework agent script and adding an environment variable for the token. In addition, you should prepend the existing entrypoint/command with shell script to launch the Lacework agent.

## Prerequisites

* Needs `VolumesFrom` feature.
* Access to the underlying `Dockerfile`(s) as overriding the entrypoint/cmd depends on such.
* The application container must have the following packages installed: `openssl`, `ca-certificates`, and `curl/wget`.

## Installation steps 

### 1. Review [best practices](../../README.md#best-practices) and [prerequisites](../../README.md#prerequisites).

### 2. Upload image(s) to AWS ECR. 

### 3. [Upload main application](push-main.sh).

[Dockerfile](main.dockerfile)

  ```Dockerfile
  FROM ubuntu:latest

  RUN apt-get update && apt-get install -y \
      curl \
      jq \
      sed \
      && rm -rf /var/lib/apt/lists/*
  COPY docker-entrypoint.sh /
  RUN chmod +x /docker-entrypoint.sh

  ENTRYPOINT [ "/docker-entrypoint.sh" ]
  ```

[docker-entrypoint.sh](docker-entrypoint.sh)
  ```bash
  #!/bin/sh
  curl -s  https://stream.wikimedia.org/v2/stream/recentchange |   grep data |  sed 's/^data: //g' |  jq -rc 'with_entries(if .key == "$schema" then .key = "schema" else . end)'
  ```

#### 3a. [Build](build-main.sh) and push.

```bash
# Set variables for ECR
AWS_ECR_REGION="us-east-2"
AWS_ECR_URI="000000000000.dkr.ecr.us-east-2.amazonaws.com"
AWS_ECR_NAME="dianademo"

# Build and tag the image
docker build --force-rm=true --tag ${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-main .

# Log in to ECR (if logged out) and push the image
aws ecr get-login-password --region ${AWS_ECR_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ECR_URI}
docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-main"
```

### 4. Upload sidecar (optional).

This step enables you to have Lacework's official sidecar image in your environment. It is not required to upload Lacework’s sidecar image; however, if reaching out to Docker hub poses any blockers or additional complexity, it is recommended to upload the sidecar in your internal container registry.

```Dockerfile
FROM lacework/datacollector:latest-sidecar
```

#### 4a. [Build](build-sidecar.sh) and [push](build-sidecar.sh).

```bash
# Set variables for ECR
AWS_ECR_REGION="us-east-2"
AWS_ECR_URI="000000000000.dkr.ecr.us-east-2.amazonaws.com"
AWS_ECR_NAME="dianademo"

# Build and tag the image
docker build --force-rm=true --tag ${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-sidecar .

# Log in to ECR (if logged out) and push the image
aws ecr get-login-password --region ${AWS_ECR_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ECR_URI}
docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-sidecar"
```

### 5. Create and register the `TaskDefinition`.

This step adds details from the sidecar and main application containers. A full [TaskDefinition](taskDefinition.json) is necessary for this step; however, the extracted, relevant configurations are below. Please ensure anything in **bold** matches on your end.

See Lacework's [docs](https://support.lacework.com/hc/en-us/articles/360055567574#sidecar-based-deployment) for screenshots.

```bash
# Register the task definition
aws ecs register-task-definition --cli-input-json file://taskDefinition.json   
```

[Sidecar section](taskDefinition.json) (partially shown below)
  ```json
  {
    "name": "dianademo-sidecar",
    "image": "000000000000.dkr.ecr.us-east-2.amazonaws.com/dianademo:latest-sidecar",
    "cpu": 512,
    "memory": 1024,
    "essential": false,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/dianademo-sidecar",  
        "awslogs-region": "us-east-2",  
        "awslogs-stream-prefix": "sidecar" 
      }
    }
  }
  ```


[Main app section](taskDefinition.json) (partially shown below)
  ```json
  {
    "name": "dianademo-mainapp",
    "image": "000000000000.dkr.ecr.us-east-2.amazonaws.com/dianademo:latest-main",
    "cpu": 512,
    "memory": 1024,
    "essential": true,
    "command": [  
      "sh",  
      "-c",  
      "/var/lib/lacework-backup/lacework-sidecar.sh && /docker-entrypoint.sh"  
    ],  
    "environment": [  
        {  
            "name": "LaceworkAccessToken",  
            "value": "ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6"
        }
    ],  
    "volumesFrom": [  
      {  
          "sourceContainer": "dianademo-sidecar",  
          "readOnly": true  
      }  
    ],
    "dockerLabels": {  
      "Monitoring": "Lacework"  
    },  
    "dependsOn": [  
        {  
            "containerName": "dianademo-sidecar",  
            "condition": "SUCCESS"  
        }  
    ],    
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/dianademo-sidecar",  
        "awslogs-region": "us-east-2",  
        "awslogs-stream-prefix": "main" 
      }
    }
  }
  ```

### 6. Run the TaskDefinition

Once the task is created, you can either run it or creare a service around it. This can be performed in the AWS web console or via the CLI. The service’s task will be the one created in the previous step. An example of a simple service is [here](service.json).


## Appendix

### AWS examples

- [taskDefinition.json](taskDefinition.json); obtained via:
```bash
aws ecs describe-task-definition --task-definition arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-sidecar:1 > ~/lw/agent/fargate/fargate-ecs-guide/examples/sidecar/taskDefinition.json
```
- [service.json](service.json); obtained via:
```bash
aws ecs describe-services --services arn:aws:ecs:us-east-2:000000000000:service/dianademo-cluster/dianademo-sidecar --cluster dianademo-cluster  > ~/lw/agent/fargate/fargate-ecs-guide/examples/sidecar/service.json
```
