# Linux /tmp Hardening Script (Debian/Ubuntu)

A robust Bash script to automate the hardening of `/tmp` and `/var/tmp` directories on Debian-based systems.

By mounting temporary directories with the `noexec` option, this tool **effectively blocks the download and execution of crypto-miners, WebShells, and other malicious scripts**, serving as a critical first line of defense for your servers.

## 🛡️ Key Features

* **Automated Hardening**: Mounts `/tmp` as a `tmpfs` (RAM disk) with `noexec,nosuid,nodev` permissions.
* **Dual Protection**: Binds `/var/tmp` to `/tmp`, ensuring it inherits the same security policies.
* **Universal Compatibility**: Works seamlessly on **Ubuntu** and **Debian**.
* **APT Smart Hook**: Includes an automated APT Hook to temporarily allow execution only during updates (`apt update`), preventing permission errors.
* **Idempotent & Safe**: Checks OS type before running. Detects existing configurations to prevent duplication.
* **Auto-Backup**: Automatically backs up `/etc/fstab` before making changes.

## 💻 Supported OS

| OS | Versions |
| --- | --- |
| **Ubuntu** | 18.04 LTS, 20.04 LTS, 22.04 LTS, 24.04 LTS |
| **Debian** | 10 (Buster), 11 (Bullseye), 12 (Bookworm) |
| **Others** | Kali Linux, Linux Mint, Pop!_OS (Debian-based) |

## 🚀 Quick Start

Run the following command directly in your server terminal:

**Using wget:**

```bash
wget -O - https://raw.githubusercontent.com/sectojoy/linux-tmp-hardening/main/tmp-noexec.sh | sudo bash

```

**Using curl:**

```bash
curl -sL https://raw.githubusercontent.com/sectojoy/linux-tmp-hardening/main/tmp-noexec.sh | sudo bash

```

> **Note**: This script requires `root` privileges to modify system configurations.

---

## ✅ Verification

After the script completes, verify the hardening status:

### 1. Check Mount Permissions

Output must include `noexec`:

```bash
mount | grep -E '\s/tmp\s'
# Expected: tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime,size=2G)

```

### 2. Test Execution Block

Creating and running a script in `/tmp` should fail:

```bash
echo "echo 'Hacked'" > /tmp/test_exec.sh
chmod +x /tmp/test_exec.sh
/tmp/test_exec.sh
# Expected output: bash: /tmp/test_exec.sh: Permission denied

```

### 3. Test System Updates

Ensure APT still works correctly:

```bash
sudo apt update
# Expected result: Runs normally without errors.

```

---

## 🚑 Rollback

If you need to revert the changes, execute the following:

```bash
# 1. Restore original fstab
sudo cp /etc/fstab.bak /etc/fstab

# 2. Remove APT hook
sudo rm -f /etc/apt/apt.conf.d/99tmp-exec-fix

# 3. Reload configuration
if command -v systemctl &> /dev/null; then sudo systemctl daemon-reload; fi
sudo mount -a

# 4. Restore exec permission
sudo mount -o remount,exec /tmp

echo "✅ Rollback complete."

```

---

**Disclaimer**: Use this script at your own risk. Always backup your data before making system-level changes.
