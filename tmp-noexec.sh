#!/bin/bash

# ==========================================
# Script Name: tmp-noexec.sh
# Target: Ubuntu 20.04 / 22.04 / 24.04 (Debian based)
# Description: Secure /tmp and /var/tmp with noexec, ensuring apt compatibility.
# ==========================================

set -e # Exit immediately if a command exits with a non-zero status

# 0. Check for Root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this script with sudo"
  exit 1
fi

echo "=== Starting /tmp Directory Hardening (Final Optimized) ==="

# 1. Smart Backup of fstab
if [ ! -f /etc/fstab.bak ]; then
    cp /etc/fstab /etc/fstab.bak
    echo "✅ Original backup created: /etc/fstab.bak"
else
    echo "ℹ️  Original backup already exists, skipping backup step."
fi

# 2. Configure /tmp (Ensure tmpfs and include noexec)
TMP_LINE="tmpfs /tmp tmpfs defaults,rw,nosuid,nodev,noexec,relatime,size=2G 0 0"

if grep -q "[[:space:]]/tmp[[:space:]]" /etc/fstab; then
    # Check if it is tmpfs type to avoid modifying physical partitions
    if grep -q "^tmpfs[[:space:]]\+/tmp" /etc/fstab; then
        echo "🔄 /tmp configuration exists (tmpfs), updating security options..."
        sed -i "s|^tmpfs[[:space:]]\+/tmp.*|$TMP_LINE|" /etc/fstab
    else
        echo "⚠️  Warning: /tmp appears to be a physical partition mount."
        echo "❌ Skipping modification to prevent potential data loss. Please check manually."
        exit 1
    fi
else
    echo "➕ Adding /tmp tmpfs configuration..."
    echo "$TMP_LINE" >> /etc/fstab
fi

# 3. Configure /var/tmp (Bind mount to /tmp)
VAR_TMP_LINE="/tmp /var/tmp none defaults,bind 0 0"

if grep -q "[[:space:]]/var/tmp[[:space:]]" /etc/fstab; then
    echo "🔄 /var/tmp configuration exists, forcing update to bind mode..."
    # Ensure a clean state by removing old config before adding the correct one
    sed -i "\|[[:space:]]/var/tmp[[:space:]]|d" /etc/fstab
    echo "$VAR_TMP_LINE" >> /etc/fstab
else
    echo "➕ Adding /var/tmp bind configuration..."
    echo "$VAR_TMP_LINE" >> /etc/fstab
fi

# 4. Configure APT Hook (Crucial for fixing 'apt update' permission errors)
APT_CONF="/etc/apt/apt.conf.d/99tmp-exec-fix"
echo "⚙️  Configuring APT hook: $APT_CONF"

cat > "$APT_CONF" <<EOF
# Automatically remount as exec before dpkg/apt runs, and restore noexec afterwards
# Created by harden_tmp script
DPkg::Pre-Invoke {"mount -o remount,exec /tmp";};
DPkg::Post-Invoke {"mount -o remount,noexec /tmp";};
EOF
chmod 644 "$APT_CONF"

# 5. Apply Changes
echo "🔄 Applying mount configurations..."

# Attempt to apply all configurations directly from fstab
# Suppress irrelevant 'already mounted' warnings
mount -a 2>/dev/null || echo "⚠️  Note: 'mount -a' returned some warnings, usually safe to ignore."

# Explicitly force remount /tmp to ensure noexec takes effect immediately
mount -o remount,noexec /tmp

# 6. Final Verification
echo "========================================"
echo "           Verification Results"
echo "========================================"

# Verify /tmp
if mount | grep "on /tmp" | grep -q "noexec"; then
    echo "✅ /tmp Status: SECURE (noexec)"
else
    echo "❌ /tmp Status: INSECURE (exec permission not removed)"
fi

# Verify /var/tmp
if mount | grep "on /var/tmp"; then
    echo "✅ /var/tmp Status: MOUNTED (Inherits /tmp permissions)"
    # Show findmnt details for reassurance
    echo "ℹ️  Mount Details (SOURCE should be /tmp):"
    findmnt /var/tmp | tail -n 1
else
    echo "❌ /var/tmp Status: NOT MOUNTED"
fi

echo "========================================"
echo "Script execution completed. Please run 'sudo apt update' for final testing."
