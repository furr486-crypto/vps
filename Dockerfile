FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Update & Instal Paket Utama
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    nano \
    build-essential \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Instal Cloudflared (Klien Terowongan Cloudflare) secara resmi
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared.deb \
    && rm cloudflared.deb

# 3. Direktori proses SSH
RUN mkdir -p /var/run/sshd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
