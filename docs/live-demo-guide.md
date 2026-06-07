# Putting the demo online — a step-by-step guide for first-timers

This walks you from "I've never deployed anything" to "my demo is live on the
internet with a padlock (HTTPS)." Every command is copy-paste. Take it slowly; there's
nothing here you can't undo.

**What you'll end up with:** the exact same app you run locally, on a public URL like
`https://203-0-113-5.sslip.io/`, that anyone (judges included) can open in a browser.

**What it costs:** about **$1–2** for the few weeks it needs to live (you delete the
server when voting ends). **Time:** ~30–45 minutes, most of it waiting for the build.

**What you need:** a credit card (for the server), the project's GitHub URL, and a
web browser. That's it — no domain name, no special software on your computer.

> **Why this setup?** I picked the simplest path that still gives real HTTPS:
> a single small cloud server (a "droplet") from **DigitalOcean**, and a free
> auto-HTTPS hostname from **sslip.io** so you don't have to buy or configure a
> domain. If you'd rather pay less, **Hetzner Cloud** is ~⅕ the price with a similar
> console — the steps are nearly identical.

---

## Step 1 — Create the server (DigitalOcean droplet)

1. Go to **[digitalocean.com](https://www.digitalocean.com/)** and sign up (you may
   get free trial credit — search "DigitalOcean credit").
2. Top-right, click **Create → Droplets**.
3. Fill in the form:
   - **Region:** pick the one nearest you (or your judges).
   - **Image:** **Ubuntu 24.04 (LTS)**.
   - **Size:** choose **Basic → Regular**, then the **8 GB RAM / 2 CPU** option
     (around $48/mo, billed by the hour — a couple of weeks is a few dollars). The
     build needs this much memory; smaller will fail.
   - **Authentication:** choose **Password**, and set a strong root password you'll
     remember (write it down). *(Password is the simplest; SSH keys are "better
     practice" but unnecessary for a two-week demo.)*
   - **Hostname:** anything, e.g. `fhir-demo`.
4. Click **Create Droplet**. After ~30 seconds you'll see your droplet with a public
   **IP address** like `203.0.113.5`. **Copy it — you'll need it twice.**

---

## Step 2 — Open a terminal on the server (no software needed)

1. Click your droplet's name, then the **Console** button (top right). A black
   terminal opens **in your browser**.
2. If it asks you to log in, type `root`, press Enter, then your root password.

You're now "on" the server. Everything from here is typed into this console.
(Tip: in the browser console, paste with the on-screen paste button or
Ctrl+Shift+V.)

---

## Step 3 — Install Docker

Copy-paste this one line and press Enter (it installs Docker and waits a minute):

```bash
curl -fsSL https://get.docker.com | sh
```

When it finishes, check it worked:

```bash
docker --version && docker compose version
```

You should see two version numbers. (If `docker compose version` shows anything below
**v2.24**, run `curl -fsSL https://get.docker.com | sh` once more — a current version
matters for the security step later.)

---

## Step 4 — Download the project

Replace the URL with your project's GitHub address, then run:

```bash
git clone https://github.com/<your-org>/fhir-agent-studio.git
cd fhir-agent-studio
```

---

## Step 5 — Set your free HTTPS web address

We'll use **sslip.io**, a free service that turns any IP address into a real hostname
(so HTTPS works) without buying a domain. Your address is simply your droplet's IP
with dots replaced by dashes, followed by `.sslip.io`.

Example: IP `203.0.113.5` → hostname **`203-0-113-5.sslip.io`**.

Open the web-server config file in a simple editor:

```bash
nano deploy/Caddyfile
```

The first line reads `demo.example.com {`. Change **only** that hostname to yours, e.g.:

```
203-0-113-5.sslip.io {
```

Save and exit: press **Ctrl+O**, **Enter**, then **Ctrl+X**.

---

## Step 6 — Launch it

```bash
docker compose -f docker-compose.yml -f deploy/docker-compose.online.yml up --build -d
```

This builds the whole thing (the React apps, the IRIS backend, 1,000 demo patients,
the AI cache) and starts it behind an automatic-HTTPS web server. **The first build
takes several minutes** — that's normal. You can watch progress with:

```bash
docker compose logs -f iris
```

(Press **Ctrl+C** to stop watching the logs — it does *not* stop the app.)

The app is ready about 90 seconds after the build finishes.

---

## Step 7 — Check it's live

In the server console:

```bash
curl -s https://YOUR-HOSTNAME.sslip.io/fhir-agent-studio/api/status
```

(use your real hostname). You want to see `"status":"ok"` and `"templates":12`.

Now open it in your own browser:

- **`https://YOUR-HOSTNAME.sslip.io/`** → it lands on the guided demo. 🎉
- Run one agent (e.g. Results Follow-Up) — the AI result appears with no setup.
- Click around: the Ask page, a patient chart, the phone portal.

The padlock should show a valid certificate. (First load can take ~30 seconds while
the HTTPS certificate is issued — refresh if needed.)

---

## Step 8 — Lock down the server's admin login (5 minutes)

The behind-the-scenes admin portal isn't reachable from the internet (the web-server
config blocks it), but change the default IRIS passwords anyway. In the console:

