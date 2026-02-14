FROM debian:stable

ARG GOLANG_VERSION=1.25
ARG DEV_USER=dev
ARG NVM_VERSION=v0.40.4
ARG NODE_VERSION=24

# Install OpenSSH server and essential tools
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
    openssh-server \
    sudo \
    which \
    hugo \
	; \

# Install golang
RUN set -eux; \
	wget https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz; \
  rm -rf /usr/local/go; \
  tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz; \
  rm go${GOLANG_VERSION}.linux-amd64.tar.gz; \
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile; \
  /usr/local/go/bin/go version;
ENV PATH="/usr/local/go/bin:${PATH}"

# Install nvm and nodejs
RUN set -eux; \
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | PROFILE=/etc/profile bash; \
  source /etc/profile && nvm install ${NODE_VERSION}; \
  node -v; \
  npm -v;

# Create a user with password
RUN useradd -m -s /bin/bash user && echo "${DEV_USER}:${DEV_USER}" | chpasswd

# Ensure the SSH directory exists
RUN mkdir -p /var/run/sshd

# Allow root login (optional, for testing)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set root password (optional)
RUN echo 'root:root' | chpasswd

# Expose SSH port
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]   