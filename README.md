# Candidate Assessment Lab — 3 vulnerable Linux boxes

A small CTF-style assessment lab for screening new team members. Three
**independent** boxes, rising in difficulty. Each has a **user** flag and a
**root** flag (6 flags total). Everything is custom, so candidates can't find a
VulnHub/HTB walkthrough.

| Box | Level | Core skills | Foothold | Root |
|-----|-------|-------------|----------|------|
| **m1-recovery** | easy | enumeration, **forensics** | recover a deleted file from a disk image | `sudo find` (GTFOBins) |
| **m2-webwork** | easy-medium | web enum, SQLi, file upload, creds reuse | SQLi login bypass → `.phtml` webshell | world-writable root cron |
| **m3-gauntlet** | medium | web enum, SQLi (sqlmap), hash cracking, privesc | SQL injection → crack MD5 → SSH | `sudo -u` pivot → Linux capability |

> On m1 the flags come from **forensic recovery** (your spec). On m2 and m3 the
> flags are plain `user.txt` / `root.txt` in the user and root home dirs.

- `BRIEFING.md` — give this to candidates.
- `EXAMINER-GUIDE.md` — **examiner only**: flags, rubric, quick answers.
- `mN-*/SOLUTION.md` — full walkthrough per box (examiner only).

---

## 1. Requirements (on your Kali laptop)

```bash
sudo apt update && sudo apt install -y virtualbox vagrant
```

Disk/RAM while building: ~1 GB RAM and ~5 GB disk per box (built one at a time).
Each finished `.ova` is roughly 0.7–1.2 GB.

## 2. Build the `.ova` files

```bash
cd ~/machines
./build-all.sh            # builds all three
# or one at a time:
./build-all.sh m2-webwork
```

The script runs Vagrant (it auto-downloads the `debian/bookworm64` base box the
first time), provisions each box, powers it off, and exports it to
`ova/lab-mN-*.ova`. The build also **disables the Vagrant build account** so
candidates can't use it as a backdoor.

## 3. Run a box for an assessment

Import the `.ova` in VirtualBox (GUI: *File → Import Appliance*, or CLI):

```bash
VBoxManage import ova/lab-m2-webwork.ova
```

**Networking — give the box an IP the candidate can reach:**

- Create a host-only network once:
  *VirtualBox → Tools → Network → Host-only Networks → Create* (e.g. `vboxnet0`,
  DHCP enabled). 
- Set the imported VM's adapter to **Host-only Adapter → vboxnet0**, then boot.
- Find its IP from your Kali host: `nmap -sn 192.168.56.0/24` (or whatever the
  host-only subnet is). Tell the candidate that IP (your spec: IP is given).

> Prefer host-only over bridged so the vulnerable box is never exposed to your
> real LAN/internet. One box at a time is cleanest for scoring.

## 4. Reset between candidates

Take a snapshot right after import/boot, and *Restore* it after each candidate —
instant reset, no rebuild:

```bash
VBoxManage snapshot "lab-m2-webwork" take clean
# after a candidate:
VBoxManage controlvm "lab-m2-webwork" poweroff
VBoxManage snapshot "lab-m2-webwork" restore clean
```

## 5. Notes / assumptions

- Candidates are **told the target IP** and **may use tools** (nmap, gobuster,
  sqlmap, Metasploit, hashcat/john). Pass bar: **user + root on all three**.
- Linux only. No kernel-exploit dependence (vulns are misconfigurations and
  custom web code), so the boxes stay stable and fully offline.
- Password-cracking on m3 expects the standard `rockyou.txt` wordlist (ships on
  Kali at `/usr/share/wordlists/rockyou.txt.gz` — `gunzip` it once).
- The flags and credentials are fixed in each `provision.sh`; change them there
  and rebuild if you want fresh values per hiring round.
