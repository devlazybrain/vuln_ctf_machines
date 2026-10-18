#!/usr/bin/env bash
# ============================================================================
#  FlagTrail CTF - guest provisioning
#  Run as root FROM the kit root (the dir that contains web/ and smb/).
#  Idempotent: safe to re-run.
# ============================================================================
set -euo pipefail

CTF_USER="hasker"
CTF_PASS='DoppiPomidor!27'

# Resolve kit root = parent of this script's dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
echo "[*] kit root: $KIT_ROOT"

if [[ $EUID -ne 0 ]]; then echo "run as root"; exit 1; fi

export DEBIAN_FRONTEND=noninteractive

echo "[*] installing packages (apache2, samba, openssh-server)..."
apt-get update -y
apt-get install -y --no-install-recommends \
    apache2 samba openssh-server python3 ca-certificates

# ---------------------------------------------------------------------------
# 1) User: hasker (foothold). Created with minimal privileges.
# ---------------------------------------------------------------------------
echo "[*] configuring user ${CTF_USER}..."
if ! id "$CTF_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$CTF_USER"
fi
echo "${CTF_USER}:${CTF_PASS}" | chpasswd

# MINIMAL PERMS: strip every admin/sudo group. hasker keeps only its own group.
for g in sudo admin adm wheel staff lpadmin; do
    gpasswd -d "$CTF_USER" "$g" 2>/dev/null || true
done
echo "    groups now: $(id "$CTF_USER")"

# ---------------------------------------------------------------------------
# 2) Web root - fake distraction storefront + /api + root.txt flag later
# ---------------------------------------------------------------------------
echo "[*] deploying web content..."
rm -rf /var/www/html
mkdir -p /var/www/html
cp -r "$KIT_ROOT/web/html/." /var/www/html/
chown -R root:root /var/www/html
find /var/www/html -type d -exec chmod 755 {} +
find /var/www/html -type f -exec chmod 644 {} +

# Apache: serve extensionless api files as text, alias /config, no extra modules
a2dismod -q userdir 2>/dev/null || true
a2enmod -q alias
cat > /etc/apache2/conf-available/doppiomart.conf <<'APACHE'
# DoppioMart demo site - intentionally exposed dev API (training lab)
<Directory /var/www/html>
    Options -Indexes +FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
<Directory /var/www/html/api>
    <FilesMatch "^(config|flag|health)$">
        ForceType text/plain
    </FilesMatch>
</Directory>
# Legacy alias referenced in robots.txt
Alias /config /var/www/html/api/config
<Location /config>
    ForceType text/plain
</Location>
APACHE
a2enconf -q doppiomart
sed -i 's/^ServerTokens.*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf 2>/dev/null || true
sed -i 's/^ServerSignature.*/ServerSignature Off/' /etc/apache2/conf-available/security.conf 2>/dev/null || true
systemctl enable apache2
systemctl restart apache2

# ---------------------------------------------------------------------------
# 3) Internal admin page - bound to 127.0.0.1:8000 (flag5 via SSH tunnel)
# ---------------------------------------------------------------------------
echo "[*] configuring localhost-only internal server (flag5)..."
mkdir -p /opt/internal
cp "$KIT_ROOT/web/internal/index.html" /opt/internal/index.html
chown -R root:root /opt/internal
chmod 755 /opt/internal && chmod 644 /opt/internal/index.html

cat > /etc/systemd/system/internal-admin.service <<'UNIT'
[Unit]
Description=DoppioMart internal admin (localhost only)
After=network.target

[Service]
Type=simple
# Bind ONLY to loopback: unreachable without SSH port forwarding.
ExecStart=/usr/bin/python3 -m http.server 8000 --bind 127.0.0.1 --directory /opt/internal
DynamicUser=yes
Restart=always
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable internal-admin.service
systemctl restart internal-admin.service

