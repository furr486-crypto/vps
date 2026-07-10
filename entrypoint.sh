#!/bin/bash
set -e

USER="${SSH_USERNAME:-root}"
PASS="${SSH_PASSWORD:-thaipuri}"
KEYS="${AUTHORIZED_KEYS:-}"
TUNNEL_TOKEN="${TUNNEL_TOKEN:-}"

echo "=== VPS MANDIRI DARI GITHUB NYALA ==="

ssh-keygen -A

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

if [ "$USER" != "root" ]; then
    if ! id "$USER" &>/dev/null; then
        useradd -m -s /bin/bash -g sudo "$USER"
        echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    fi
fi

echo "$USER:$PASS" | chpasswd

# Setup Volume Permanen
if [ -d "/data" ]; then
    if [ "$USER" == "root" ]; then
        HOME_DIR="/root"
        PERSISTENT_HOME="/data/root_home"
    else
        HOME_DIR="/home/$USER"
        PERSISTENT_HOME="/data/$USER"
    fi

    if [ ! -d "$PERSISTENT_HOME" ]; then
        mkdir -p "$PERSISTENT_HOME"
        cp -a "$HOME_DIR/." "$PERSISTENT_HOME/" || true
        chown -R "$USER" "$PERSISTENT_HOME" || true
    fi
    usermod -d "$PERSISTENT_HOME" "$USER" || true
    export HOME="$PERSISTENT_HOME"

    # Simpan binary permanen di PATH
    PERSISTENT_BIN="/data/bin"
    mkdir -p "$PERSISTENT_BIN"
    chown -R "$USER" "$PERSISTENT_BIN" || true

    PATH_LINE='export PATH="/data/bin:$PATH"'
    if ! grep -q "/data/bin" /etc/profile; then
        echo "$PATH_LINE" >> /etc/profile
    fi
    if ! grep -q "/data/bin" "$PERSISTENT_HOME/.bashrc"; then
        echo "$PATH_LINE" >> "$PERSISTENT_HOME/.bashrc"
    fi

    # Script Otomatisasi Booting
    STARTUP_SCRIPT="/data/startup.sh"
    if [ ! -f "$STARTUP_SCRIPT" ]; then
        cat << 'EOF' > "$STARTUP_SCRIPT"
#!/bin/bash
# Tulis perintah otomatis di sini (akan tetap aman dari restart)
EOF
        chmod +x "$STARTUP_SCRIPT"
        chown "$USER" "$STARTUP_SCRIPT" || true
    fi
    bash "$STARTUP_SCRIPT" &
fi

# Pemasangan Kunci SSH
CURRENT_HOME=$(eval echo ~$USER)
if [ -n "$KEYS" ]; then
    mkdir -p "$CURRENT_HOME/.ssh"
    echo "$KEYS" > "$CURRENT_HOME/.ssh/authorized_keys"
    chmod 700 "$CURRENT_HOME/.ssh"
    chmod 600 "$CURRENT_HOME/.ssh/authorized_keys"
    chown -R "$USER" "$CURRENT_HOME/.ssh" || true
fi

# Jalankan Cloudflare Tunnel
if [ -n "$TUNNEL_TOKEN" ]; then
    echo "[Sistem] Menghubungkan VPS ke Cloudflare Tunnel..."
    cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" &
fi

exec /usr/sbin/sshd -D
