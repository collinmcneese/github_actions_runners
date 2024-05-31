# GitHub Actions Runners Examples

[![Create and publish a Docker image](https://github.com/collinmcneese/github_actions_runners/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/collinmcneese/github_actions_runners/actions/workflows/docker-publish.yml)

Working repository with reference examples for building self-hosted runners for GitHub Actions.

The contents of this repository are _not_ meant to be run in a production environment and are for reference example only.  This is still an active _Work In Progress_ and likely should not be used by anyone, for any reason.

## References

- [https://github.com/actions/runner/](https://github.com/actions/runner/)

## Included Examples

### Customized Container Image

[Published Image](https://github.com/users/collinmcneese/packages/container/package/github_actions_runners)

Builds a [GitHub Actions Runner](https://github.com/actions/runner/) container :ship:.

This repository has a reference [docker](./docker) example which contains a `Dockerfile` for building an image along with a `docker-compose` configuration for local testing.

The image configuration built from this example is published to [GitHub Packages](https://github.com/collinmcneese/github_actions_runners/pkgs/container/github_actions_runners) and can be pulled rather than performing a local build for quick testing.

The container image reference:

- Is meant for [organization](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-an-organization) or [repository](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-a-repository) scoped runners.  See [Docs](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) for additional information.

#### Building & Using the Container Image Locally

- Create `docker/.env` file using the reference [docker/.env.example](docker/.env.example)

  ```shell
  GHRUNNER_ORGANIZATION=''
  # Optionally specify a Repository
  # GHRUNNER_REPOSITORY=''
  GHRUNNER_ACCESS_TOKEN=''
  GHRUNNER_LABELS="self-hosted,Linux,x64,dependabot"
  # Specify the base GitHub URL if not using github.com
  # GHRUNNER_GITHUB_BASE_URL='https://myGHES.com'
  ```

### runner-no-dind

[Published Image](https://github.com/users/collinmcneese/packages/container/package/runner-no-dind)

This is a similar example to the `docker` example, but with the `dind` (Docker in Docker) feature disabled.  This is useful for running the runner in a container that does not have access to the host Docker daemon so no Docker dependencies are required or installed on the container.

### Actions Runner

[Published Image](https://github.com/users/collinmcneese/packages/container/package/actions-runner)

The [actions-runner](./actions-runner) example contains a `Dockerfile` for building an image with the GitHub Actions Runner installed.  This directory is an example of only building the runner image, such as for use with [Actions Runner Controller](https://github.com/actions/actions-runner-controller), as it does not contain a start script or configuration for running the runner.
