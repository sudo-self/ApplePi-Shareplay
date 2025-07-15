#!/bin/bash

# ApplePi.sh: install and configure Shairport Sync as an AirPlay 2 Receiver
# on 32-bit Kali Linux for Raspberry Pi 4, named "ApplePi"

set -euo pipefail

# Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root (use sudo)."
  exit 1
fi

echo "Updating system and installing dependencies..."
apt-get update
apt-get upgrade -y
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
  libgcrypt-dev

# 🔧 Bluetooth fix for Kali on Raspberry Pi
echo "Enabling Bluetooth services for Raspberry Pi 4..."
systemctl enable --now hciuart.service
systemctl enable --now bluetooth.service

# 🔧 Set audio output to headphone jack (not HDMI)
echo "Switching audio output to 3.5mm jack..."
amixer -c 0 set numid=3 1 || echo "Failed to set audio output. Run 'alsamixer' manually."

# Build nqptp (AirPlay 2 support)
echo "Installing nqptp..."
cd "$HOME"
rm -rf nqptp
git clone https://github.com/mikebrady/nqptp.git
cd nqptp
autoreconf -fi
./configure
make -j"$(nproc)"
make install

# Build Shairport Sync
echo "Cloning and building Shairport Sync..."
cd "$HOME"
rm -rf shairport-sync
git clone https://github.com/mikebrady/shairport-sync.git
cd shairport-sync
autoreconf -fi
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

# Configure Shairport Sync
echo "Configuring Shairport Sync as 'ApplePi'..."
cat > /etc/shairport-sync.conf << 'EOF'
general =
{
  name = "ApplePi";
  volume_range_db = 60;
};

alsa =
{
  output_device = "default";
  mixer_control_name = "PCM";
};
EOF

# Enable and start services
echo "Enabling services..."
systemctl enable --now nqptp
systemctl enable --now shairport-sync
systemctl enable --now avahi-daemon

# Set volume
echo "Setting ALSA volume to 100%..."
amixer -q set PCM 100% || echo "Warning: 'PCM' mixer not found. Use 'alsamixer' to verify."

echo
echo "🍏 Apple Pi Baked!"
echo "Your Raspberry Pi should now appear as 'ApplePi' in the AirPlay menu."
echo "If there's no sound, try running 'alsamixer' or reboot the system:"
echo "sudo reboot"
exit 0



