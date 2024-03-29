# GitHub Actions Runners Examples

[![Create and publish a Docker image](https://github.com/collinmcneese/github_actions_runners/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/collinmcneese/github_actions_runners/actions/workflows/docker-publish.yml)

Working repository with reference examples for building self-hosted runners for GitHub Actions.

The contents of this repository are _not_ meant to be run in a production environment and are for refernce example only.  This is still an active _Work In Progress_ and likely should not be used by anyone, for any reason.

## References

- [https://github.com/actions/runner/](https://github.com/actions/runner/)

## Container Image

Builds a [GitHub Actions Runner](https://github.com/actions/runner/) container :ship:.

This repository has a reference [docker](./docker) example which contains a `Dockerfile` for building an image along with a `docker-compose` configuration for local testing.

The image configuration built from this example is published to [GitHub Packages](https://github.com/collinmcneese/github_actions_runners/pkgs/container/github_actions_runners) and can be pulled rather than performing a local build for quick testing.

The container image reference:

- Is meant for [organization](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-an-organization) or [repository](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-a-repository) scoped runners.  See [Docs](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) for additional information.

### Building & Using the Container Image Locally

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
