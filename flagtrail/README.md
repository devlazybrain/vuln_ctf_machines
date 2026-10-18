# FlagTrail — Linux CTF recruiting machine

A small, self-contained **intentionally vulnerable** Linux VM (Debian 13) for
testing candidates before you let them on your team. Six flags, in a deliberate
chain from anonymous web recon to root. **Only** the vulnerabilities needed for
those six flags are present — nothing extra.

> ⚠️ **Training target. Host-only network only.** Never bridge it to a real
> network or expose it to the internet. The weaknesses here are intentional.

---

## The six flags (what each tests)

| # | Flag | Where | Skill it proves |
|---|------|-------|-----------------|
| 1 | `FLAG{robots_txt_is_not_a_secret}` | `http://TARGET/robots.txt` | basic web recon |
| 2 | `FLAG{view_source_reveals_more}` | HTML comment in page source (Ctrl+U) of `/` | reading source |
| 3 | `FLAG{api_endpoints_left_exposed}` | `http://TARGET/api/flag` (creds leak in `/api/config`) | API enumeration |
| 4 | `FLAG{ssh_foothold_established}` | `~/flag4.txt` after SSH as `hasker` | using leaked creds |
| 5 | `FLAG{port_forwarding_unlocks_localhost}` | `http://127.0.0.1:8000` **on the box** | SSH port forwarding |
| 6 | `FLAG{sudo_find_is_a_classic_gtfobin}` | `/root/root.txt` | privesc via `sudo find` |

Plus: an **anonymous SMB share** (`//TARGET/public`) serving `1oy6dars.zip`
(and a `briefing.zip` scenario brief) that candidates download first.

## Credentials (intended to be *found*, not given)
- SSH: `hasker` / `DoppiPomidor!27` — leaked in `http://TARGET/api/config`.

---

## Running it (you and your candidates)

1. In VirtualBox: **File → Import Appliance** → pick `FlagTrail-Linux-CTF.ova`.
2. Before first boot, confirm **Adapter 1 = Host-only** (`vboxnet0` or your
   host-only net). Do not use bridged.
3. Boot it. Find its IP from your host:
   ```bash
   # candidate's attack box on the same host-only net:
   nmap -sn 192.168.56.0/24          # find the target IP
   ```
4. Hand the candidate only the IP (and maybe "there's an SMB share"). Watch how
   far they get.

### The intended solve path (hand this to nobody)
See `ANSWER_KEY.md`.

---

## Rebuilding the OVA from source

Everything that defines the machine lives in this kit:

```
flagtrail/
├── web/html/            # fake storefront, robots.txt, /api/{config,flag}
├── web/internal/        # localhost-only page (flag5)
├── smb/briefing.zip     # file served over anonymous SMB
└── provision/
    ├── setup.sh         # configures the whole box (run as root on the guest)
    └── build_ova.sh     # unattended Debian install + provision + export OVA
```

To rebuild on a host with VirtualBox 7.x + a Debian netinst ISO:

```bash
export ISO=/path/to/debian-13.x-amd64-netinst.iso
export KEY=/path/to/provkey           # ssh keypair; provkey.pub beside it
export OUT_OVA=$PWD/FlagTrail-Linux-CTF.ova
./provision/build_ova.sh
```

`build_ova.sh` creates a throwaway VM, installs Debian unattended, copies this
kit in, runs `setup.sh`, removes the provisioning key, switches the NIC to
host-only, and exports the `.ova`. The provisioning key is **not** present in
the shipped image.

To re-provision an existing Debian box by hand instead, copy this folder onto it
and run `sudo provision/setup.sh` from the kit root.

---

## Why this is "minimal" (no extra vulns)
- Web app is **static** — no RCE, no upload, no injection.
- `hasker` is in **no** admin group; its *only* sudo right is `/usr/bin/find`.
- SMB is a **single read-only guest share** — no write, no home shares, no printers.
- The internal page is bound to **127.0.0.1 only** — unreachable without a tunnel.
- SSH: root login disabled, password auth on for `hasker` only.
- Root flag is `0600 root:root`; each flag is reachable only at its intended stage.
