# Alternative Installation
## Use a Sidecar

While the [baked option](../baked-multistageRECOMMENDED/README.md) is **preferred**, a sidecar alternative is also possible with additional effort.  

With this approach, the original application images stay intact so we instead modify the `TaskDefinition` to interpolate the LW Agent and LW Agent Token. This is achieved by using a sidecar containing the LW Agent script and adding an environment variable for the token. In addition, we prepend the existing entrypoint/command with shell script to launch the LW Agent. See below for reference examples.

### Additional Requirements

* Needs `VolumesFrom` feature
* Access to the underlying `Dockerfile`(s) as overriding the entrypoint/cmd is dependent on such.
* The application container must have the following packages installed: `openssl`, `ca-certificates`, and `curl/wget`.


## Installation Steps 

### Step 0: Review [Best Practices](../../README.md#best-practices) & [General Requirements](../../README.md#requirements)

### Step 1: Upload image(s) to AWS ECR

#### Step 1A: [Upload Main Application](push-main.sh)

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

[Build](build-main.sh) & Push

```bash
# Set variables for ECR
AWS_ECR_REGION="us-east-2"
AWS_ECR_URI="000000000000.dkr.ecr.us-east-2.amazonaws.com"
AWS_ECR_NAME="dianademo"

# Build and Tag the image
docker build --force-rm=true --tag ${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-main .

# Log in to ECR (if logged out) and Push the image
aws ecr get-login-password --region ${AWS_ECR_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ECR_URI}
docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-main"
```

#### Step 1B: Upload Sidecar (Optional)

This steps allows you to have Laceworks official sidecar image in your environment. It is not required to upload Lacework’s sidecar image, however, if reaching out to docker hub poses any blockers or additional complexity, it is recommended to upload the side car in your internal Container Registry.

```Dockerfile
FROM lacework/datacollector:latest-sidecar
```

[Build](build-sidecar.sh) & [Push](build-sidecar.sh)

```bash
# Set variables for ECR
AWS_ECR_REGION="us-east-2"
AWS_ECR_URI="000000000000.dkr.ecr.us-east-2.amazonaws.com"
AWS_ECR_NAME="dianademo"

# Build and Tag the image
docker build --force-rm=true --tag ${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-sidecar .

# Log in to ECR (if logged out) and Push the image
aws ecr get-login-password --region ${AWS_ECR_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ECR_URI}
docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-sidecar"
```

### Step 2: Create & Register the `TaskDefinition`

In this step, we’ll be adding details from our sidecar and main application containers.  Though we need to provide a full [TaskDefinition](taskDefinition.json), below are the extracted, relevant configurations. Please ensure anything in **bold** matches on your end.

See our [docs](https://support.lacework.com/hc/en-us/articles/360055567574#sidecar-based-deployment) for screenshots.

### Step 2a: Register the task definition

```bash
# Register the task definition
aws ecs register-task-definition --cli-input-json file://taskDefinition-sidecar.json   
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


[Main App section](taskDefinition.json) (partially shown below)
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

### Step 3: Run the TaskDefinition

Once the task is created we can run it or create a service around it. This can be done in the aws web console or via the cli. The service’s task will be the one we just created in the previous step. An example of a simple service is [here](service.json).

