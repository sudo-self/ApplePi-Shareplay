#!/bin/bash
# ApplePi.sh
# Install and configure Shairport Sync as AirPlay 2 Receiver on Kali Linux 32-bit Raspberry Pi 4

set -euo pipefail

# Check if running as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root (sudo)."
  exit 1
fi

echo "Updating system packages..."
apt-get update
apt-get upgrade -y

echo "Installing required packages..."
apt-get install -y \
  autoconf \
  automake \
  avahi-daemon \
  build-essential \
  git \
  libasound2-dev \
  libavahi-client-dev \
  libconfig-dev \
  libdaemon-dev \
  libpopt-dev \
  libssl-dev \
  libtool \
  xmltoman \
  pkg-config \
  libsoxr-dev \
  libplist-dev \
  libsodium-dev \
  libavutil-dev \
  libavcodec-dev \
  libavformat-dev \
  uuid-dev \
  libgcrypt-dev \
  qrencode \
  bluez \
  pulseaudio \
  alsa-utils

echo "Enabling Bluetooth services..."
systemctl enable --now hciuart.service || echo "Warning: hciuart.service not found or failed."
systemctl enable --now bluetooth.service || echo "Warning: bluetooth.service not found or failed."

echo "🔊 Setting audio output to 3.5mm headphone jack (not HDMI)..."
amixer -c 0 set 'Auto-Mute Mode' Disabled || true
amixer -c 0 set numid=3 1 || echo "Failed to set audio output. Run 'alsamixer' manually."

echo "Installing nqptp (AirPlay 2 support)..."
cd "$HOME"
rm -rf nqptp
git clone https://github.com/mikebrady/nqptp.git
cd nqptp
autoreconf -fi
./configure
make -j"$(nproc)"
make install

echo "Cloning and building Shairport Sync..."
cd "$HOME"
rm -rf shairport-sync
git clone https://github.com/mikebrady/shairport-sync.git
cd shairport-sync
autoreconf -fi

# Configure with AirPlay 2 support and required dependencies
./configure \
  --with-alsa \
  --with-avahi \
  --with-ssl=openssl \
  --with-soxr \
  --with-airplay-2 \
  --with-systemd \
  --with-metadata

make -j"$(nproc)"
make install

echo "🛠 Configuring Shairport Sync (/etc/shairport-sync.conf)..."
cat > /etc/shairport-sync.conf << 'EOF'
general = {
  name = "ApplePi";
  interpolation = "soxr";
  volume_range_db = 60;
  session_backend = "udp";
  statistics = "yes";
  metadata_enabled = "yes";
};

alsa = {
  output_device = "default";
  mixer_control_name = "PCM";
  mixer_device = "default";
  disable_synchronization = "no";
};

metadata = {
  enabled = "yes";
  include_cover_art = "yes";
  pipe_name = "/tmp/shairport-sync-metadata";
};
EOF

echo "Enabling and starting services..."
systemctl daemon-reload
systemctl enable --now nqptp.service || echo "Warning: nqptp.service not found or failed."
systemctl enable --now shairport-sync.service || echo "Warning: shairport-sync.service not found or failed."
systemctl enable --now avahi-daemon.service

echo "🔊 Setting ALSA PCM volume to 100%..."
amixer -q set PCM 100% || echo "Warning: 'PCM' mixer not found. Use 'alsamixer' to verify."

echo
echo "ApplePi setup complete!"
echo "Your Raspberry Pi should now show up as 'ApplePi' in AirPlay menus."
echo "If audio doesn't work, try running 'alsamixer' or reboot with: sudo reboot"
echo

echo "📱 QR code for reinstalling this script:"
qrencode -t ansiutf8 'curl -sSL https://raw.githubusercontent.com/sudo-self/ApplePi-Shareplay/main/ApplePi.sh | sudo bash' || echo "Install 'qrencode' to see QR code."

exit 0

