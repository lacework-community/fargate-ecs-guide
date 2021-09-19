
# Preferred Installation
## "Baked" the LW Agent in the Docker Image using multi-stage builds

There are a few options on how to bake our agent. While you could technically download the agent at run time, this would typically result in a longer startup time as opposed to having the agent installed and preconfigured in the image for quicker boot times.

**We recommend directly installing the LW Agent in your existing Docker Image via multi stage builds as shown below.**

## Installation Steps 

### Step 0: Review [Best Practices](../../README.md#best-practices) & [General Requirements](../../README.md#requirements)

### Step 1: Add the Agent to your existing `Dockerfile`

Firstly, we modify your existing `Dockerfile` in order to add the LW Agent. This is achieved by:

* (Step 1a) adding a build stage, 
* (Step 1b) copying the binary, 
* (Step 1c) setting up configurations.

Secondly, in the docker-entrypoint script, we add a line for: 

* (Step 1d) running the agent 

#### Full Example (with BuildKit)

Below is a full example of a _very_ simple `Dockerfile` along with its entrypoint script. This example pretty prints real-time Wikipedia recent changes. We have also added three lines and comments indicating the LW Agent additions.

[Dockerfile](multi.dockerfile)
  ```Dockerfile
  # syntax=docker/dockerfile:1
  ### LW Agent (Step 1a) adding a build stage ######################
  FROM lacework/datacollector:latest AS agent-build-image
  ############################################################

  FROM ubuntu:latest
  RUN apt-get update && apt-get install -y \
    curl \
    jq \
    sed \
    && rm -rf /var/lib/apt/lists/*

  ### LW Agent (Step 1b) copying the binary  #######################
  COPY --from=agent-build-image  /var/lib/backup/*/datacollector /var/lib/lacework/datacollector
  ### LW Agent (Step 1c) setting up configurations  
  RUN  --mount=type=secret,id=LW_AGENT_ACCESS_TOKEN    \
        mkdir -p /var/log/lacework/                 && \
        mkdir -p /var/lib/lacework/config/          && \
        echo '{"tokens": {"accesstoken": "'$( cat /run/secrets/LW_AGENT_ACCESS_TOKEN)'"}}' > /var/lib/lacework/config/config.json  
  ############################################################

  COPY docker-entrypoint.sh /
  RUN chmod +x /docker-entrypoint.sh
  ENTRYPOINT [ "/docker-entrypoint.sh" ]
  ```

[Entrypoint Script](docker-entrypoint.sh)
  ```bash
  #!/bin/sh
  ### LW Agent (Step 1d) copying the binary  #######################
  ./var/lib/lacework/datacollector &

  curl -s  https://stream.wikimedia.org/v2/stream/recentchange |   grep data |  sed 's/^data: //g' |  jq -rc 'with_entries(if .key == "$schema" then .key = "schema" else . end)'
```

Notes: 
* The <code>RUN</code></strong> command uses [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) to securely pass the LW Agent Token as <code>LW_AGENT_ACCESS_TOKEN</code>. This is <em>not</em> necessary but <strong>recommended</strong>. For an example <em>sans</em> the BuildKit see the [Sans BuildKit folder](sans-buildkit-example/README.md).
* It’s also possible to install the LW Agent by fetching and installing the binaries from our official github repository. Steps for this approach are found in the [GitHub Build Example](../baked-github-build/README.md)
* Optionally, some customers choose to upload the `lacework/datacollector:latest` to their ECR. 

### Step 2: [Build](build-multi.sh) & [Push](push-multi.sh)

Now that our image has been modified, it’s time to upload the changes to ECR by:

* (1) Rebuilding the image
* (2) Pushing the changes to AWS ECR

#### Full Example (with BuildKit)

  ```bash
  #!/bin/sh

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

At this point, we’re done making custom changes to add the LW Agent. This step involves running the container as you typically would and we listed here to serve as a reference.

#### Example of a Task Definition Service

To run the image, AWS requires the configuration of an ECS [Task Definition](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html). A very simple example is available in the [here](taskDefinition.json). For more examples, visit the [AWS documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/example_task_definitions.html).

```bash
# Create a cluster. You only need to do this once.
aws ecs create-cluster --cluster-name dianademo-cluster 

# Register the task definition
aws ecs register-task-definition --cli-input-json file://taskDefinition.json   
```

The next step is to either create a service or simply run the task. Below we create a service through the AWS web console and also present the <code>json</code></strong> output [here](service.json) for reference. 

```bash
# Create a Service (or Run Task) 
## Follow the AWS Wizard
open https://us-east-2.console.aws.amazon.com/ecs/home?region=us-east-2#/clusters/dianademo-cluster/createService 

## OR provide json definition of the service
aws ecs create-service --cli-input-json file://bakedService.json   

# View Service
aws ecs list-services --cluster dianademo-cluster 
```
