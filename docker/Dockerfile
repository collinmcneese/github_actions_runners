ARG BASE_IMAGE="ubuntu:22.04"

# Base image information
FROM ${BASE_IMAGE}

ARG RUNNER_VERSION
RUN \
    # Check for mandatory build arguments
    : "${RUNNER_VERSION:?Build argument RUNNER_VERSION needs to be set and non-empty.}"

# Add a non-priviledged user
RUN useradd -m docker

# Install dependencies
RUN apt update \
    && apt install -y --no-install-recommends \
        gnupg \
        lsb-release \
        curl \
        tar \
        unzip \
        apt-transport-https \
        ca-certificates \
        sudo \
        gpg-agent \
        software-properties-common \
        build-essential \
        zlib1g-dev \
        zstd \
        gettext \
        libcurl4-openssl-dev \
        inetutils-ping \
        jq \
        wget \
        dirmngr \
        openssh-client \
        locales \
        python3-pip \
        python3-setuptools \
        python3 \
        dumb-init \
        nodejs \
        rsync \
        gosu

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y

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
RUN apt remove -y docker docker-engine docker.io containerd runc || true

RUN apt update \
    && apt install -y gnupg lsb-release  --no-install-recommends \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update \
    && apt install -y docker-ce-cli --no-install-recommends

# Set permissions for the docker user on extracted files
RUN chown -R docker ~docker

# Create hostedtoolcache directory and set permissions
RUN mkdir -p /opt/hostedtoolcache \
    && chown -R docker /opt/hostedtoolcache

# Run Cleanup
RUN apt clean -y && apt autoremove --purge -y

# copy the start.sh script & set permissions
COPY start.sh start.sh
RUN chmod +x start.sh

# run as non-root user
USER docker

ENTRYPOINT ["./start.sh"]
