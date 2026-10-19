# FlagTrail — Linux CTF recruiting machine

A small, self-contained **intentionally vulnerable** Linux VM (Debian 13) for
testing candidates before you let them on your team. Six flags, in a deliberate
chain from anonymous web recon to root. **Only** the vulnerabilities needed for
those six flags are present — nothing extra.

> ⚠️ **Training target. Host-only network only.** Never bridge it to a real
> network or expose it to the internet. The weaknesses here are intentional.

---

## What's here

| File | For | Contents |
|------|-----|----------|
| `launch_instructions.html` | you (admin) | import, network, boot & reset the VM |
| `challenger_instruction.html` | candidates | brief + self-check flag submitter (validates by hash) |
| `writeup.html` | you (grader) | **full walkthrough + rubric — SPOILERS** |

The VM image itself (`FlagTrail-Linux-CTF.ova`) is distributed under
[**Releases**](../../releases) — it is too large to live in the repo.

## Quick start

1. Get the image from **Releases**. It ships as two parts (GitHub caps assets
   at 2 GB) — download both and reassemble:
   ```bash
   cat FlagTrail-Linux-CTF.part00.ova FlagTrail-Linux-CTF.part01.ova > FlagTrail-Linux-CTF.ova
   sha256sum -c FlagTrail-Linux-CTF.ova.sha256   # should print: OK
   ```
   Then import it in VirtualBox (**File → Import Appliance**). Full steps: `launch_instructions.html`.
2. Set **Adapter 1 = Host-only** before first boot. Do not use bridged.
3. Boot it, then find its IP from an attacker box on the same host-only net:
   ```bash
   nmap -sn 192.168.56.0/24
   ```
4. Hand the candidate only the IP (and maybe "there's an SMB share"). Give them
   `challenger_instruction.html` to submit flags. Watch how far they get.

## The challenge (no spoilers)

Six flags, each gating the next — from anonymous web recon through an SSH
foothold and a localhost-only service to a root privilege escalation. What each
flag tests, the full solve path, and the recruiting rubric are in `writeup.html`
(keep that one to yourself).

## Why it's "minimal" (no unintended vulns)
- Web app is **static** — no RCE, no upload, no injection.
- The foothold user is in **no** admin group; it has exactly one narrow sudo right.
- SMB is a **single read-only guest share** — no write, no home shares, no printers.
- The internal page is bound to **127.0.0.1 only** — unreachable without a tunnel.
- SSH: root login disabled, password auth for the one lab user only.
- The root flag is `0600 root:root`; each flag is reachable only at its intended stage.
