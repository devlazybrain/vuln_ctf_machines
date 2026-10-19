#!/bin/bash
# Author: devlazybrain — https://github.com/devlazybrain
# =====================================================================
# Machine 3 — "gauntlet"  | Level: MEDIUM
# Theme: web enum -> SQL injection (sqlmap) -> dump+crack hashes (john/hashcat)
#        -> SSH -> sudo -u pivot (awk, GTFOBins) -> capability privesc (python)
# Flags:  /home/mbrown/user.txt , /root/root.txt
# =====================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[*] M3 gauntlet: installing packages"
apt-get update -y
apt-get install -y openssh-server apache2 mariadb-server php php-mysqli libapache2-mod-php libcap2-bin gawk python3

# ---- fixed secrets / flags ----
MBROWN_PASS='chocolate'                 # crackable (present in rockyou.txt)
USER_FLAG='FLAG{sqli_dump_crack_login}'
ROOT_FLAG='FLAG{c4p_s3tu1d_pyth0n_r00t}'

# ---- users ----
id mbrown &>/dev/null || useradd -m -s /bin/bash mbrown
echo "mbrown:${MBROWN_PASS}" | chpasswd
id svc &>/dev/null || useradd -m -s /bin/bash svc
echo "svc:$(openssl rand -base64 24)" | chpasswd      # unknown; reached via sudo -u

echo "$USER_FLAG" > /home/mbrown/user.txt
chown mbrown:mbrown /home/mbrown/user.txt
chmod 644 /home/mbrown/user.txt
echo "$ROOT_FLAG" > /root/root.txt
chmod 600 /root/root.txt

# ---- database (hashes computed by the DB so they are always correct) ----
echo "[*] M3 gauntlet: configuring MariaDB"
systemctl enable mariadb
systemctl start mariadb
mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS devhub;
CREATE USER IF NOT EXISTS 'webapp'@'localhost' IDENTIFIED BY 'devhubpass';
GRANT SELECT ON devhub.* TO 'webapp'@'localhost';
USE devhub;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;
CREATE TABLE products(id INT, title VARCHAR(100), description VARCHAR(255));
INSERT INTO products VALUES
 (1,'DevHub Pro','Team collaboration suite'),
 (2,'DevHub CI','Continuous integration runner'),
 (3,'DevHub Pages','Static site hosting');
CREATE TABLE users(id INT, username VARCHAR(50), password CHAR(32));
INSERT INTO users VALUES
 (1,'mbrown', MD5('chocolate')),
 (2,'alice',  MD5('princess')),
 (3,'admin',  MD5('Zx9!qW3r#Tv7_longstrong'));
FLUSH PRIVILEGES;
SQL

# ---- web application (injectable search) ----
echo "[*] M3 gauntlet: deploying web app"
WROOT=/var/www/html
rm -f "$WROOT"/index.html
cat > "$WROOT/index.php" <<'PHP'
<!doctype html><html><head><title>DevHub</title>
<style>body{font-family:sans-serif;max-width:720px;margin:40px auto;color:#222}</style></head>
<body>
<h1>DevHub</h1>
<p>Developer tools catalogue.</p>
<form action="search.php" method="get">
  <input name="q" placeholder="search products">
  <button>Search</button>
</form>
</body></html>
PHP

cat > "$WROOT/search.php" <<'PHP'
<?php
$con = @new mysqli('localhost','webapp','devhubpass','devhub');
$q = $_GET['q'] ?? '';
// NOTE: intentionally vulnerable (string concatenation, injectable)
$sql = "SELECT id,title,description FROM products WHERE title LIKE '%$q%'";
$res = $con->query($sql);
echo "<!doctype html><html><head><title>DevHub search</title>";
echo "<style>body{font-family:sans-serif;max-width:720px;margin:40px auto}td{padding:4px 10px}</style></head><body>";
echo "<h2>Search results</h2><p><a href='index.php'>&larr; back</a></p><table>";
if ($res) {
  while ($row = $res->fetch_assoc()) {
    echo "<tr><td>".htmlspecialchars($row['title'])."</td><td>".htmlspecialchars($row['description'])."</td></tr>";
  }
} else {
  echo "<tr><td>query error</td></tr>";
}
echo "</table></body></html>";
PHP

systemctl enable apache2
systemctl restart apache2

# ---- privesc step 1: mbrown -> svc via sudo -u (awk, GTFOBins) ----
echo 'mbrown ALL=(svc) NOPASSWD: /usr/bin/awk' > /etc/sudoers.d/mbrown
chmod 440 /etc/sudoers.d/mbrown

# ---- privesc step 2: svc -> root via file capability on a python copy ----
cp /usr/bin/python3 /usr/local/bin/python3cap
setcap cap_setuid+ep /usr/local/bin/python3cap

# ---- SSH password auth ----
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl enable ssh
systemctl restart ssh

echo "[*] M3 gauntlet provisioning complete"
