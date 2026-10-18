#!/usr/bin/env bash
# ============================================================================
#  FlagTrail CTF - automated OVA builder (VirtualBox 7.x)
#
#  Does an unattended Debian install, provisions the lab over SSH (key auth),
#  then exports a self-contained .ova.
#
#  Requires on the host: VBoxManage, ssh/scp, a Debian netinst ISO.
#  Usage:  ./build_ova.sh
#  Override via env: VM_NAME, ISO, OUT_OVA, BUILD_DIR, KEY, MEM, DISK_MB, CPUS
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VM_NAME="${VM_NAME:-FlagTrail-CTF}"
ISO="${ISO:?set ISO=/path/to/debian-netinst.iso}"
OUT_OVA="${OUT_OVA:-$KIT_ROOT/FlagTrail-Linux-CTF.ova}"
BUILD_DIR="${BUILD_DIR:-$KIT_ROOT/.build}"
KEY="${KEY:?set KEY=/path/to/provkey (private key; provkey.pub next to it)}"
MEM="${MEM:-2048}"
DISK_MB="${DISK_MB:-20000}"
CPUS="${CPUS:-2}"
SSH_PORT="${SSH_PORT:-2222}"

PUBKEY="$(cat "${KEY}.pub")"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o LogLevel=ERROR -i $KEY -p $SSH_PORT"

log(){ echo -e "\n=== $* ==="; }

# ---------------------------------------------------------------------------
log "cleaning any previous build VM"
VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
sleep 2
VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------------------
log "creating VM"
VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register --basefolder "$BUILD_DIR"
VBoxManage modifyvm "$VM_NAME" --memory "$MEM" --cpus "$CPUS" --vram 16 \
    --nic1 nat --audio-driver none --usb off --graphicscontroller vmsvga
VBoxManage modifyvm "$VM_NAME" --natpf1 "ssh,tcp,,${SSH_PORT},,22"

VBoxManage createhd --filename "$BUILD_DIR/$VM_NAME/$VM_NAME.vdi" --size "$DISK_MB" --variant Standard
VBoxManage storagectl "$VM_NAME" --name SATA --add sata --controller IntelAhci --portcount 2
VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 0 --device 0 --type hdd \
    --medium "$BUILD_DIR/$VM_NAME/$VM_NAME.vdi"

# ---------------------------------------------------------------------------
log "preparing unattended Debian install"
# NOTE: VirtualBox runs --post-install-command via log_command in the INSTALLER
# environment (NOT chrooted into the target), and splits on ';'. So we keep the
# command as a single argv that chroots into /target and runs a base64'd script
# (base64 is quote-safe, avoiding all shell-escaping problems).
PREP_SRC="$(mktemp)"
cat > "$PREP_SRC" <<PREP
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y openssh-server
# enable ssh for next boot (chroot-safe: maintainer scripts + explicit symlink)
deb-systemd-helper enable ssh.service 2>/dev/null || true
ln -sf /usr/lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service 2>/dev/null || true
ln -sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service 2>/dev/null || true
install -d -m700 /root/.ssh
cat > /root/.ssh/authorized_keys <<'KEYEOF'
${PUBKEY}
KEYEOF
chmod 600 /root/.ssh/authorized_keys
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
touch /root/.provisioned-ready
true
PREP
PREP_B64="$(base64 -w0 "$PREP_SRC")"
rm -f "$PREP_SRC"
POST="chroot /target /bin/bash -c \"echo ${PREP_B64} | base64 -d > /root/prep.sh && /bin/bash /root/prep.sh\""

VBoxManage unattended install "$VM_NAME" \
    --iso="$ISO" \
    --user=hasker --password='DoppiPomidor!27' --full-user-name='hasker' \
    --hostname=doppiomart.local \
    --locale=en_US --country=US --time-zone=UTC \
    --post-install-command="$POST" \
    --start-vm=headless

# ---------------------------------------------------------------------------
log "waiting for installer to finish and SSH to come up (this takes a while)"
ok=0
for i in $(seq 1 120); do   # up to ~40 min
    if ssh $SSH_OPTS root@127.0.0.1 'test -f /root/.provisioned-ready' 2>/dev/null; then ok=1; break; fi
    sleep 20
    printf '.'
done
echo
[ "$ok" = 1 ] || { echo "ERROR: VM did not become reachable in time"; exit 1; }
log "SSH is up"

# ---------------------------------------------------------------------------
log "copying kit and provisioning (one session: provision -> cleanup -> poweroff)"
ssh $SSH_OPTS root@127.0.0.1 'rm -rf /opt/kit && mkdir -p /opt/kit'
tar -C "$KIT_ROOT" --exclude='.build' --exclude='*.ova' -czf - web smb provision \
    | ssh $SSH_OPTS root@127.0.0.1 'tar -C /opt/kit -xzf -'

# IMPORTANT: setup.sh disables root SSH (PermitRootLogin no) and restarts sshd.
# An already-authenticated session survives a sshd restart, so provisioning,
# cleanup, and the poweroff trigger must all happen in THIS single session.
# New root SSH connections will (correctly) be refused afterwards.
ssh $SSH_OPTS root@127.0.0.1 '
  set -e
  bash /opt/kit/provision/setup.sh
  echo "[*] removing provisioning key + build artifacts"
  rm -rf /root/.ssh /root/.provisioned-ready /opt/kit
  apt-get clean || true
  rm -rf /var/lib/apt/lists/*
  : > /root/.bash_history 2>/dev/null || true
  sync
  echo "[*] scheduling poweroff"
  nohup sh -c "sleep 3; systemctl poweroff" >/dev/null 2>&1 &
  exit 0'

# ---------------------------------------------------------------------------
log "waiting for poweroff"
for i in $(seq 1 30); do
    state=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -E '^VMState=' | cut -d'"' -f2)
    [ "$state" = "poweroff" ] && break
    sleep 3
done
VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
sleep 3

# ---------------------------------------------------------------------------
log "reconfiguring network for distribution (host-only) + detaching ISO"
VBoxManage modifyvm "$VM_NAME" --natpf1 delete ssh 2>/dev/null || true
VBoxManage modifyvm "$VM_NAME" --nic1 hostonly --hostonlyadapter1 vboxnet0
# Detach installer ISO if still attached
VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 1 --device 0 --type dvddrive --medium none 2>/dev/null || true

# ---------------------------------------------------------------------------
log "exporting OVA -> $OUT_OVA"
rm -f "$OUT_OVA"
VBoxManage export "$VM_NAME" --output "$OUT_OVA" \
    --vsys 0 \
    --product "FlagTrail Linux CTF" \
    --vendor "DoppioMart Lab" \
    --description "Intentionally vulnerable training target. Host-only use only."

log "DONE"
ls -lh "$OUT_OVA"
