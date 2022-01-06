
# Lacework Agent + AWS Fargate Guide <!-- omit in toc -->

### Table of Contents
- [Change log](#change-log)
- [Overview](#overview)
- [Best practices](#best-practices)
- [Prerequisites](#prerequisites)
- [Installation steps](#installation-steps)
- [Provide feedback](#provide-feedback)

## Change log 

| **Date**  | **Author** | **Comment** | 
| ------------- | ------------- | ------------- |
| January 2022  | Allie Fick  | Revised to align with Lacework's best practice guide template.  |
| September 2021  |  Diana Esteves  | <ul><li>We're embracing Docker's multi-stage build feature when baking the agent.</li><li>Updated best practices to include 1 agent token:1 service recommendation</li><li>Updated one-liner and corresponding entrypoint to start the agent service.</li><li>Updated sidecar reqs.</li><li>We now have several example Dockerfiles and helper scripts. :star_struck: See [/examples](/examples).</li></ul> |
| August 2021  | Diana Esteves  |  Initial public release for this guide. Thank you to all the amazing Lacers who provided valuable feedback! |


## Overview

Two options are available to install the Lacework agent in AWS Fargate. We highly recommend the baking solution because it pre-installs and configures the agent _directly_ in the Docker image.

## Prerequisites

* The base image in your Dockerfile must be based on one of the Linux distros found [here](https://support.lacework.com/hc/en-us/articles/360005230014). 
* As the Lacework agent user gathers network packet data, it needs to be run with <code>sudo</code></strong> privileges. The Lacework agent must be run as <strong><code>root</code></strong>. 
* The user must have valid access token(s) for the Lacework agent. These can be obtained via the [Lacework CLI](https://github.com/lacework/go-sdk/wiki/CLI-Documentation#agent-access-token-management) (see [Installing the CLI & Creating a Token](/examples/cliToken.sh) bash script for a simple example) or, alternatively, head over to <code>[https://](https://YOUR-ORG.lacework.net/ui/investigation/settings)<strong><span style="text-decoration:underline;">YOUR-ORG[.lacework.net/ui/investigation/settings](https://YOUR-ORG.lacework.net/ui/investigation/settings)</span></strong>  </code>.
* The AWS Identity and Access Management (IAM) user used needs permissions listed in [AmazonECSTaskExecutionRolePolicy](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy$jsonEditor).
* Lacework agent needs to reach Lacework’s API endpoint. The default endpoint is [https://api.lacework.net](https://api.lacework.net). See [other endpoints here](https://support.lacework.com/hc/en-us/articles/1500007918841-Agent-Server-URL).
* If leveraging the sidecar alternative, be sure to review [additional requirements](/examples/sidecar/README.md#additional-requirements).

## Best practices

* Install the agent _directly_ into your existing application Dockerfile(s):
    * Use [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds).
    * When building the Docker image, place the Lacework agent token in the container definition as an environment variable to securely pass it in. 
* Allocate 512 MB vCPU and 1 GB RAM for the Lacework agent.
* Use one Lacework agent token per _container_ (`TaskDefinition` Service).



## Installation steps 

Two primary options to install the Lacework Agent in AWS Fargate are available. The *preferred* method is to bake the Lacework agent directly in the Docker image. We encourage using multistage builds; however, a version without multistage builds is also documented below:

Navigate to the corresponding configuration below to view the installation steps. 

- ***Recommended***: [Bake the Lacework Agent in the Docker Image Using Multistage Builds](examples/baked-multistageRECOMMENDED/README.md)
- [Bake the Lacework Agent into Existing Dockerfile Sans Multistage Build](examples/baked-github-build/README.md)
- [Using a Sidecar](examples/sidecar/README.md)

## Provide feedback

To provide feedback on this guide, submit a pull request or email `diana@lacework.com`.