```bash
docker exec -it fhir-agent-studio iris session iris -U %SYS
```

Then paste these, using your own long random passwords:

```objectscript
do ##class(Security.Users).UnExpireUserPasswords("*")
set p("Password")="<long-random-1>"  do ##class(Security.Users).Modify("_SYSTEM", .p)
set p("Password")="<long-random-2>"  do ##class(Security.Users).Modify("SuperUser", .p)
set p("Password")="<long-random-3>"  do ##class(Security.Users).Modify("Admin", .p)
halt
```

**Optional belt-and-braces:** in the DigitalOcean panel, **Networking → Firewalls →
Create Firewall**, allow inbound only **22, 80, 443**, and attach it to your droplet.

---

## Step 9 — Keep it fresh (optional but nice)

Judges will sign drafts and create tasks; over a day the demo data drifts. This resets
it to pristine every night at 4:15am (server time), taking about a minute:

```bash
crontab -e
```

(If asked, choose `nano`.) Add this single line at the bottom, save (Ctrl+O, Enter),
exit (Ctrl+X):

```
15 4 * * * cd /root/fhir-agent-studio && docker compose -f docker-compose.yml -f deploy/docker-compose.online.yml up -d --force-recreate iris
```

(After a reset, the admin passwords from Step 8 revert to defaults — fine, since the
admin portal isn't exposed. Re-run Step 8 if you prefer.)

---

## Step 10 — Add the link to your submission

- **Open Exchange** listing → **Demo URL** = `https://YOUR-HOSTNAME.sslip.io/`
- Put the same link near the top of the project **README**.
- Tick the **Online Demo** bonus in the contest description.

One honest line worth adding to your demo description: *"For the engine-level Visual
Trace, clone the repo and run the one-command local build — the admin portal is
deliberately not exposed on the public demo."* The "Under the hood → Visual Trace"
links open IRIS's admin portal, which we keep off the public internet on purpose;
everything else works online.

---

## Step 11 — Shut it down when voting ends (stop the bill)

When the contest is over (after 2026-06-14), delete the droplet so you stop paying:
DigitalOcean panel → your droplet → **Destroy → Destroy Droplet**. That's it — billing
stops immediately.

---

## If something goes wrong

| What you see | What to do |
|---|---|
| The browser shows a certificate warning | Wait a minute and refresh — the HTTPS cert is still being issued. Make sure ports 80 and 443 aren't blocked (if you added a firewall, it must allow them). |
| `502 Bad Gateway` | IRIS is still starting after the build. Wait, then `docker compose logs -f iris`. |
| Build fails / runs out of memory | Your droplet is too small — it needs the **8 GB** size from Step 1. |
| The site loads but `/api/status` doesn't | Give it the full ~90 seconds after the build, then retry. |
| `!override` error on launch | Your Docker Compose is too old — re-run `curl -fsSL https://get.docker.com \| sh` and try Step 6 again. |
| I'm lost | Everything lives in the one folder from Step 4. To start over cleanly: `docker compose -f docker-compose.yml -f deploy/docker-compose.online.yml down` then repeat Step 6. |

That's the whole thing. Once it's up, it stays up — and you've now deployed a real
containerised app behind HTTPS, which is a genuinely useful thing to know how to do.

> Full reference (for when you're comfortable): [`docs/online-demo.md`](online-demo.md).
