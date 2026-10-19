# Vulnerable Linux Boxes — practice lab

Three self-contained, intentionally vulnerable **Debian 12** machines (easy →
medium) for hands-on security practice, exams, or self-training. Each box has a
**user** flag and a **root** flag, a built-in **flag checker**, and a full
HTML **write-up**.

Open **[`index.html`](index.html)** in a browser for the styled front page, or
browse the pages directly.

| Box | Level | Skills | Challenge | Host guide | Write-up |
|-----|-------|--------|-----------|-----------|----------|
| **recovery** | easy | enumeration, forensics, privesc | [challenge](machines/m1-recovery/challenger_instructions.html) | [host](machines/m1-recovery/instructions.html) | [solution](writeups/m1-recovery.html) |
| **webwork** | easy–medium | web, SQLi, file upload, privesc | [challenge](machines/m2-webwork/challenger_instructions.html) | [host](machines/m2-webwork/instructions.html) | [solution](writeups/m2-webwork.html) |
| **gauntlet** | medium | SQLi, hash cracking, sudo, capabilities | [challenge](machines/m3-gauntlet/challenger_instructions.html) | [host](machines/m3-gauntlet/instructions.html) | [solution](writeups/m3-gauntlet.html) |

Each box ships three HTML docs:

- **`instructions.html`** — *host*: how to build, run, and reset the box.
- **`challenger_instructions.html`** — *player*: scenario, objective, rules, and
  a flag checker (answers stored only as salted hashes — the flag is never in
  the page source).
- **`writeups/<box>.html`** — the full walkthrough (**spoilers**).

## Build the machines

Requires **VirtualBox** and **Vagrant** on the host:

```bash
sudo apt update && sudo apt install -y virtualbox vagrant

cd machines
./build-all.sh            # build all three -> machines/ova/*.ova
# or one at a time:
./build-all.sh m2-webwork
```

The first build downloads the `debian/bookworm64` base box once (~500 MB) and
reuses it. Each finished `.ova` is ~0.7–1.2 GB. The build also disables the
Vagrant provisioning account, so the shipped machine has no build-time backdoor.

## Run a box

Import the `.ova` in VirtualBox, set its network adapter to a **Host-only**
network, and boot. Find its IP from the host with `sudo nmap -sn 192.168.56.0/24`
and give that to the player as the target.

> ⚠️ These machines are intentionally vulnerable. **Never** attach them to a
> bridged/public network or expose them to the internet — keep them on an
> isolated host-only (or internal) network.

Reset between players with a VirtualBox snapshot (instant, no rebuild) — see any
box's host guide. For headless/server use:
`VBoxManage startvm "lab-m1-recovery" --type headless`.

## Repository layout

```
index.html                     front page
machines/
  build-all.sh                 build + export all .ova files
  common/finalize.sh           lockdown + cleanup run on every box
  m1-recovery/   provision.sh  Vagrantfile  instructions.html  challenger_instructions.html
  m2-webwork/    ...
  m3-gauntlet/   ...
writeups/
  m1-recovery.html  m2-webwork.html  m3-gauntlet.html
```

Build artifacts (`ova/`, the Debian ISO, VM disks, keys) are git-ignored and
never committed.

## Credits

Built by **[devlazybrain](https://github.com/devlazybrain)**. Free to use for
learning, teaching, and self-practice.
