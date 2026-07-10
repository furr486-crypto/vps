#!/bin/bash
set -e

# Ambil variabel dari Railway Env
USER="${SSH_USERNAME:-root}"
PASS="${SSH_PASSWORD:-thaipuri}"
KEYS="${AUTHORIZED_KEYS:-}"

echo "====================================================="
echo "        ENGINE VPS CERDAS (ON RAILWAY) NYALA        "
echo "====================================================="
echo "[Sistem] Memulai inisialisasi untuk user: $USER"

# 1. Generate SSH Host Keys jika belum ada
ssh-keygen -A

# 2. Konfigurasi SSHD bawaan
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 3. Buat user dinamis jika bukan root
if [ "$USER" != "root" ]; then
    if ! id "$USER" &>/dev/null; then
        echo "[Sistem] Membuat user baru: $USER..."
        useradd -m -s /bin/bash -g sudo "$USER"
        echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    fi
fi

# Atur password user
echo "$USER:$PASS" | chpasswd
echo "[Sistem] Kredensial masuk berhasil diatur."

# 4. AKTIVASI FITUR EVOLUSI (Melalui Penyimpanan /data)
if [ -d "/data" ]; then
    echo "[Persistensi] Penyimpanan eksternal /data terdeteksi."

    # A. Migrasi direktori Home ke penyimpanan permanen
    if [ "$USER" == "root" ]; then
        HOME_DIR="/root"
        PERSISTENT_HOME="/data/root_home"
    else
        HOME_DIR="/home/$USER"
        PERSISTENT_HOME="/data/$USER"
    fi

    if [ ! -d "$PERSISTENT_HOME" ]; then
        echo "[Persistensi] Membuat direktori home permanen di $PERSISTENT_HOME..."
        mkdir -p "$PERSISTENT_HOME"
        cp -a "$HOME_DIR/." "$PERSISTENT_HOME/" || true
        chown -R "$USER" "$PERSISTENT_HOME" || true
    fi
    usermod -d "$PERSISTENT_HOME" "$USER" || true
    export HOME="$PERSISTENT_HOME"

    # B. Integrasi Penyimpanan Biner Permanen ke Sistem PATH
    # Ini membuat aplikasi yang diinstal di /data/bin tidak hilang dan bisa dipanggil global
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

    # C. Fitur Booting Script Otomatis (Evolusi VPS)
    # Jika Anda ingin VPS menginstal aplikasi atau menyalakan bot saat dinyalakan, tulis di file ini.
    STARTUP_SCRIPT="/data/startup.sh"
    if [ ! -f "$STARTUP_SCRIPT" ]; then
        cat << 'EOF' > "$STARTUP_SCRIPT"
#!/bin/bash
# ======================================================================
# STARTUP.SH - Tulis script otomatisasi Anda di bawah baris ini.
# File ini berada di penyimpanan luar, artinya isinya akan tetap aman
# meskipun Railway direstart atau dideploy ulang dari GitHub.
# ======================================================================
echo "[Startup] Script otomatisasi awal berhasil dieksekusi secara aman."
EOF
        chmod +x "$STARTUP_SCRIPT"
        chown "$USER" "$STARTUP_SCRIPT" || true
    fi

    # Menjalankan script booting di background agar tidak menghentikan jalannya SSH
    echo "[Sistem] Menjalankan script otomatisasi awal (/data/startup.sh)..."
    bash "$STARTUP_SCRIPT" &
else
    echo "[Peringatan] Penyimpanan luar /data tidak ditemukan! Data Anda akan hilang jika server direstart."
fi

# 5. Konfigurasi login kunci SSH (jika disediakan)
CURRENT_HOME=$(eval echo ~$USER)
if [ -n "$KEYS" ]; then
    echo "[Keamanan] Memasang Authorized Keys untuk SSH tanpa sandi..."
    mkdir -p "$CURRENT_HOME/.ssh"
    echo "$KEYS" > "$CURRENT_HOME/.ssh/authorized_keys"
    chmod 700 "$CURRENT_HOME/.ssh"
    chmod 600 "$CURRENT_HOME/.ssh/authorized_keys"
    chown -R "$USER" "$CURRENT_HOME/.ssh" || true
fi

echo "[Sistem] Inisialisasi selesai. Menghidupkan layanan SSH..."
exec /usr/sbin/sshd -D
