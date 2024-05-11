#!/bin/bash

# Wait for Docker to be available before starting
until docker ps ; do
  >&2 echo "Docker is unavailable - sleeping"
  sleep 5
done

cd /home/docker/actions-runner

# Register with the GHES endpoint, if specified
if [[ -n ${GHRUNNER_GITHUB_BASE_URL} ]]; then
  echo "Using GHES endpoint: ${GHRUNNER_GITHUB_BASE_URL}"
  if [[ -n ${GHRUNNER_REPOSITORY} ]]; then
    if [[ -n ${GHRUNNER_REG_TOKEN} ]]; then
      REG_TOKEN=${GHRUNNER_REG_TOKEN}
    else
      REG_TOKEN=$(curl -sX POST -H "Authorization: token ${GHRUNNER_ACCESS_TOKEN}" ${GHRUNNER_GITHUB_BASE_URL}/api/v3/repos/${GHRUNNER_ORGANIZATION}/${GHRUNNER_REPOSITORY}/actions/runners/registration-token | jq .token --raw-output)
    fi
    ./config.sh --url "${GHRUNNER_GITHUB_BASE_URL}/${GHRUNNER_ORGANIZATION}/${GHRUNNER_REPOSITORY}" \
      --token "${REG_TOKEN}" \
      --unattended \
      --labels "${GHRUNNER_LABELS}" \
      --ephemeral ${GHRUNNER_RUNNER_GROUP:+--runnergroup "${GHRUNNER_RUNNER_GROUP}"}
  else
    if [[ -n ${GHRUNNER_REG_TOKEN} ]]; then
      REG_TOKEN=${GHRUNNER_REG_TOKEN}
    else
      REG_TOKEN=$(curl -sX POST -H "Authorization: token ${GHRUNNER_ACCESS_TOKEN}" ${GHRUNNER_GITHUB_BASE_URL}/api/v3/orgs/${GHRUNNER_ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)
    fi
    ./config.sh --url "${GHRUNNER_GITHUB_BASE_URL}/${GHRUNNER_ORGANIZATION}" \
      --token "${REG_TOKEN}" \
      --unattended \
      --labels "${GHRUNNER_LABELS}" \
      --ephemeral ${GHRUNNER_RUNNER_GROUP:+--runnergroup "${GHRUNNER_RUNNER_GROUP}"}
  fi
else # Register with the GitHub endpoint
  if [[ -n ${GHRUNNER_REPOSITORY} ]]; then
    if [[ -n ${GHRUNNER_REG_TOKEN} ]]; then
      REG_TOKEN=${GHRUNNER_REG_TOKEN}
    else
      REG_TOKEN=$(curl -sX POST -H "Authorization: token ${GHRUNNER_ACCESS_TOKEN}" https://api.github.com/repos/${GHRUNNER_ORGANIZATION}/${GHRUNNER_REPOSITORY}/actions/runners/registration-token | jq .token --raw-output)
    fi
    ./config.sh --url "https://github.com/${GHRUNNER_ORGANIZATION}/${GHRUNNER_REPOSITORY}" \
      --token "${REG_TOKEN}" \
      --unattended \
      --labels "${GHRUNNER_LABELS}" \
      --ephemeral ${GHRUNNER_RUNNER_GROUP:+--runnergroup "${GHRUNNER_RUNNER_GROUP}"}
  else
    if [[ -n ${GHRUNNER_REG_TOKEN} ]]; then
      REG_TOKEN=${GHRUNNER_REG_TOKEN}
    else
      REG_TOKEN=$(curl -sX POST -H "Authorization: token ${GHRUNNER_ACCESS_TOKEN}" https://api.github.com/orgs/${GHRUNNER_ORGANIZATION}/actions/runners/registration-token | jq .token --raw-output)
    fi
    ./config.sh --url "https://github.com/${GHRUNNER_ORGANIZATION}" \
      --token "${REG_TOKEN}" \
      --unattended \
      --labels "${GHRUNNER_LABELS}" \
      --ephemeral ${GHRUNNER_RUNNER_GROUP:+--runnergroup "${GHRUNNER_RUNNER_GROUP}"}
  fi
fi

# De-register the runner if the container is stopped
cleanup() {
    echo "De-registering runner"
    ./config.sh remove --unattended --token "${REG_TOKEN}"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
