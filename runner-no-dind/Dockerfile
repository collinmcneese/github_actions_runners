ARG BASE_IMAGE="ubuntu:22.04"

# Base image information
FROM ${BASE_IMAGE}

# Add a non-priviledged user
RUN useradd -m runner

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
        gosu \
    && rm -rf /var/lib/apt/lists/*

# Configure package repositories and install additional dependencies
RUN set -eu; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
    curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb; \
    dpkg -i /tmp/packages-microsoft-prod.deb; \
    rm /tmp/packages-microsoft-prod.deb; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh apt-transport-https dotnet-sdk-6.0; \
    rm -rf /var/lib/apt/lists/*

ARG RUNNER_VERSION
ARG TARGETARCH
RUN : "${RUNNER_VERSION:?Build argument RUNNER_VERSION needs to be set and non-empty.}" \
    && case "$TARGETARCH" in \
        amd64) RUNNER_ARCH=x64 ;; \
        arm64) RUNNER_ARCH=arm64 ;; \
        *) echo "Unsupported runner architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && mkdir -p /home/runner/actions-runner \
    && chown runner /home/runner/actions-runner \
    && curl -fsSL -o /tmp/actions-runner.tar.gz "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
    && gosu runner tar -xzf /tmp/actions-runner.tar.gz -C /home/runner/actions-runner \
    && rm /tmp/actions-runner.tar.gz

# Create hostedtoolcache directory and set permissions
RUN mkdir -p /opt/hostedtoolcache \
    && chown -R runner /opt/hostedtoolcache

# Run Cleanup
RUN apt clean -y && apt autoremove --purge -y

# copy the start.sh script & set permissions
COPY --chown=runner:runner --chmod=755 start.sh start.sh

# run as non-root user
USER runner

ENTRYPOINT ["./start.sh"]
