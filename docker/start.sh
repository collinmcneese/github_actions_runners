#!/bin/bash

# Wait for Docker to be available before starting
until docker ps ; do
  >&2 echo "Docker is unavailable - sleeping"
  sleep 5
done

cd /home/docker/actions-runner

# Register with the GHES endpoint, if specified
if [[ ! -z ${GHRUNNER_GITHUB_BASE_URL} ]]; then
  echo "Using GHES endpoint: ${GHRUNNER_GITHUB_BASE_URL}"
  REG_TOKEN=$(curl -sX POST -H "Authorization: token ${GHRUNNER_ACCESS_TOKEN}" ${GHRUNNER_GITHUB_BASE_URL}/api/v3/orgs/${GHRUNNER_ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)
  ./config.sh --url "${GHRUNNER_GITHUB_BASE_URL}/${GHRUNNER_ORGANIZATION}" --token "${REG_TOKEN}" --unattended --labels "${GHRUNNER_LABELS}" --ephemeral
else # Register with the GitHub endpoint
  REG_TOKEN=$(curl -sX POST -H "Authorization: token ${GHRUNNER_ACCESS_TOKEN}" https://api.github.com/orgs/${GHRUNNER_ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)
  ./config.sh --url "https://github.com/${GHRUNNER_ORGANIZATION}" --token "${REG_TOKEN}" --unattended --labels "${GHRUNNER_LABELS}" --ephemeral
fi

# De-register the runner if the container is stopped
cleanup() {
    echo "De-registering runner"
    ./config.sh remove --unattended --token "${REG_TOKEN}"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
