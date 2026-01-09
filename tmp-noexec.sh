#!/bin/bash

# ==========================================
# Script Name: tmp-noexec.sh
# Target: Debian 10/11/12 & Ubuntu 20.04/22.04/24.04
# Description: Harden /tmp & /var/tmp with noexec, ensuring apt compatibility.
# Repo: https://github.com/sectojoy/linux-tmp-hardening
# ==========================================

set -e

# 1. Check for Root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this script with sudo (or as root)."
  exit 1
fi

# 2. OS Detection
# Ensures script only runs on supported Debian-based systems
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" && "$ID" != "ubuntu" && "$ID_LIKE" != *"debian"* ]]; then
        echo "❌ Error: This script is strictly for Debian or Ubuntu systems."
        echo "   Current OS Detected: $ID"
        exit 1
    fi
    echo "✅ OS Checked: $NAME detected. Proceeding..."
else
    echo "❌ Error: Cannot detect OS information. /etc/os-release not found."
    exit 1
fi

echo "=== Starting /tmp Directory Hardening ==="

# 3. Smart Backup of fstab
if [ ! -f /etc/fstab.bak ]; then
    cp /etc/fstab /etc/fstab.bak
    echo "✅ Original backup created: /etc/fstab.bak"
else
    echo "ℹ️  Original backup already exists, skipping backup step."
fi

# 4. Configure /tmp (tmpfs + noexec)
TMP_LINE="tmpfs /tmp tmpfs defaults,rw,nosuid,nodev,noexec,relatime,size=2G 0 0"

if grep -q "[[:space:]]/tmp[[:space:]]" /etc/fstab; then
    # Check if it is tmpfs type
    if grep -q "^tmpfs[[:space:]]\+/tmp" /etc/fstab; then
        echo "🔄 /tmp configuration exists (tmpfs), updating security options..."
        sed -i "s|^tmpfs[[:space:]]\+/tmp.*|$TMP_LINE|" /etc/fstab
    else
        echo "⚠️  Warning: /tmp appears to be a physical partition mount."
        echo "❌ Skipping modification to prevent data loss. Please check manually."
        exit 1
    fi
else
    echo "➕ Adding /tmp tmpfs configuration..."
    echo "$TMP_LINE" >> /etc/fstab
fi

# 5. Configure /var/tmp (Bind to /tmp)
VAR_TMP_LINE="/tmp /var/tmp none defaults,bind 0 0"

if grep -q "[[:space:]]/var/tmp[[:space:]]" /etc/fstab; then
    echo "🔄 /var/tmp configuration exists, ensuring bind mode..."
    sed -i "\|[[:space:]]/var/tmp[[:space:]]|d" /etc/fstab
    echo "$VAR_TMP_LINE" >> /etc/fstab
else
    echo "➕ Adding /var/tmp bind configuration..."
    echo "$VAR_TMP_LINE" >> /etc/fstab
fi

# 6. Configure APT Hook (Universal for Debian/Ubuntu)
APT_CONF="/etc/apt/apt.conf.d/99tmp-exec-fix"
echo "⚙️  Configuring APT hook: $APT_CONF"

cat > "$APT_CONF" <<EOF
# Automatically remount as exec before dpkg/apt runs, and restore noexec afterwards
# Created by harden_tmp script
DPkg::Pre-Invoke {"mount -o remount,exec /tmp";};
DPkg::Post-Invoke {"mount -o remount,noexec /tmp";};
EOF
chmod 644 "$APT_CONF"

# 7. Apply Changes
echo "🔄 Applying mount configurations..."

# Reload systemd manager configuration if available
if command -v systemctl &> /dev/null; then
    systemctl daemon-reload
fi

# Apply mounts
mount -a 2>/dev/null || echo "⚠️  Note: 'mount -a' returned warnings, safe to ignore."
mount -o remount,noexec /tmp

# 8. Verification
echo "========================================"
echo "           Verification Results"
echo "========================================"

# Verify /tmp
if mount | grep "on /tmp" | grep -q "noexec"; then
    echo "✅ /tmp Status: SECURE (noexec)"
else
    echo "❌ /tmp Status: INSECURE (exec permission present)"
fi

# Verify /var/tmp
if mount | grep "on /var/tmp"; then
    echo "✅ /var/tmp Status: MOUNTED (Inherits /tmp permissions)"
    # Use findmnt if available
    if command -v findmnt &> /dev/null; then
        echo "ℹ️  Mount Details:"
        findmnt /var/tmp | tail -n 1
    fi
else
    echo "❌ /var/tmp Status: NOT MOUNTED"
fi

echo "========================================"
echo "Setup complete. Please run 'sudo apt update' to verify package manager compatibility."