# ---------------------------------------------------------------------------
# 4) Samba - single read-only guest share exposing briefing.zip
# ---------------------------------------------------------------------------
echo "[*] configuring Samba public share..."
mkdir -p /srv/smb/public
cp "$KIT_ROOT/smb/1oy6dars.zip" /srv/smb/public/1oy6dars.zip
[ -f "$KIT_ROOT/smb/briefing.zip" ] && cp "$KIT_ROOT/smb/briefing.zip" /srv/smb/public/briefing.zip
chown -R root:root /srv/smb/public
chmod 755 /srv/smb/public
chmod 644 /srv/smb/public/*.zip

cat > /etc/samba/smb.conf <<'SMB'
[global]
   workgroup = WORKGROUP
   server string = DoppioMart Files
   security = user
   map to guest = Bad User
   guest account = nobody
   log file = /var/log/samba/log.%m
   max log size = 1000
   server role = standalone server
   # training lab: no printers, no home shares, nothing but [public]
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

[public]
   comment = DoppioMart public files
   path = /srv/smb/public
   browseable = yes
   read only = yes
   guest ok = yes
   guest only = yes
SMB
systemctl enable smbd
systemctl restart smbd
systemctl disable --now nmbd 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5) SSH - password auth for hasker, root login disabled
# ---------------------------------------------------------------------------
echo "[*] hardening SSH..."
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-ctf.conf <<'SSHD'
PasswordAuthentication yes
PermitRootLogin no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding yes
SSHD
systemctl enable ssh
systemctl restart ssh

# ---------------------------------------------------------------------------
# 6) sudo privesc - the ONLY sudo capability hasker has: /usr/bin/find
#    Intended: sudo find . -exec /bin/sh \; -quit   (GTFOBins) -> root
# ---------------------------------------------------------------------------
echo "[*] installing intentional sudo rule (flag6 vector)..."
cat > /etc/sudoers.d/ctf <<SUDO
# Training lab: deploy pipeline needs to run find as root. (intentionally unsafe)
${CTF_USER} ALL=(ALL) NOPASSWD: /usr/bin/find
SUDO
chmod 440 /etc/sudoers.d/ctf
visudo -cf /etc/sudoers.d/ctf

# ---------------------------------------------------------------------------
# 7) Flags
# ---------------------------------------------------------------------------
echo "[*] placing flags..."
# flag1 (robots) & flag2 (source) & flag3 (api) already baked into web files.

# flag4 - ssh home
echo 'FLAG{ssh_foothold_established}' > /home/${CTF_USER}/flag4.txt
chown ${CTF_USER}:${CTF_USER} /home/${CTF_USER}/flag4.txt
chmod 644 /home/${CTF_USER}/flag4.txt

# flag6 - root only
echo 'FLAG{sudo_find_is_a_classic_gtfobin}' > /root/root.txt
chown root:root /root/root.txt
chmod 600 /root/root.txt

# ---------------------------------------------------------------------------
# 8) Minimal-perms cleanup: make sure no accidental extra exposure
# ---------------------------------------------------------------------------
echo "[*] cleanup / least privilege checks..."
# web user owns nothing extra; api config readable only via web, not writable
chmod 644 /var/www/html/api/config /var/www/html/api/flag
# no password on sudo except the single find rule above (hasker not in sudo grp)
# disable apache default extra sites
a2dissite -q 000-default 2>/dev/null || true
a2ensite -q 000-default  # keep one site serving html
systemctl reload apache2 || systemctl restart apache2

echo
echo "[+] provisioning complete."
echo "    web  : http://<ip>/           (flag1 robots, flag2 source, flag3 /api)"
echo "    smb  : //<ip>/public/briefing.zip  (guest)"
echo "    ssh  : ${CTF_USER} / ${CTF_PASS}   (flag4 in home)"
echo "    tunnel: ssh -L 8000:127.0.0.1:8000 ${CTF_USER}@<ip>  -> http://127.0.0.1:8000 (flag5)"
echo "    root : sudo find . -exec /bin/sh \\; -quit  -> /root/root.txt (flag6)"
