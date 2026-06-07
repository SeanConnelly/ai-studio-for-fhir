# Online demo — deployment runbook (Sean executes)

Puts the judge build on a public URL for the contest's **Online Demo bonus (2 pts)**.
Everything here is manual-by-Sean (provisioning, DNS, deploy); the repo ships the
two config files it uses: `deploy/docker-compose.online.yml` and `deploy/Caddyfile`.

**Security model in one line:** Caddy exposes *only* `/fhir-agent-studio/*` (SPA +
API + FHIR R4) and `/clinical/*`; the IRIS web server itself is bound to loopback,
the superserver port isn't published at all, the Management Portal is unreachable
from the internet, and the default IRIS passwords get changed anyway. All data is
synthetic — there is no PHI to protect, only the instance itself.

**Known trade-off:** the "Under the hood" → **Visual Trace** deep links point at the
Management Portal, which is deliberately not exposed — on the public demo those
links won't open (everything else, including the AI Hub corpus browser, works).
Judges who want Visual Trace run the one-command local build; consider one line in
the demo-guide/OEX description saying exactly that, so it reads as a security
choice, not a gap.

---

## 1. Provision

Any Ubuntu 22.04/24.04 VPS with **≥8 GB RAM, 2+ vCPU, ≥25 GB disk** (Hetzner
CX32/CPX31, DigitalOcean 8 GB, Lightsail 8 GB — ~$10–20/mo; the demo only needs to
live through 2026-06-14). Open inbound **80 + 443** (and 22 for yourself) in the
provider firewall. Nothing else — IRIS's ports are never published.

```bash
ssh root@<server>
curl -fsSL https://get.docker.com | sh        # docker + compose v2 (need v2.24+ for the override)
```

## 2. DNS (recommended — gives automatic HTTPS)

Point an A record (e.g. `demo.yourdomain.tld`) at the server IP. Then edit
`deploy/Caddyfile` and replace `demo.example.com` with your hostname.
No domain? Change the site address in the Caddyfile to `:80` (plain HTTP on the IP).

## 3. Deploy

```bash
git clone https://github.com/<your-org>/fhir-agent-studio.git
cd fhir-agent-studio
docker compose -f docker-compose.yml -f deploy/docker-compose.online.yml up --build -d
```

This is the exact judge build (image bake takes several minutes) plus two changes
from the override: IRIS bound to `127.0.0.1:42773` only, and Caddy in front on
80/443.

## 4. Harden the IRIS accounts

The community image ships well-known default credentials. The portal is not
reachable through Caddy, but change them anyway:

```bash
docker exec -it fhir-agent-studio iris session iris -U %SYS
```

```objectscript
do ##class(Security.Users).UnExpireUserPasswords("*")
set props("Password") = "<long-random-1>"  do ##class(Security.Users).Modify("_SYSTEM", .props)
set props("Password") = "<long-random-2>"  do ##class(Security.Users).Modify("SuperUser", .props)
set props("Password") = "<long-random-3>"  do ##class(Security.Users).Modify("Admin", .props)
halt
```

(Keep the passwords somewhere only you can find them; nothing in the demo needs
them.)

## 5. Verify from outside

```bash
curl -s https://demo.yourdomain.tld/fhir-agent-studio/api/status   # "status":"ok", 12 templates
curl -s -o /dev/null -w "%{http_code}\n" https://demo.yourdomain.tld/csp/sys/UtilHome.csp   # 404 - portal blocked
```

Then click through in a browser:
- `https://demo.yourdomain.tld/` → redirects to **The demo** guide
- Run one agent end-to-end (e.g. Results Follow-Up) — expect `source: cached`
- Ask page: press the dice, run a question
- Phone portal tabs for a portal patient

## 6. Nightly self-reset

Judges can sign drafts, create tasks, run triage — all state is in the container,
and the image bakes the pristine demo. A nightly recreate restores it:

```bash
crontab -e
# 04:15 UTC nightly: recreate the app container from the baked image (~1 min)
15 4 * * * cd /root/fhir-agent-studio && docker compose -f docker-compose.yml -f deploy/docker-compose.online.yml up -d --force-recreate iris >> /var/log/fhir-demo-reset.log 2>&1
```

(`--force-recreate` without `--build`: the baked image is the reset point. Step 4's
password change is inside the container, so re-run it after a recreate — or accept
defaults-on-loopback for the demo week.)

## 7. Wire it into the submission

- Open Exchange app page → **Demo URL** = `https://demo.yourdomain.tld/`
- README: add the demo link near the top ("Try it without installing")
- Tick the **Online Demo** bonus in the contest description
- Calendar note: tear the VPS down after voting ends (2026-06-14)

## Troubleshooting

| Symptom | Fix |
|---|---|
| Caddy serves a TLS error | DNS not propagated yet, or port 80/443 blocked at the provider firewall (Caddy needs 80 for the ACME challenge) |
| 502 from Caddy | IRIS still baking/starting — `docker compose logs -f iris`; healthcheck takes ~90 s after image build |
| `!override` rejected | Compose < v2.24 — upgrade Docker, or delete the `ports:` block from the base file on the server instead |
| Demo state looks messy mid-day | Run the step-6 command by hand; it's a 1-minute reset |
