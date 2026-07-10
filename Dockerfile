# Menggunakan Ubuntu 24.04 LTS sebagai basis
FROM ubuntu:24.04

# Menghindari interaksi saat instalasi paket
ENV DEBIAN_FRONTEND=noninteractive

# Instalasi aplikasi inti penting
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

# Persiapan untuk direktori proses SSH
RUN mkdir -p /var/run/sshd

# Salin script inisialisasi cerdas
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ekspos port default SSH
EXPOSE 22

# Jalankan mesin inisialisasi
ENTRYPOINT ["/entrypoint.sh"]
