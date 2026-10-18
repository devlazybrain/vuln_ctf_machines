#!/bin/bash
# =====================================================================
# Machine 2 — "webwork"  | Level: EASY-MEDIUM
# Theme: web enum -> SQLi login bypass -> upload-filter bypass (webshell)
#        -> config creds reuse -> world-writable cron privesc
# Flags:  /home/webdev/user.txt , /root/root.txt
# =====================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[*] M2 webwork: installing packages"
apt-get update -y
apt-get install -y openssh-server apache2 mariadb-server php php-mysqli libapache2-mod-php cron

# ---- fixed secrets / flags ----
WEBDEV_PASS='Summer#Breeze88'          # reused by DB app user -> system user
USER_FLAG='FLAG{upl04d_t0_w3bsh3ll_w1n}'
ROOT_FLAG='FLAG{cr0n_w0rld_wr1t4bl3_pwn}'

# ---- system user ----
id webdev &>/dev/null || useradd -m -s /bin/bash webdev
echo "webdev:${WEBDEV_PASS}" | chpasswd
echo "$USER_FLAG" > /home/webdev/user.txt
chown webdev:webdev /home/webdev/user.txt
chmod 644 /home/webdev/user.txt
echo "$ROOT_FLAG" > /root/root.txt
chmod 600 /root/root.txt

# ---- database ----
echo "[*] M2 webwork: configuring MariaDB"
systemctl enable mariadb
systemctl start mariadb
mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS snaphost;
CREATE USER IF NOT EXISTS 'appuser'@'localhost' IDENTIFIED BY 'Summer#Breeze88';
GRANT ALL PRIVILEGES ON snaphost.* TO 'appuser'@'localhost';
USE snaphost;
DROP TABLE IF EXISTS admins;
CREATE TABLE admins(id INT, username VARCHAR(50), password VARCHAR(100));
INSERT INTO admins VALUES (1,'admin','d7e3f8c0a1b2notreal');
FLUSH PRIVILEGES;
SQL

# ---- web application ----
echo "[*] M2 webwork: deploying web app"
WROOT=/var/www/html
rm -f "$WROOT"/index.html
mkdir -p "$WROOT/admin" "$WROOT/uploads"

cat > "$WROOT/index.php" <<'PHP'
<!doctype html><html><head><title>SnapHost</title>
<style>body{font-family:sans-serif;max-width:760px;margin:40px auto;color:#222}</style></head>
<body>
<h1>SnapHost</h1>
<p>Fast, friendly image hosting for your team.</p>
<p>Staff only: <a href="/admin/">admin console</a>.</p>
</body></html>
PHP

cat > "$WROOT/admin/index.php" <<'PHP'
<?php
session_start();
$con = @new mysqli('localhost','appuser','Summer#Breeze88','snaphost');
$err = '';
if (isset($_POST['username'])) {
  $u = $_POST['username'];
  $p = $_POST['password'];
  // NOTE: intentionally vulnerable (string concatenation)
  $sql = "SELECT * FROM admins WHERE username='$u' AND password='$p'";
  $res = $con->query($sql);
  if ($res && $res->num_rows > 0) {
    $_SESSION['auth'] = 1;
    header('Location: panel.php');
    exit;
  } else {
    $err = 'Invalid credentials';
  }
}
?>
<!doctype html><html><head><title>SnapHost admin</title>
<style>body{font-family:sans-serif;max-width:420px;margin:60px auto}input{display:block;width:100%;padding:8px;margin:6px 0}</style></head>
<body>
<h2>Admin login</h2>
<?php if($err) echo "<p style='color:#c00'>$err</p>"; ?>
<form method="post">
  <input name="username" placeholder="username">
  <input name="password" type="password" placeholder="password">
  <button>Sign in</button>
</form>
</body></html>
PHP

cat > "$WROOT/admin/panel.php" <<'PHP'
<?php
session_start();
if (!($_SESSION['auth'] ?? 0)) { header('Location: index.php'); exit; }
require __DIR__.'/config.php';   // DB creds live here
$msg = '';
if (isset($_FILES['avatar'])) {
  $name = basename($_FILES['avatar']['name']);
  $ext  = strtolower(pathinfo($name, PATHINFO_EXTENSION));
  // weak blocklist (misses .phtml / .pht)
  $blocked = ['php','php5','php4'];
  if (in_array($ext, $blocked)) {
    $msg = "Blocked file type: .$ext";
  } else {
    move_uploaded_file($_FILES['avatar']['tmp_name'], __DIR__.'/../uploads/'.$name);
    $msg = "Uploaded to /uploads/$name";
  }
}
?>
<!doctype html><html><head><title>SnapHost console</title>
<style>body{font-family:sans-serif;max-width:560px;margin:50px auto}</style></head>
<body>
<h2>Console</h2>
<p>Welcome, admin. Upload a new avatar image:</p>
<?php if($msg) echo "<p>$msg</p>"; ?>
<form method="post" enctype="multipart/form-data">
  <input type="file" name="avatar">
  <button>Upload</button>
</form>
</body></html>
PHP

cat > "$WROOT/admin/config.php" <<'PHP'
<?php
// SnapHost database configuration
$DB_HOST = 'localhost';
$DB_USER = 'appuser';
$DB_PASS = 'Summer#Breeze88';
$DB_NAME = 'snaphost';
PHP

# make .phtml execute as PHP (classic blocklist bypass)
cat > /etc/apache2/conf-available/phtml.conf <<'EOF'
<FilesMatch "\.(phtml|pht)$">
    SetHandler application/x-httpd-php
</FilesMatch>
EOF
a2enconf phtml

chown -R www-data:www-data "$WROOT/uploads"
chmod 755 "$WROOT/uploads"
systemctl enable apache2
systemctl restart apache2

# ---- privesc: world-writable script run by root cron ----
echo "[*] M2 webwork: configuring vulnerable cron"
mkdir -p /opt/scripts /var/backups
cat > /opt/scripts/backup.sh <<'EOF'
#!/bin/bash
# housekeeping job - runs as root every minute
tar -czf /var/backups/www.tgz /var/www/html >/dev/null 2>&1
EOF
chmod 777 /opt/scripts/backup.sh          # world-writable -> webdev can overwrite
echo '* * * * * root /opt/scripts/backup.sh' > /etc/cron.d/webbackup
chmod 644 /etc/cron.d/webbackup
systemctl enable cron
systemctl restart cron

# ---- SSH password auth ----
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl enable ssh
systemctl restart ssh

echo "[*] M2 webwork provisioning complete"
