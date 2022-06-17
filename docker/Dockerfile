ARG PLATFORM="linux/amd64"
ARG BASE_IMAGE="ubuntu:22.04"

# Base image information
FROM --platform=${PLATFORM} ${BASE_IMAGE}

ARG RUNNER_VERSION="2.293.0"

# Add a non-priviledged user
RUN useradd -m docker

# Install dependencies
RUN apt update \ 
    # && apt install -y curl build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip  --no-install-recommends
    && apt install -y curl ca-certificates --no-install-recommends

# Fetch and extract the GitHub Actions Runner
RUN cd /home/docker && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Install GitHub Actions Runner pre-requisites
RUN curl -O -L https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb  \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb

RUN apt update \
    && apt install -y apt-transport-https dotnet-sdk-6.0  --no-install-recommends

# for Docker-in-Docker
RUN apt update \
    && apt install -y gnupg lsb-release  --no-install-recommends \
    && apt remove docker docker-engine docker.io containerd runc \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update \
    && apt install -y docker-ce-cli --no-install-recommends

# Set permissions for the docker user on extracted files
RUN chown -R docker ~docker

# Run Cleanup
RUN apt clean -y && apt autoremove --purge -y

# copy the start.sh script & set permissions
COPY start.sh start.sh
RUN chmod +x start.sh

# run as non-root user
USER docker

ENTRYPOINT ["./start.sh"]
