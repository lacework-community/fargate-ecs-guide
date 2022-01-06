
# Bake the Lacework Agent in the Docker Image Using Multistage Builds (preferred method) 

There are a few options to bake the Lacework agent. Downloading the agent at run time will result in a longer startup time than installing and preconfiguring it in the image. 

**Therefore, we recommend directly installing the Lacework agent in your existing Docker image via multistage builds as shown below.**

## Installation steps 

### 1. Review [best practices](../../README.md#best-practices) and [prerequisites](../../README.md#prerequisites)

### 2. Add the agent to your existing Dockerfile

Modify your existing Dockerfile in to add the Lacework agent by following these steps: 

#### 2a. Add a build stage
#### 2b. Copy the binary
#### 2c. Set up configurations

In the docker-entrypoint script, add a line to: 

#### 2d. Run the agent 

#### Example (with BuildKit)

Below is an example of a _very_ simple Dockerfile along with its entrypoint script. This example prettyprints real-time Wikipedia recent changes. We also added three lines and comments indicating the Lacework agent additions.

[Dockerfile](multi.dockerfile)
  ```Dockerfile
  # syntax=docker/dockerfile:1
  ### Lacework agent (step 2a) add a build stage ######################
  FROM lacework/datacollector:latest AS agent-build-image
  ############################################################

  FROM ubuntu:latest
  RUN apt-get update && apt-get install -y \
    curl \
    jq \
    sed \
    && rm -rf /var/lib/apt/lists/*

  ### Lacework agent (step 2b) copy the binary  #######################
  COPY --from=agent-build-image  /var/lib/backup/*/datacollector /var/lib/lacework/datacollector
  ### Lacework agent (step 2c) set up configurations  
  RUN  --mount=type=secret,id=LW_AGENT_ACCESS_TOKEN    \
        mkdir -p /var/log/lacework/                 && \
        mkdir -p /var/lib/lacework/config/          && \
        echo '{"tokens": {"accesstoken": "'$( cat /run/secrets/LW_AGENT_ACCESS_TOKEN)'"}}' > /var/lib/lacework/config/config.json  
  ############################################################

  COPY docker-entrypoint.sh /
  RUN chmod +x /docker-entrypoint.sh
  ENTRYPOINT [ "/docker-entrypoint.sh" ]
  ```

[Entrypoint script](docker-entrypoint.sh)
  ```bash
  #!/bin/sh
  ### Lacework agent (step 2d) copy the binary  #######################
  ./var/lib/lacework/datacollector &

  curl -s  https://stream.wikimedia.org/v2/stream/recentchange |   grep data |  sed 's/^data: //g' |  jq -rc 'with_entries(if .key == "$schema" then .key = "schema" else . end)'
```

Notes: 
* The <code>RUN</code></strong> command uses [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) to securely pass the Lacework agent token as <code>LW_AGENT_ACCESS_TOKEN</code>. This is <em>not</em> necessary but <strong>recommended</strong>. For an example <em>sans</em> the BuildKit, see the [Sans BuildKit folder](sans-buildkit-example/README.md).
* It’s also possible to install the Lacework agent by fetching and installing the binaries from our official Github repository. Steps for this approach are found in the [GitHub build example](../baked-github-build/README.md).
* Optionally, some customers choose to upload the `lacework/datacollector:latest` to their ECR. 

### 3. [Build](build-multi.sh) and [push](push-multi.sh)

Now that the image is modified, you can upload the changes to ECR by:

#### 3a. Rebuilding the image
#### 3b. Pushing the changes to AWS ECR

#### Example (with BuildKit)

  ```bash
  #!/bin/sh

  # Set variables for ECR
  export AWS_ECR_REGION="us-east-2"
  export AWS_ECR_URI="000000000000.dkr.ecr.us-east-2.amazonaws.com"
  export AWS_ECR_NAME="dianademo"

  # Store the Lacework agent token in a file (See Requirements to obtain one)
  echo "ae83fc1d3f79f8f84b3512688b5b6b98f33f6688fa4c67931afae9a6" > token.key

  # Build and tag the image
  DOCKER_BUILDKIT=1 docker build --secret id=LW_AGENT_ACCESS_TOKEN,src=token.key --force-rm=true --tag "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-baked" .

  # Log in to ECR and push the image
  aws ecr get-login-password --region ${AWS_ECR_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_URI}
  docker push "${AWS_ECR_URI}/${AWS_ECR_NAME}:latest-baked"
  ```

### 4. Run 

Now you have finished making custom changes to add the Lacework agent. This step involves running the container as you typically would. 

#### Example of a task definition service

To run the image, AWS requires configuration of an ECS [task definition](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html). A simple example is available [here](taskDefinition.json). For more examples, visit [AWS documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/example_task_definitions.html).

```bash
# Create a cluster. You only need to do this once.
aws ecs create-cluster --cluster-name dianademo-cluster 

# Register the task definition
aws ecs register-task-definition --cli-input-json file://taskDefinition.json   
```

Either create a service or run the task. Below we create a service through the AWS web console and also present the JSON output [here](service.json) for reference. 

```bash
# Create a service (or run task) 
## Follow the AWS Wizard
open https://us-east-2.console.aws.amazon.com/ecs/home?region=us-east-2#/clusters/dianademo-cluster/createService 

## OR provide JSON definition of the service
aws ecs create-service --cli-input-json file://service.json   

# View service
aws ecs list-services --cluster dianademo-cluster 
```
