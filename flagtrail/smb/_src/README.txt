DoppioMart — Shared Files (public, anonymous)
=============================================

Welcome, candidate.

You are looking at a public SMB share exported by the DoppioMart demo server.
This is the recruitment lab for joining the team. Your objective: collect all
six FLAG{...} values, in order, and show how you got each one.

Scope / rules of engagement
----------------------------
- This single host is the only in-scope target.
- Everything you need is reachable from the network services this box exposes.
- Do NOT attack anything outside this VM. It is a training target only.

Where to start
--------------
- There is a web storefront on the usual HTTP port. Look at it the way an
  attacker would: the page, its source, and what a well-behaved crawler is
  told to avoid.
- One flag lives somewhere you can only reach *from the box itself*. Think
  about tunneling.
- The final step is a local privilege-escalation. Enumerate what your user is
  allowed to run.

Good luck. Document your path — we care about how you think, not just the loot.
    — DoppioMart Security
