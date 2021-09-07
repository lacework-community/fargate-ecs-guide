
# LW Agent + AWS Fargate Guide <!-- omit in toc -->

**August 2021**

- [Overview](#overview)
- [Best Practices](#best-practices)
- [Requirements](#requirements)
- [Installation Steps](#installation-steps)
  - [Preferred Installation: LW Agent Baked in the Docker Image](#preferred-installation-lw-agent-baked-in-the-docker-image)
    - [Step 1: Copy RUN command to existing `Dockerfile`](#step-1-copy-run-command-to-existing-dockerfile)
      - [one-liner RUN command (with BuildKit)](#one-liner-run-command-with-buildkit)
      - [Example](#example)
    - [Step 2: Build, Tag, & Push](#step-2-build-tag--push)
    - [Step 3: Run](#step-3-run)
  - [Alternative Installation: Use a sidecar](#alternative-installation-use-a-sidecar)
    - [Additional Requirements](#additional-requirements)
    - [Step 1: Upload image(s) to AWS ECR](#step-1-upload-images-to-aws-ecr)
      - [Step 1A: Upload Main Application](#step-1a-upload-main-application)
      - [Step 1B: Upload Sidecar (Optional)](#step-1b-upload-sidecar-optional)
    - [Step 2: Create & Register the `TaskDefinition`](#step-2-create--register-the-taskdefinition)
    - [Step 3: Run the TaskDefinition](#step-3-run-the-taskdefinition)
- [Appendix](#appendix)
  - [Installing the LW CLI and Creating and LW Agent Token](#installing-the-lw-cli-and-creating-and-lw-agent-token)
  - [Dockerfile sans BuildKit Example](#dockerfile-sans-buildkit-example)
  - [AWS ECS Task Definition Examples](#aws-ecs-task-definition-examples)
    - [taskDefinition.json](#taskdefinitionjson)
    - [taskDefinition-sidecar.json](#taskdefinition-sidecarjson)
  - [AWS ECS Service Examples](#aws-ecs-service-examples)
    - [bakedService.json](#bakedservicejson)
    - [sidecarService.json](#sidecarservicejson)
  - [AWS AmazonECSTaskExecutionRolePolicy](#aws-amazonecstaskexecutionrolepolicy)

# Overview

Two options are available when installing the LW Agent in AWS Fargate. Both are presented below. We highly recommend leveraging the [first option highlighted](#preferred-installation-lw-agent-baked-in-the-docker-image) as it pre-installs and configures the agent _directly_ in the Docker Image.

# Best Practices

* Install the LW Agent via our [GitHub Release repository](https://github.com/lacework/lacework-agent-releases). Jump to the [Installation](#installation-steps) section below to view steps.
* “Bake” the agent directly into the Docker images. This avoids the alternative of installing the agent dynamically during the initial runtime launch.
* Securely pass in the LW Agent Token when building the Docker image. This may be achieved using [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/).
* Each LW Agent needs 512MB vCPU and 1GB RAM. 

# Requirements

* The base image in your Dockerfile must be based on one of the Linux distros found [here](https://support.lacework.com/hc/en-us/articles/360005230014).  And you must be able to install curl, openssl, and ca-certificates, if they are not already included in the base image.  The example provided in this document is Ubuntu.  You will need to first determine the Linux distro used by your base image, identify the package manager used by that distro, and install the needed dependencies as part of your Dockerfile.
* As the LW Agent user gathers network packet data, it needs to be run with **<code>sudo</code></strong> privileges. The LW Agent must be run as <strong><code>root</code></strong>
* Have valid Access Token(s) for the LW Agent(s). These may be obtained at via the [LW CLI](https://github.com/lacework/go-sdk/wiki/CLI-Documentation#agent-access-token-management) (see [Appendix](#installing-the-lw-cli-and-creating-and-lw-agent-token) for a simple example) or at <code>[https://](https://YOUR-ORG.lacework.net/ui/investigation/settings)<strong><span style="text-decoration:underline;">YOUR-ORG[.lacework.net/ui/investigation/settings](https://YOUR-ORG.lacework.net/ui/investigation/settings)</span></strong>  </code>
* IAM User used needs permissions listed in [AmazonECSTaskExecutionRolePolicy](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy$jsonEditor)
* LW Agent needs to reach Lacework’s API endpoint.  Default: [https://api.lacework.net](https://api.lacework.net). See [here](https://support.lacework.com/hc/en-us/articles/1500007918841-Agent-Server-URL) for other endpoints.
* If leveraging the sidecar alternative, review [additional requirements](#additional-requirements).

# Installation Steps 

Below are the two options to install the LW Agent in AWS Fargate.

## Preferred Installation: LW Agent Baked in the Docker Image  

Note: Ensure to replace placeholders

This option downloads our latest LW Agent from the official github repository. The installation script will determine the underlying OS and install the appropriate package. 

There are a few options on how to bake our agent. While you could technically download the agent at run time, this would typically result in a longer startup time as opposed to having the agent installed and preconfigured in the image for quicker boot times.

For optimization, a one-liner to getting the LW Agent installed is presented below. This effectively collapses the 14+ steps listed in our documentation [here](https://support.lacework.com/hc/en-us/articles/360023100733-Install-from-APT-and-YUM-Repositories). It may be appended to an existing `RUN` command via `&&`’s. Alternatively, it may be added as a new `RUN` command.

Notes:

* The example assumes the following are available: <code>curl, jq </code>
* The <strong><code>RUN</code></strong> command uses [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) to securely pass the LW Agent Token as <code>LW_AGENT_ACCESS_TOKEN</code>. This is not necessary but recommended. For an example <em>sans</em> the BuildKit see the [Appendix](#appendix) section.
* 

### Step 1: Copy [RUN command](#one-liner-run-command-with-buildkit) to existing `Dockerfile`

#### one-liner RUN command (with BuildKit) 

```Dockerfile
RUN --mount=type=secret,id=LW_AGENT_ACCESS_TOKEN for asset_url in $(curl -s https://api.github.com/repos/lacework/lacework-agent-releases/releases/latest | jq --raw-output '.assets[]."browser_download_url"'); do \
    curl -OL ${asset_url}; done && \
    md5sum -c checksum.txt      && \
    lwagent=$(cat checksum.txt | cut -d' ' -f3) && \
    tar zxf $lwagent -C /tmp    && \
    cd /tmp/${lwagent%.*}       && \
    mkdir -p /var/lib/lacework/config/          && \
    echo '{"tokens": {"accesstoken": "'$( cat /run/secrets/LW_AGENT_ACCESS_TOKEN)'"}}' > /var/lib/lacework/config/config.json            && \
    /usr/bin/sh install.sh      && \
    cd ~                        && \
    rm -rf /tmp/${lwagent%.*}
```

#### Example 

Below is a full example of a _very_ simple `Dockerfile` along with its `docker-entrypoint.sh`. This example pretty prints real-time Wikipedia recent changes.

```Dockerfile
FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
   curl \
   jq \
   sed \
   && rm -rf /var/lib/apt/lists/*
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

##
## add the above one-liner RUN command to bake in the LW Agent here:) 
##

ENTRYPOINT [ "/docker-entrypoint.sh" ]
```

```bash
#!/bin/sh
curl -s  https://stream.wikimedia.org/v2/stream/recentchange |   grep data |  sed 's/^data: //g' |  jq -rc 'with_entries(if .key == "$schema" then .key = "schema" else . end)'
```

### Step 2: Build, Tag, & Push 

```bash
# Set variables for ECR
export AWS_ECR_REGION="us-east-2"
export AWS_ECR_URI="000000000000.dkr.ecr.us-east-2.amazonaws.com"
export AWS_ECR_NAME="dianademo"

# Store the LW Agent Token in a file (See Requirements to obtain one)
echo "ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6" > token.key

# Build and Tag the image
DOCKER_BUILDKIT=1 docker build --secret id=LW_AGENT_ACCESS_TOKEN,src=token.key --force-rm=true --tag "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-baked" .

# Log in to ECR and Push the image
aws ecr get-login-password --region ${AWS_ECR_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_URI}
docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-baked"
```

### Step 3: Run  

To run the image, AWS requires the configuration of an ECS [Task Definition](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html). A very simple example is available in the [Appendix](#taskdefinition-json). For more examples, visit the [AWS documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/example_task_definitions.html).

```bash
# Create a cluster. You only need to do this once.
aws ecs create-cluster --cluster-name dianademo-cluster 

# Register the task definition
aws ecs register-task-definition --cli-input-json file://taskDefinition.json   
```

The next step is to either create a service or simply run the task. Below we create a service through the AWS web console and also present the **<code>json</code></strong> output of the service in the [Appendix](#bakedservice-json) for reference. 

```bash
# Create a Service (or Run Task) 
## Follow the AWS Wizard
open https://us-east-2.console.aws.amazon.com/ecs/home?region=us-east-2#/clusters/dianademo-cluster/createService 

## OR provide json definition of the service
aws ecs create-service --cli-input-json file://bakedService.json   

# View Service
aws ecs list-services --cluster dianademo-cluster 
```

## Alternative Installation: Use a sidecar 

While the aforementioned option is **preferred**, a sidecar alternative is also possible with additional effort.  

With this approach, the original application images stay intact so we instead modify the TaskDefinition to interpolate the LW Agent and LW Agent token. This is achieved by using a sidecar containing the LW Agent script and adding an environment variable for the token. In addition, we prepend the existing entrypoint/command with shell script to launch the LW Agent. See below for reference examples.

### Additional Requirements 

* Needs VolumesFrom feature
* Ensure AmazonECSTaskExecutionRolePolicy is as shown on the [Appendix](#aws-ecs-service-examples)

### Step 1: Upload image(s) to AWS ECR 

#### Step 1A: Upload Main Application 
- Dockerfile
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
- `docker-entrypoint.sh`
  ```bash
  #!/bin/sh
  curl -s  https://stream.wikimedia.org/v2/stream/recentchange |   grep data |  sed 's/^data: //g' |  jq -rc 'with_entries(if .key == "$schema" then .key = "schema" else . end)'
  ```

- Build/Tag & Push
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


- Dockerfile
  ```Dockerfile
  FROM lacework/datacollector:latest-sidecar
  ```

- Build/Tag & Push
  ```bash
  # Set variables for ECR
  ```bash
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

In this step, we’ll be adding details from our sidecar and main application containers.  Though we need to provide a full [TaskDefinition](#taskdefinition-sidecar-json), below are the extracted, relevant configurations. Please ensure anything in **bold** matches on your end.

- Register the task definition
  ```bash
  # Register the task definition
  aws ecs register-task-definition --cli-input-json file://taskDefinition-sidecar.json   
  ```
- Sidecar Container Definition (partial)
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
- Main App Container Definition (partial)
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

Once the task is created we can run it or create a service around it. This can be done in the aws web console or via the cli. The service’s task will be the one we just created in the previous step. An example of a simple service is in the [Appendix](#sidecarservice-json).

# Appendix 

## Installing the LW CLI and Creating and LW Agent Token 

Follow steps listed in our [documentation here](https://github.com/lacework/go-sdk/wiki/CLI-Documentation#installation).

```bash
curl https://raw.githubusercontent.com/lacework/go-sdk/main/cli/install.sh | bash
lacework configure --json_file ~/Downloads/*.json
lacework agent token create dianademo
lacework agent token list | grep dianademo
```

## Dockerfile sans BuildKit Example 

```Dockerfile
FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
   curl \
   jq \
   sed \
   && rm -rf /var/lib/apt/lists/*
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

RUN  LW_AGENT_ACCESS_TOKEN="ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6" && for asset_url in $(curl -s https://api.github.com/repos/lacework/lacework-agent-releases/releases/latest | jq --raw-output '.assets[]."browser_download_url"'); do
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
```

## AWS ECS Task Definition Examples 

### taskDefinition.json 

```json
{
  "ipcMode": null,
  "executionRoleArn": "arn:aws:iam::000000000000:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "dnsSearchDomains": null,
      "environmentFiles": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/dianademo-baked",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "entryPoint": null,
      "portMappings": [
        {
          "hostPort": 80,
          "protocol": "tcp",
          "containerPort": 80
        }
      ],
      "command": null,
      "linuxParameters": null,
      "cpu": 0,
      "environment": [],
      "resourceRequirements": null,
      "ulimits": null,
      "dnsServers": null,
      "mountPoints": [],
      "workingDirectory": null,
      "secrets": null,
      "dockerSecurityOptions": null,
      "memory": null,
      "memoryReservation": null,
      "volumesFrom": [],
      "stopTimeout": null,
      "image": "000000000000.dkr.ecr.us-east-2.amazonaws.com/dianademo:latest-baked",
      "startTimeout": null,
      "firelensConfiguration": null,
      "dependsOn": null,
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": true,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": null,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": null,
      "name": "dianademo-baked"
    }
  ],
  "placementConstraints": [],
  "memory": "512",
  "taskRoleArn": "arn:aws:iam::000000000000:role/ecsTaskExecutionRole",
  "compatibilities": [
    "EC2",
    "FARGATE"
  ],
  "taskDefinitionArn": "arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-baked:1",
  "family": "dianademo-baked",
  "requiresAttributes": [
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.execution-role-awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.ecr-auth"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.task-iam-role"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.execution-role-ecr-pull"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.18"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.task-eni"
    }
  ],
  "pidMode": null,
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "networkMode": "awsvpc",
  "cpu": "256",
  "revision": 2,
  "status": "ACTIVE",
  "inferenceAccelerators": null,
  "proxyConfiguration": null,
  "volumes": []
}
```

### taskDefinition-sidecar.json 

```json
{
  "ipcMode": null,
  "executionRoleArn": "arn:aws:iam::000000000000:role/ecsInstanceRole",
  "containerDefinitions": [
    {
      "dnsSearchDomains": null,
      "environmentFiles": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/dianademo-sidecar",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "entryPoint": null,
      "portMappings": [],
      "command": null,
      "linuxParameters": null,
      "cpu": 0,
      "environment": [],
      "resourceRequirements": null,
      "ulimits": null,
      "dnsServers": null,
      "mountPoints": [],
      "workingDirectory": null,
      "secrets": null,
      "dockerSecurityOptions": null,
      "memory": null,
      "memoryReservation": null,
      "volumesFrom": [],
      "stopTimeout": null,
      "image": "000000000000.dkr.ecr.us-east-2.amazonaws.com/dianademo:latest-sidecar",
      "startTimeout": null,
      "firelensConfiguration": null,
      "dependsOn": null,
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": false,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": null,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": null,
      "name": "dianademo-sidecar"
    },
    {
      "dnsSearchDomains": null,
      "environmentFiles": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "/ecs/dianademo-sidecar",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "entryPoint": [
        "sh",
        "-c"
      ],
      "portMappings": [
        {
          "hostPort": 80,
          "protocol": "tcp",
          "containerPort": 80
        }
      ],
      "command": [
        "/var/lib/lacework-backup/lacework-sidecar.sh && /docker-entrypoint.sh"
      ],
      "linuxParameters": null,
      "cpu": 0,
      "environment": [
        {
          "name": "LaceworkAccessToken",
          "value": "ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6"
        }
      ],
      "resourceRequirements": null,
      "ulimits": null,
      "dnsServers": null,
      "mountPoints": [],
      "workingDirectory": null,
      "secrets": null,
      "dockerSecurityOptions": null,
      "memory": null,
      "memoryReservation": null,
      "volumesFrom": [
        {
          "sourceContainer": "dianademo-sidecar",
          "readOnly": true
        }
      ],
      "stopTimeout": null,
      "image": "000000000000.dkr.ecr.us-east-2.amazonaws.com/dianademo:latest-main",
      "startTimeout": null,
      "firelensConfiguration": null,
      "dependsOn": [
        {
          "containerName": "dianademo-sidecar",
          "condition": "SUCCESS"
        }
      ],
      "disableNetworking": null,
      "interactive": null,
      "healthCheck": null,
      "essential": true,
      "links": null,
      "hostname": null,
      "extraHosts": null,
      "pseudoTerminal": null,
      "user": null,
      "readonlyRootFilesystem": null,
      "dockerLabels": null,
      "systemControls": null,
      "privileged": null,
      "name": "dianademo-main"
    }
  ],
  "placementConstraints": [],
  "memory": "1024",
  "taskRoleArn": "arn:aws:iam::000000000000:role/ecsInstanceRole",
  "compatibilities": [
    "EC2",
    "FARGATE"
  ],
  "taskDefinitionArn": "arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-sidecar:1",
  "family": "dianademo-sidecar",
  "requiresAttributes": [
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.execution-role-awslogs"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.ecr-auth"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.task-iam-role"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.container-ordering"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.execution-role-ecr-pull"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "com.amazonaws.ecs.capability.docker-remote-api.1.18"
    },
    {
      "targetId": null,
      "targetType": null,
      "value": null,
      "name": "ecs.capability.task-eni"
    }
  ],
  "pidMode": null,
  "requiresCompatibilities": [
    "FARGATE"
  ],
  "networkMode": "awsvpc",
  "cpu": "512",
  "revision": 1,
  "status": "ACTIVE",
  "inferenceAccelerators": null,
  "proxyConfiguration": null,
  "volumes": []
}
```

## AWS ECS Service Examples 

### bakedService.json 

```json
// aws ecs describe-services --service dianademo-baked --cluster dianademo-cluster  > bakedService.json
{
    "services": [
        {
            "serviceArn": "arn:aws:ecs:us-east-2:000000000000:service/dianademo-cluster/dianademo-baked",
            "serviceName": "dianademo-baked",
            "clusterArn": "arn:aws:ecs:us-east-2:000000000000:cluster/dianademo-cluster",
            "loadBalancers": [],
            "serviceRegistries": [],
            "status": "ACTIVE",
            "desiredCount": 1,
            "runningCount": 1,
            "pendingCount": 0,
            "launchType": "FARGATE",
            "platformVersion": "LATEST",
            "taskDefinition": "arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-baked:2",
            "deploymentConfiguration": {
                "deploymentCircuitBreaker": {
                    "enable": false,
                    "rollback": false
                },
                "maximumPercent": 200,
                "minimumHealthyPercent": 100
            },
            "deployments": [
                {
                    "id": "ecs-svc/5386320934964759578",
                    "status": "PRIMARY",
                    "taskDefinition": "arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-baked:2",
                    "desiredCount": 1,
                    "pendingCount": 0,
                    "runningCount": 1,
                    "failedTasks": 0,
                    "createdAt": "2021-08-25T10:45:52.807000-05:00",
                    "updatedAt": "2021-08-25T11:34:27.579000-05:00",
                    "launchType": "FARGATE",
                    "platformVersion": "1.4.0",
                    "networkConfiguration": {
                        "awsvpcConfiguration": {
                            "subnets": [
                                "subnet-0e9ee9e68b696cd87"
                            ],
                            "securityGroups": [
                                "sg-0ef05399277d4814f"
                            ],
                            "assignPublicIp": "ENABLED"
                        }
                    },
                    "rolloutState": "COMPLETED",
                    "rolloutStateReason": "ECS deployment ecs-svc/5386320934964759578 completed."
                }
            ],
            "roleArn": "arn:aws:iam::680354150194:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS",
            "events": [
                {
                    "id": "db4e95ac-d3eb-4280-9a92-b9eef67a7a7c",
                    "createdAt": "2021-08-25T11:34:27.584000-05:00",
                    "message": "(service dianademo-baked) has reached a steady state."
                },
                {
                    "id": "c5194fdf-e3e1-46db-8c41-8b5564bbeff4",
                    "createdAt": "2021-08-25T11:33:55.648000-05:00",
                    "message": "(service dianademo-baked) has started 1 tasks: (task 47d3c8816dc14883b49fdd8da1b9f130)."
                },
                {
                    "id": "0e8984fc-cef7-464a-9954-8a7bb02d7421",
                    "createdAt": "2021-08-25T11:18:15.986000-05:00",
                    "message": "(service dianademo-baked) has reached a steady state."
                },
                {
                    "id": "7c923ead-6b51-4da9-bbbe-189167a82e09",
                    "createdAt": "2021-08-25T11:17:52.616000-05:00",
                    "message": "(service dianademo-baked) has started 1 tasks: (task 8d62f0e5065449f4ae503ec74693a95f)."
                },
                {
                    "id": "d11cf91a-8ac0-4b58-9afd-2551787b2bf8",
                    "createdAt": "2021-08-25T11:02:24.603000-05:00",
                    "message": "(service dianademo-baked) has reached a steady state."
                },
                {
                    "id": "672f55f4-aa8a-4af1-b3c3-855b1e44e1f0",
                    "createdAt": "2021-08-25T11:01:54.222000-05:00",
                    "message": "(service dianademo-baked) has started 1 tasks: (task 3eecb6f40ff54504a8b01e5685fadd27)."
                },
                {
                    "id": "8951beba-dda0-45ad-b2dd-9548b2f8ddf3",
                    "createdAt": "2021-08-25T10:46:22.059000-05:00",
                    "message": "(service dianademo-baked) has reached a steady state."
                },
                {
                    "id": "a8761e3e-025f-4189-94a6-d1a1f076d7a1",
                    "createdAt": "2021-08-25T10:46:22.058000-05:00",
                    "message": "(service dianademo-baked) (deployment ecs-svc/5386320934964759578) deployment completed."
                },
                {
                    "id": "0b6f0c5b-099b-4202-9c47-82f5426791f5",
                    "createdAt": "2021-08-25T10:45:58.591000-05:00",
                    "message": "(service dianademo-baked) has started 1 tasks: (task 0176035e168e419c84222dff14facbd0)."
                }
            ],
            "createdAt": "2021-08-25T10:45:52.807000-05:00",
            "placementConstraints": [],
            "placementStrategy": [],
            "networkConfiguration": {
                "awsvpcConfiguration": {
                    "subnets": [
                        "subnet-0e9ee9e68b696cd87"
                    ],
                    "securityGroups": [
                        "sg-0ef05399277d4814f"
                    ],
                    "assignPublicIp": "ENABLED"
                }
            },
            "schedulingStrategy": "REPLICA",
            "createdBy": "arn:aws:iam::000000000000:role/lacework-cs1-admin-role",
            "enableECSManagedTags": true,
            "propagateTags": "TASK_DEFINITION",
            "enableExecuteCommand": false
        }
    ],
    "failures": []
}
```

### sidecarService.json 

```json
// aws ecs describe-services --service dianademo-sidecar --cluster dianademo-cluster  > sidecarService.json
{
    "services": [
        {
            "serviceArn": "arn:aws:ecs:us-east-2:000000000000:service/dianademo-cluster/dianademo-sidecar",
            "serviceName": "dianademo-sidecar",
            "clusterArn": "arn:aws:ecs:us-east-2:000000000000:cluster/dianademo-cluster",
            "loadBalancers": [],
            "serviceRegistries": [],
            "status": "ACTIVE",
            "desiredCount": 1,
            "runningCount": 1,
            "pendingCount": 0,
            "launchType": "FARGATE",
            "platformVersion": "LATEST",
            "taskDefinition": "arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-sidecar:1",
            "deploymentConfiguration": {
                "deploymentCircuitBreaker": {
                    "enable": false,
                    "rollback": false
                },
                "maximumPercent": 200,
                "minimumHealthyPercent": 100
            },
            "deployments": [
                {
                    "id": "ecs-svc/5130863164295611656",
                    "status": "PRIMARY",
                    "taskDefinition": "arn:aws:ecs:us-east-2:000000000000:task-definition/dianademo-sidecar:1",
                    "desiredCount": 1,
                    "pendingCount": 0,
                    "runningCount": 1,
                    "failedTasks": 0,
                    "createdAt": "2021-08-25T11:21:20.634000-05:00",
                    "updatedAt": "2021-08-25T11:38:00.778000-05:00",
                    "launchType": "FARGATE",
                    "platformVersion": "1.4.0",
                    "networkConfiguration": {
                        "awsvpcConfiguration": {
                            "subnets": [
                                "subnet-0e9ee9e68b696cd87"
                            ],
                            "securityGroups": [
                                "sg-0ef05399277d4814f"
                            ],
                            "assignPublicIp": "ENABLED"
                        }
                    },
                    "rolloutState": "COMPLETED",
                    "rolloutStateReason": "ECS deployment ecs-svc/5130863164295611656 completed."
                }
            ],
            "roleArn": "arn:aws:iam::000000000000:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS",
            "events": [
                {
                    "id": "966c51a3-e6ac-4625-a259-92845bacb95f",
                    "createdAt": "2021-08-25T11:38:00.784000-05:00",
                    "message": "(service dianademo-sidecar) has reached a steady state."
                },
                {
                    "id": "fee7f5d6-eafd-47cf-ba39-4cb8949c91ff",
                    "createdAt": "2021-08-25T11:37:29.272000-05:00",
                    "message": "(service dianademo-sidecar) has started 1 tasks: (task 023f0074d36a403ba94b57d5d9567b22)."
                },
                {
                    "id": "aabdd23b-af81-4ce7-b12b-c34ed178ddc1",
                    "createdAt": "2021-08-25T11:21:55.868000-05:00",
                    "message": "(service dianademo-sidecar) has reached a steady state."
                },
                {
                    "id": "0075ac10-43bf-4a08-b212-d558d0d0f741",
                    "createdAt": "2021-08-25T11:21:55.867000-05:00",
                    "message": "(service dianademo-sidecar) (deployment ecs-svc/5130863164295611656) deployment completed."
                },
                {
                    "id": "475e3ac0-60d0-4bc8-ab45-e1fc1c4aa7ae",
                    "createdAt": "2021-08-25T11:21:23.927000-05:00",
                    "message": "(service dianademo-sidecar) has started 1 tasks: (task b9070446356944c294a94942dbccdebb)."
                }
            ],
            "createdAt": "2021-08-25T11:21:20.634000-05:00",
            "placementConstraints": [],
            "placementStrategy": [],
            "networkConfiguration": {
                "awsvpcConfiguration": {
                    "subnets": [
                        "subnet-0e9ee9e68b696cd87"
                    ],
                    "securityGroups": [
                        "sg-0ef05399277d4814f"
                    ],
                    "assignPublicIp": "ENABLED"
                }
            },
            "schedulingStrategy": "REPLICA",
            "createdBy": "arn:aws:iam::000000000000:role/lacework-cs1-admin-role",
            "enableECSManagedTags": true,
            "propagateTags": "NONE",
            "enableExecuteCommand": false
        }
    ],
    "failures": []
}
```

## AWS AmazonECSTaskExecutionRolePolicy 

```json
{  
 "Version": "2012-10-17",  
 "Statement": [  
   {  
     "Effect": "Allow",  
     "Action": [  
       "ecr:GetAuthorizationToken",  
       "ecr:BatchCheckLayerAvailability",  
       "ecr:GetDownloadUrlForLayer",  
       "ecr:BatchGetImage",  
       "logs:CreateLogStream",  
       "logs:PutLogEvents"  
     ],  
     "Resource": "*"  
   }  
 ]  
}  
```
