#!/bin/bash
# =====================================================================
# finalize.sh — runs LAST on every box.
# Removes the Vagrant build account's power so candidates can't abuse it,
# then cleans logs/history and zeroes free space to shrink the .ova.
# This severs Vagrant's own SSH access, which is fine: build-all.sh
# powers the VM off with VBoxManage and exports it afterwards.
# =====================================================================
set -uo pipefail
echo "[*] finalize: locking down build account + cleanup"

# Neutralise the 'vagrant' provisioning account (insecure key + NOPASSWD sudo)
if id vagrant &>/dev/null; then
  passwd -l vagrant           || true
  usermod -s /usr/sbin/nologin vagrant || true
  rm -rf /home/vagrant/.ssh
fi
rm -f /etc/sudoers.d/vagrant

# Drop any leftover insecure authorized_keys elsewhere
rm -f /root/.ssh/authorized_keys 2>/dev/null || true

# Cleanup to keep the image small and tidy
apt-get clean || true
rm -rf /var/lib/apt/lists/*
find /root /home -maxdepth 2 -name ".bash_history" -delete 2>/dev/null || true
history -c 2>/dev/null || true
journalctl --rotate 2>/dev/null || true
journalctl --vacuum-time=1s 2>/dev/null || true
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true

# Zero free space so the exported OVA compresses well
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "[*] finalize: done (the 'vagrant' account is now disabled)"
