FROM debian:stable

# Install OpenSSH server and essential tools
RUN apt-get update && apt-get install -y openssh-server sudo which

# Create a user (e.g., 'user') with password
RUN useradd -m -s /bin/bash user && echo "user:user" | chpasswd

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