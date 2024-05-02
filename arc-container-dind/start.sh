#!/bin/bash

__log() {
  local color instant level

  color=${1:?missing required <color> argument}
  shift

  level=${FUNCNAME[1]} # `main` if called from top-level
  level=${level#log.} # substring after `log.`
  level=${level^^} # UPPERCASE

  if [[ ! -v "LOG_${level}_DISABLED" ]]; then
    instant=$(date '+%F %T.%-3N' 2>/dev/null || :)

    # https://no-color.org/
    if [[ -v NO_COLOR ]]; then
      printf -- '%s  %s --- %s\n' "$instant" "$level" "$*" 1>&2 || :
    else
      printf -- '\033[0;%dm%s  %s --- %s\033[0m\n' "$color" "$instant" "$level" "$*" 1>&2 || :
    fi
  fi
}

# To log with a dynamic level use standard Bash capabilities:
#
#     level=notice
#     command || level=error
#     "log.$level" message
#
# @formatter:off
log.debug   () { __log 37 "$@"; } # white
log.notice  () { __log 34 "$@"; } # blue
log.warning () { __log 33 "$@"; } # yellow
log.error   () { __log 31 "$@"; } # red
log.success () { __log 32 "$@"; } # green
# @formatter:on

RUNNER_GRACEFUL_STOP_TIMEOUT=${RUNNER_GRACEFUL_STOP_TIMEOUT:-15}

graceful_stop() {
  log.notice "Executing actions-runner-controller's SIGTERM handler."
  log.notice "Note that if this takes more time than terminationGracePeriodSeconds, the runner will be forcefully terminated by Kubernetes, which may result in the in-progress workflow job, if any, to fail."

  log.notice "Ensuring dockerd is still running."
  if ! docker ps -a; then
    log.warning "Detected configuration error: dockerd should be running but is already nowhere. This is wrong. Ensure that your init system to NOT pass SIGTERM directly to dockerd!"
  fi

  # The below procedure atomically removes the runner from GitHub Actions service,
  # to ensure that the runner is not running any job.
  # This is required to not terminate the actions runner agent while running the job.
  # If we didn't do this atomically, we might end up with a rare race where
  # the runner agent is terminated while it was about to start a job.

  # `pushd`` is needed to run the config.sh successfully.
  # Without this the author of this script ended up with errors like the below:
  #   Cannot connect to server, because config files are missing. Skipping removing runner from the server.
  #   Does not exist. Skipping Removing .credentials
  #   Does not exist. Skipping Removing .runner
  if ! pushd /runner; then
    log.error "Failed to pushd ${RUNNER_HOME}"
    exit 1
  fi

  # We need to wait for the registration first.
  # Otherwise a direct runner pod deletion triggered while the runner entrypoint.sh is about to register itself with
  # config.sh can result in this graceful stop process to get skipped.
  # In that case, the pod is eventually and forcefully terminated by ARC and K8s, resulting
  # in the possible running workflow job after this graceful stop process failed might get cancelled prematurely.
  log.notice "Waiting for the runner to register first."
  while ! [ -f /runner/.runner ]; do
    sleep 1
  done
  log.notice "Observed that the runner has been registered."

  if ! /runner/config.sh remove --token "$RUNNER_TOKEN"; then
    i=0
    log.notice "Waiting for RUNNER_GRACEFUL_STOP_TIMEOUT=$RUNNER_GRACEFUL_STOP_TIMEOUT seconds until the runner agent to stop by itself."
    while [[ $i -lt $RUNNER_GRACEFUL_STOP_TIMEOUT ]]; do
      sleep 1
      if ! pgrep Runner.Listener > /dev/null; then
        log.notice "The runner agent stopped before RUNNER_GRACEFUL_STOP_TIMEOUT=$RUNNER_GRACEFUL_STOP_TIMEOUT"
        break
      fi
      i=$((i+1))
    done
  fi

  if ! popd; then
    log.error "Failed to popd from ${RUNNER_HOME}"
    exit 1
  fi

  if pgrep Runner.Listener > /dev/null; then
    # The below procedure fixes the runner to correctly notify the Actions service for the cancellation of this runner.
    # It enables you to see `Error: The operation was canceled.` in the worklow job log, in case a job was still running on this runner when the
    # termination is requested.
    #
    # Note though, due to how Actions work, no all job steps gets `Error: The operation was canceled.` in the job step logs.
    # Jobs that were still in the first `Stet up job` step` seem to get `Error: A task was canceled.`,
    #
    # Anyway, without this, a runer pod is "forcefully" killed by any other controller (like cluster-autoscaler) can result in the workflow job to
    # hang for 10 minutes or so.
    # After 10 minutes, the Actions UI just shows the failure icon for the step, without `Error: The operation was canceled.`,
    # not even showing `Error: The operation was canceled.`, which is confusing.
    runner_listener_pid=$(pgrep Runner.Listener)
    log.notice "Sending SIGTERM to the actions runner agent ($runner_listener_pid)."
    kill -TERM "$runner_listener_pid"

    log.notice "SIGTERM sent. If the runner is still running a job, you'll probably see \"Error: The operation was canceled.\" in its log."
    log.notice "Waiting for the actions runner agent to stop."
    while pgrep Runner.Listener > /dev/null; do
      sleep 1
    done
  fi

  # This message is supposed to be output only after the runner agent output:
  #   2022-08-27 02:04:37Z: Job test3 completed with result: Canceled
  # because this graceful stopping logic is basically intended to let the runner agent have some time
  # needed to "Cancel" it.
  # At the times we didn't have this logic, the runner agent was even unable to output the Cancelled message hence
  # unable to gracefully stop, hence the workflow job hanged like forever.
  log.notice "The actions runner process exited."

  if [ "$RUNNER_INIT_PID" != "" ]; then
    log.notice "Holding on until runner init (pid $RUNNER_INIT_PID) exits, so that there will hopefully be no zombie processes remaining."
    # We don't need to kill -TERM $RUNNER_INIT_PID as the init is supposed to exit by itself once the foreground process(=the runner agent) exists.
    wait "$RUNNER_INIT_PID" || :
  fi

  log.notice "Graceful stop completed."
}

sudo /bin/bash <<SCRIPT
mkdir -p /etc/docker

if [ ! -f /etc/docker/daemon.json ]; then
  echo "{}" > /etc/docker/daemon.json
fi

if [ -n "${MTU}" ]; then
jq ".\"mtu\" = ${MTU}" /etc/docker/daemon.json > /tmp/.daemon.json && mv /tmp/.daemon.json /etc/docker/daemon.json
# See https://docs.docker.com/engine/security/rootless/
export DOCKERD_ROOTLESS_ROOTLESSKIT_MTU=${MTU}
fi

if [ -n "${DOCKER_DEFAULT_ADDRESS_POOL_BASE}" ] && [ -n "${DOCKER_DEFAULT_ADDRESS_POOL_SIZE}" ]; then
  jq ".\"default-address-pools\" = [{\"base\": \"${DOCKER_DEFAULT_ADDRESS_POOL_BASE}\", \"size\": ${DOCKER_DEFAULT_ADDRESS_POOL_SIZE}}]" /etc/docker/daemon.json > /tmp/.daemon.json && mv /tmp/.daemon.json /etc/docker/daemon.json
fi

if [ -n "${DOCKER_REGISTRY_MIRROR}" ]; then
jq ".\"registry-mirrors\"[0] = \"${DOCKER_REGISTRY_MIRROR}\"" /etc/docker/daemon.json > /tmp/.daemon.json && mv /tmp/.daemon.json /etc/docker/daemon.json
fi

if [ -n "${DOCKER_INSECURE_REGISTRY}" ]; then
jq ".\"insecure-registries\"[0] = \"${DOCKER_INSECURE_REGISTRY}\"" /etc/docker/daemon.json > /tmp/.daemon.json && mv /tmp/.daemon.json /etc/docker/daemon.json
fi
SCRIPT

dumb-init bash <<'SCRIPT' &
source logger.sh
source wait.sh

dump() {
  local path=${1:?missing required <path> argument}
  shift
  printf -- "%s\n---\n" "${*//\{path\}/"$path"}" 1>&2
  cat "$path" 1>&2
  printf -- '---\n' 1>&2
}

for config in /etc/docker/daemon.json; do
  dump "$config" 'Using {path} with the following content:'
done

log.debug 'Starting Docker daemon'
sudo /usr/bin/dockerd &

log.debug 'Waiting for processes to be running...'
processes=(dockerd)

for process in "${processes[@]}"; do
    if ! wait_for_process "$process"; then
        log.error "$process is not running after max time"
        exit 1
    else
        log.debug "$process is running"
    fi
done

if [ -n "${MTU}" ]; then
  sudo ifconfig docker0 mtu "${MTU}" up
fi

startup.sh
SCRIPT

RUNNER_INIT_PID=$!
log.notice "Runner init started with pid $RUNNER_INIT_PID"
wait $RUNNER_INIT_PID
log.notice "Runner init exited. Exiting this process with code 0 so that the container and the pod is GC'ed Kubernetes soon."

trap - TERM

RUNNER_ASSETS_DIR=${RUNNER_ASSETS_DIR:-/runnertmp}
RUNNER_HOME=${RUNNER_HOME:-/runner}

# Let GitHub runner execute these hooks. These environment variables are used by GitHub's Runner as described here
# https://github.com/actions/runner/blob/main/docs/adrs/1751-runner-job-hooks.md
# Scripts referenced in the ACTIONS_RUNNER_HOOK_ environment variables must end in .sh or .ps1
# for it to become a valid hook script, otherwise GitHub will fail to run the hook
export ACTIONS_RUNNER_HOOK_JOB_STARTED=/etc/arc/hooks/job-started.sh
export ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/etc/arc/hooks/job-completed.sh

if [ -n "${STARTUP_DELAY_IN_SECONDS}" ]; then
  log.notice "Delaying startup by ${STARTUP_DELAY_IN_SECONDS} seconds"
  sleep "${STARTUP_DELAY_IN_SECONDS}"
fi

if [ -z "${GITHUB_URL}" ]; then
  log.debug 'Working with public GitHub'
  GITHUB_URL="https://github.com/"
else
  length=${#GITHUB_URL}
  last_char=${GITHUB_URL:length-1:1}

  [[ $last_char != "/" ]] && GITHUB_URL="$GITHUB_URL/"; :
  log.debug "Github endpoint URL ${GITHUB_URL}"
fi

if [ -z "${RUNNER_NAME}" ]; then
  log.error 'RUNNER_NAME must be set'
  exit 1
fi

if [ -n "${RUNNER_ORG}" ] && [ -n "${RUNNER_REPO}" ] && [ -n "${RUNNER_ENTERPRISE}" ]; then
  ATTACH="${RUNNER_ORG}/${RUNNER_REPO}"
elif [ -n "${RUNNER_ORG}" ]; then
  ATTACH="${RUNNER_ORG}"
elif [ -n "${RUNNER_REPO}" ]; then
  ATTACH="${RUNNER_REPO}"
elif [ -n "${RUNNER_ENTERPRISE}" ]; then
  ATTACH="enterprises/${RUNNER_ENTERPRISE}"
else
  log.error 'At least one of RUNNER_ORG, RUNNER_REPO, or RUNNER_ENTERPRISE must be set'
  exit 1
fi

if [ -z "${RUNNER_TOKEN}" ]; then
  log.error 'RUNNER_TOKEN must be set'
  exit 1
fi

if [ -z "${RUNNER_REPO}" ] && [ -n "${RUNNER_GROUP}" ];then
  RUNNER_GROUPS=${RUNNER_GROUP}
fi

# Hack due to https://github.com/actions/actions-runner-controller/issues/252#issuecomment-758338483
if [ ! -d "${RUNNER_HOME}" ]; then
  log.error "$RUNNER_HOME should be an emptyDir mount. Please fix the pod spec."
  exit 1
fi

# if this is not a testing environment
if [[ "${UNITTEST:-}" == '' ]]; then
  sudo chown -R runner:docker "$RUNNER_HOME"
  # enable dotglob so we can copy a ".env" file to load in env vars as part of the service startup if one is provided
  # loading a .env from the root of the service is part of the actions/runner logic
  shopt -s dotglob
  # use cp instead of mv to avoid issues when src and dst are on different devices
  cp -r "$RUNNER_ASSETS_DIR"/* "$RUNNER_HOME"/
  shopt -u dotglob
fi

if ! cd "${RUNNER_HOME}"; then
  log.error "Failed to cd into ${RUNNER_HOME}"
  exit 1
fi

# past that point, it's all relative pathes from /runner

config_args=()
if [ "${RUNNER_FEATURE_FLAG_ONCE:-}" != "true" ] && [ "${RUNNER_EPHEMERAL}" == "true" ]; then
  config_args+=(--ephemeral)
  log.debug 'Passing --ephemeral to config.sh to enable the ephemeral runner.'
fi
if [ "${DISABLE_RUNNER_UPDATE:-}" == "true" ]; then
  config_args+=(--disableupdate)
  log.debug 'Passing --disableupdate to config.sh to disable automatic runner updates.'
fi

update-status "Registering"

retries_left=10
while [[ ${retries_left} -gt 0 ]]; do
  log.debug 'Configuring the runner.'
  ./config.sh --unattended --replace \
    --name "${RUNNER_NAME}" \
    --url "${GITHUB_URL}${ATTACH}" \
    --token "${RUNNER_TOKEN}" \
    --runnergroup "${RUNNER_GROUPS}" \
    --labels "${RUNNER_LABELS}" \
    --work "${RUNNER_WORKDIR}" "${config_args[@]}"

  if [ -f .runner ]; then
    log.debug 'Runner successfully configured.'
    break
  fi

  log.debug 'Configuration failed. Retrying'
  retries_left=$((retries_left - 1))
  sleep 1
done

if [ ! -f .runner ]; then
  # we couldn't configure and register the runner; no point continuing
  log.error 'Configuration failed!'
  exit 2
fi

cat .runner
# Note: the `.runner` file's content should be something like the below:
#
# $ cat /runner/.runner
# {
# "agentId": 117, #=> corresponds to the ID of the runner
# "agentName": "THE_RUNNER_POD_NAME",
# "poolId": 1,
# "poolName": "Default",
# "serverUrl": "https://pipelines.actions.githubusercontent.com/SOME_RANDOM_ID",
# "gitHubUrl": "https://github.com/USER/REPO",
# "workFolder": "/some/work/dir" #=> corresponds to Runner.Spec.WorkDir
# }
#
# Especially `agentId` is important, as other than listing all the runners in the repo,
# this is the only change we could get the exact runnner ID which can be useful for further
# GitHub API call like the below. Note that 171 is the agentId seen above.
#   curl \
#     -H "Accept: application/vnd.github.v3+json" \
#     -H "Authorization: bearer ${GITHUB_TOKEN}"
#     https://api.github.com/repos/USER/REPO/actions/runners/171

# Hack due to the DinD volumes
if [ -z "${UNITTEST:-}" ] && [ -e ./externalstmp ]; then
  mkdir -p ./externals
  mv ./externalstmp/* ./externals/
fi

WAIT_FOR_DOCKER_SECONDS=${WAIT_FOR_DOCKER_SECONDS:-120}
if [[ "${DISABLE_WAIT_FOR_DOCKER}" != "true" ]] && [[ "${DOCKER_ENABLED}" == "true" ]]; then
    log.debug 'Docker enabled runner detected and Docker daemon wait is enabled'
    log.debug "Waiting until Docker is available or the timeout of ${WAIT_FOR_DOCKER_SECONDS} seconds is reached"
    if ! timeout "${WAIT_FOR_DOCKER_SECONDS}s" bash -c 'until docker ps ;do sleep 1; done'; then
      log.notice "Docker has not become available within ${WAIT_FOR_DOCKER_SECONDS} seconds. Exiting with status 1."
      exit 1
    fi
else
  log.notice 'Docker wait check skipped. Either Docker is disabled or the wait is disabled, continuing with entrypoint'
fi

# Unset entrypoint environment variables so they don't leak into the runner environment
unset RUNNER_NAME RUNNER_REPO RUNNER_TOKEN STARTUP_DELAY_IN_SECONDS DISABLE_WAIT_FOR_DOCKER

# Docker ignores PAM and thus never loads the system environment variables that
# are meant to be set in every environment of every user. We emulate the PAM
# behavior by reading the environment variables without interpreting them.
#
# https://github.com/actions/actions-runner-controller/issues/1135
# https://github.com/actions/runner/issues/1703

# /etc/environment may not exist when running unit tests depending on the platform being used
# (e.g. Mac OS) so we just skip the mapping entirely
if [ -z "${UNITTEST:-}" ]; then
  mapfile -t env </etc/environment
fi

log.notice "WARNING LATEST TAG HAS BEEN DEPRECATED. SEE GITHUB ISSUE FOR DETAILS:"
log.notice "https://github.com/actions/actions-runner-controller/issues/2056"

update-status "Idle"
exec env -- "${env[@]}" ./run.sh
