# Vulnerable Linux Boxes — practice lab

Four self-contained, intentionally vulnerable **Debian** machines (easy → hard)
for hands-on security practice, exams, or self-training. Each box has flags, a
built-in **flag checker**, and a full HTML **write-up**.

Open **[`index.html`](index.html)** in a browser for the styled front page.

| Box | Level | Skills | Challenge | Host guide | Write-up |
|-----|-------|--------|-----------|-----------|----------|
| **recovery** | easy | enumeration, forensics, privesc | [challenge](m1-recovery/challenger_instructions.html) | [host](m1-recovery/instructions.html) | [solution](m1-recovery/writeup.html) |
| **webwork** | easy–medium | web, SQLi, file upload, privesc | [challenge](m2-webwork/challenger_instructions.html) | [host](m2-webwork/instructions.html) | [solution](m2-webwork/writeup.html) |
| **gauntlet** | medium | SQLi, hash cracking, sudo, capabilities | [challenge](m3-gauntlet/challenger_instructions.html) | [host](m3-gauntlet/instructions.html) | [solution](m3-gauntlet/writeup.html) |
| **flagtrail** | hard | web recon, SMB, SSH, pivoting, privesc (6 flags) | [challenge](flagtrail/challenger_instructions.html) | [host](flagtrail/instructions.html) | [solution](flagtrail/writeup.html) |

Each machine folder holds its three docs:

- **`instructions.html`** — *host*: import, network, run (incl. on a server), reset.
- **`challenger_instructions.html`** — *player*: scenario, objective, rules, and
  a flag checker (answers stored only as salted hashes — the flag is never in
  the page source). The player sets the **Target IP** once and it fills into
  every command; each command has its own copy button.
- **`writeup.html`** — the full walkthrough (**spoilers**).

## Get the machines

The VM images (`*.ova`) are too large for the repo, so they are published under
**[Releases](https://github.com/devlazybrain/vuln_ctf_machines/releases)**. Download the box's `.ova` (a large one may be
split into parts — `cat part00 part01 > box.ova`), then import it:

```bash
VBoxManage import <box>.ova
```

You need **VirtualBox** (or any hypervisor — the host guide shows how to convert
the `.ova` for KVM/Proxmox/VMware). No build step is needed to *use* a box.

## Run a box

Set the VM's network adapter to a **Host-only** network and boot. Find its IP
from the host and give that to the player as the target:

```bash
sudo nmap -sn 192.168.56.0/24
```

> ⚠️ These machines are intentionally vulnerable. **Never** attach them to a
> bridged/public network or expose them to the internet — keep them on an
> isolated host-only (or internal) network.

Run headless on a server with `VBoxManage startvm "<vm>" --type headless`, and
reset between players with a VirtualBox snapshot (instant). Full steps — including
other hypervisors — are in each box's **host guide** (`instructions.html`).

## Repository layout

```
index.html                     front page
m1-recovery/                   recovery (easy)
  instructions.html  challenger_instructions.html  writeup.html
m2-webwork/                    webwork (easy–medium)
m3-gauntlet/                   gauntlet (medium)
flagtrail/                     flagtrail (hard, 6 flags)
  instructions.html  challenger_instructions.html  writeup.html
```

The `.ova` images live under **Releases**, not in the repo. Build scripts for
each box are included (`build-all.sh`, `common/`, each box's `provision.sh` /
`Vagrantfile`, and `flagtrail/provision/`) for anyone who wants to rebuild from
source, but they are not needed to run the boxes.

## Credits

Built by **[devlazybrain](https://github.com/devlazybrain)**. Free to use for
learning, teaching, and self-practice.
