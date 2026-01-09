# Linux /tmp Hardening Script (Ubuntu Security Hardening)

A robust Bash script to automate the hardening of `/tmp` and `/var/tmp` directories on Linux (Ubuntu/Debian).

By mounting temporary directories with the `noexec` option, this tool **effectively blocks the download and execution of crypto-miners, WebShells, and other malicious scripts**, serving as a critical first line of defense for your servers.

## 🛡️ Key Features

* **Automated Mount Hardening**: Mounts `/tmp` as a `tmpfs` (RAM disk) with `noexec,nosuid,nodev` permissions.
* **Dual Protection**: Binds `/var/tmp` to `/tmp`, ensuring it inherits the same security policies.
* **APT Compatibility**: Includes an automated APT Hook to temporarily allow execution during updates (`apt update` / `apt upgrade`), preventing permission errors.
* **Idempotent Design**: Safe to run multiple times. It detects existing configurations and applies fixes without duplicating entries.
* **Auto-Backup**: Automatically creates a backup of `/etc/fstab` on the first run, allowing for easy restoration.

## 🚀 Quick Start (One-Click Installation)

No need to manually download files. Run the following command directly in your server terminal to apply the hardening:

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

After the script completes, verify that the hardening is active:

### 1. Check Mount Permissions

Run the following command. The output must include `noexec`:

```bash
mount | grep -E '\s/tmp\s'
# Expected output example: tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime,size=2G)

```

### 2. Test Execution Block

Try to create and run a script in `/tmp`. You should see a **Permission denied** error:

```bash
echo "echo 'Hacked'" > /tmp/test_exec.sh
chmod +x /tmp/test_exec.sh
/tmp/test_exec.sh
# Expected output: bash: /tmp/test_exec.sh: Permission denied

```

### 3. Test System Updates

Ensure that system updates still work correctly:

```bash
sudo apt update
# Expected result: Runs normally without errors.

```

---

## 🚑 Rollback (Uninstall)

If you encounter compatibility issues (e.g., with specific compilation tasks requiring execution in `/tmp`), you can revert to the original state:

```bash
# 1. Restore the original fstab backup
sudo cp /etc/fstab.bak /etc/fstab

# 2. Remove the APT compatibility hook
sudo rm -f /etc/apt/apt.conf.d/99tmp-exec-fix

# 3. Reload systemd configuration
sudo systemctl daemon-reload

# 4. Remount and restore execution permissions
sudo mount -a
sudo mount -o remount,exec /tmp

echo "✅ System restored to pre-hardened state."

```

---

## ⚙️ Technical Details

The script modifies the following system files:

1. **/etc/fstab**:
* Adds or updates the `/tmp` entry to mount as `tmpfs` with: `rw,nosuid,nodev,noexec,relatime,size=2G`.
* Adds a Bind Mount for `/var/tmp` pointing to `/tmp`.


2. **/etc/apt/apt.conf.d/99tmp-exec-fix**:
* Injects `DPkg::Pre-Invoke` and `DPkg::Post-Invoke` hooks to remount `/tmp` as `exec` during installation and restore `noexec` immediately after.



## ⚠️ Compatibility Notes

* **Snap Applications**: A small number of Snap apps may attempt to execute binaries from hardcoded paths in `/tmp`, potentially causing crashes. Please test carefully if you rely heavily on Snap in a desktop environment.
* **Custom Compilation**: If you manually compile source code (`make` / `gcc`), the process might require execution rights in the temp directory. It is recommended to specify a different build directory: `mkdir ~/build_tmp && export TMPDIR=~/build_tmp`.

---

**Disclaimer**: Use this script at your own risk. Always backup your data before making system-level changes.
