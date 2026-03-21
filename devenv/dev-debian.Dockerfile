FROM debian:stable

ARG GOLANG_VERSION=1.26.0
ARG DEV_USER
ARG NVM_VERSION=v0.40.4
ARG NODE_VERSION=24
ARG CLAUDE_SETUP
ARG USER_ID
ARG GROUP_ID

RUN if [ -z "$DEV_USER" ]; \
  then echo "DEV_USER arg is required"; exit 1; \
  elif [ -z "$USER_ID" ]; \
  then echo "USER_ID arg is required"; exit 1; \
  elif [ -z "$GROUP_ID" ]; \
  then echo "GROUP_ID arg is required"; exit 1; \
  fi \
  ;

# Install OpenSSH server and essential tools
RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		g++ \
		gcc \
    libc6 \
		libc6-dev \
		make \
		pkg-config \
    openssh-server \
    sudo \
    which \
    hugo \
    ca-certificates \
    wget \
    ffmpeg \
    python3; \
  apt-get autoclean; \
  apt-get autoremove --yes; \
  rm -rf \
    /config/.cache \
    /var/lib/apt/lists/* \
    /var/lib/{apt,dpkg,cache,log} \
    /var/tmp/* \
    /tmp/* \
    ;

# Install golang
RUN set -eux; \
	wget -q https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz; \
  rm -rf /usr/local/go; \
  tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz; \
  rm go${GOLANG_VERSION}.linux-amd64.tar.gz; \
  mkdir -p /go; \
  chown "${USER_ID}:${GROUP_ID}" /go; \
  chmod 755 /go; \
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile; \
  echo 'GOPATH=/go' >> /etc/profile; \
  /usr/local/go/bin/go version;
#ENV PATH="/usr/local/go/bin:${PATH}"

# Install nvm and nodejs
RUN set -eux; \
  mkdir -p /usr/local/nvm; \
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | PROFILE=/etc/profile NVM_DIR=/usr/local/nvm bash; \
  bash -c "source /etc/profile && echo node_version && node -v && echo npm_version && npm -v" \
  ;

# Install Claude CLI
# Claude devcontainer: https://github.com/anthropics/claude-code/blob/main/.devcontainer/
RUN if [[ "${CLAUDE_SETUP}" == "true" ]]; then bash -c "source /etc/profile && npm install -g @anthropic-ai/claude-code"; fi

RUN set -eux; \
  mkdir -p /usr/local/ytdlp; \
	wget -q -O /usr/local/ytdlp/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux; \
  chmod 755 /usr/local/ytdlp/yt-dlp; \
  echo 'export PATH=$PATH:/usr/local/ytdlp' >> /etc/profile; \
  /usr/local/ytdlp/yt-dlp --version;

# Create a user with password
RUN set -eux; \
  groupadd -g "${GROUP_ID}" "${DEV_USER}"; \
  useradd -u "${USER_ID}" -m -g "${GROUP_ID}" -s /bin/bash "${DEV_USER}"; \
  mkdir -p "/home/${DEV_USER}/workspace"; \
  usermod -aG sudo "${DEV_USER}"; \
  echo "${DEV_USER}:${DEV_USER}" | chpasswd \
  ;

# Ensure the SSH directory exists
RUN set -eux; \
  mkdir -p /var/run/sshd; \
  mkdir -p /home/${DEV_USER}/.vscode-server; \
  mkdir -p /home/${DEV_USER}/.vscodium-server; \
  chown "${USER_ID}:${GROUP_ID}" /home/${DEV_USER}/.vscode-server; \
  chown "${USER_ID}:${GROUP_ID}" /home/${DEV_USER}/.vscodium-server;

# Allow root login (optional, for testing)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set root password (optional)
RUN echo 'root:root' | chpasswd

# Expose SSH port
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]   