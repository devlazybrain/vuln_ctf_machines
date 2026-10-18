# Candidate briefing

Welcome. This is a practical, hands-on assessment. You have a few hours.

## Rules
- You will be given a **target IP** for one machine at a time.
- Use any tools you like (nmap, gobuster/ffuf, sqlmap, Burp, Metasploit,
  hashcat/john, etc.). AI assistants are allowed.
- Goal on each machine: capture **two flags**.
  - a **user** flag (standing access as a normal user)
  - a **root** flag (full control of the machine)
- Flags look like `FLAG{...}`. Submit the exact string.
- Do **not** attack anything other than the target IP you were given.

## What we're looking for
Reaching the flags matters, but *how* you work matters more: clean
enumeration, understanding **why** each step works, and not getting stuck in
rabbit holes. If you get a foothold but not root, tell us how far you got and
what you'd try next — partial progress counts.

## The three machines (given in order)
1. **recovery** — easy. Think about what a "backup" really contains.
2. **webwork** — easy/medium. It's a web app. Log in, get a shell, climb.
3. **gauntlet** — medium. Find the injectable parameter, take what's in the DB,
   then work your way up.

Good luck.
