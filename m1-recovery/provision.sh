#!/bin/bash
# =====================================================================
# Machine 1 — "recovery"  | Level: EASY
# Theme: enumeration + FORENSIC recovery + simple sudo privesc
# Flags:  user flag is RECOVERED from a deleted file inside a disk image
#         root flag is in /root/root.txt after a GTFOBins sudo escape
# =====================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[*] M1 recovery: installing packages"
apt-get update -y
apt-get install -y openssh-server vsftpd apache2 e2fsprogs

# ---- fixed secrets / flags (keep in sync with EXAMINER-GUIDE.md) ----
JDOE_PASS='sunshine2019'
USER_FLAG='FLAG{f0r3ns1c_c4rv1ng_r3c0v3ry}'
ROOT_FLAG='FLAG{sud0_f1nd_g1v3s_r00t}'

# ---- user ----
id jdoe &>/dev/null || useradd -m -s /bin/bash jdoe
echo "jdoe:${JDOE_PASS}" | chpasswd

# ---- root flag ----
echo "$ROOT_FLAG" > /root/root.txt
chmod 600 /root/root.txt

# ---- build the forensic disk image with a DELETED credentials file ----
echo "[*] M1 recovery: building forensic disk image"
IMG=/srv/artifacts/disk_backup.img
mkdir -p /srv/artifacts /mnt/forensic
dd if=/dev/zero of="$IMG" bs=1M count=16 status=none
mkfs.ext4 -q -F "$IMG"
mount -o loop "$IMG" /mnt/forensic
cat > /mnt/forensic/credentials.txt <<EOF
Recovery Corp - IT credential note (CONFIDENTIAL)
-------------------------------------------------
Host : recovery.lab
SSH  : jdoe
Pass : ${JDOE_PASS}

user flag: ${USER_FLAG}
EOF
# a little noise so the image is not a one-file trivial case
dd if=/dev/urandom of=/mnt/forensic/pad1.bin bs=512k count=2 status=none
dd if=/dev/urandom of=/mnt/forensic/pad2.bin bs=512k count=1 status=none
sync
rm -f /mnt/forensic/credentials.txt      # DELETE -> must be carved/recovered
sync
umount /mnt/forensic

# ---- serve the image over HTTP ----
echo "[*] M1 recovery: configuring Apache"
cp "$IMG" /var/www/html/disk_backup.img
cat > /var/www/html/index.html <<'EOF'
<!doctype html><html><head><title>Recovery Corp - File Server</title>
<style>body{font-family:sans-serif;max-width:720px;margin:40px auto;color:#222}</style></head>
<body>
<h1>Recovery Corp &mdash; Internal File Server</h1>
<p>A decommissioned workstation disk backup has been staged here for the IT audit.</p>
<ul>
  <li><a href="disk_backup.img">disk_backup.img</a> &mdash; raw disk image (16&nbsp;MB)</li>
</ul>
<p>Anonymous FTP is also enabled for legacy clients.</p>
<hr><small>ticket #4471 &mdash; please recover the old credentials from this image.</small>
</body></html>
EOF
rm -f /var/www/html/index.html.orig 2>/dev/null || true
systemctl enable apache2
systemctl restart apache2

# ---- anonymous FTP (same image) ----
echo "[*] M1 recovery: configuring vsftpd"
mkdir -p /srv/ftp/pub
cp "$IMG" /srv/ftp/pub/disk_backup.img
chown -R ftp:ftp /srv/ftp
chmod -R a-w /srv/ftp
cat > /etc/vsftpd.conf <<'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=YES
anon_root=/srv/ftp
no_anon_password=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
local_enable=NO
write_enable=NO
pam_service_name=vsftpd
secure_chroot_dir=/var/run/vsftpd/empty
EOF
mkdir -p /var/run/vsftpd/empty
systemctl enable vsftpd
systemctl restart vsftpd

# ---- sudo misconfig (GTFOBins: find) ----
echo 'jdoe ALL=(root) NOPASSWD: /usr/bin/find' > /etc/sudoers.d/jdoe
chmod 440 /etc/sudoers.d/jdoe

# ---- enable SSH password auth ----
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl enable ssh
systemctl restart ssh

echo "[*] M1 recovery provisioning complete"
