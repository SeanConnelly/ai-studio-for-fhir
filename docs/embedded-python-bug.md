# Bug report: in-process Embedded Python calls crash IRIS 2026.x (regression vs 2025.3)

> **Status: DRAFT, stress-tested — Sean files this by hand** (Developer Community
> post and/or GitHub issue; see "Where to file" below). Found 2026-06-06 while
> building the Embedded Python SQL gate for FHIR Agent Studio. Claimable as the
> contest's "Find a bug in Embedded Python" technology bonus (2 pts).

## Summary

In the `intersystemsdc/irishealth-community` **2026.1 and 2026.2** images, **any
in-process Embedded Python *call* crashes the calling IRIS process**.
`%SYS.Python.Import()` succeeds and returns a proxy object, but invoking *any*
method on *any* imported module — including `builtins.len("abc")` — kills the
process. Because it is a fatal signal, no ObjectScript `try/catch` can intercept
it: a REST/CSP process making the call dies mid-request (the client sees an empty
response), and compiling any `[ Language = python ]` method crashes the
work-queue worker jobs.

**It is a regression in IRIS itself:** on the *same host, same Docker, same WSL2
kernel*, the **2025.3** image (Build 226U) works perfectly — and the working and
broken images ship the **identical OS and Python** (Ubuntu 24.04, system Python
3.12.3), so the only changed variable is the IRIS build.

| Image (`intersystemsdc/irishealth-community`) | IRIS build | OS / Python | `b.len("abc")` |
|---|---|---|---|
| `2025.3` | 2025.3 Build 226U (2025-11-13) | Ubuntu 24.04.3 / Py 3.12.3 | ✅ returns 3 |
| `latest` (= 2026.1) | 2026.1 Build 235U (2026-04-07) | Ubuntu 24.04.4 / Py 3.12.3 | 💥 process dies |
| `2026.2` | 2026.2 | Ubuntu 24.04.x / Py 3.12.3 | 💥 process dies |
| `2025.1` | — | — | untestable: bundled community license expired (image self-bricks) |

The external `irispython` interpreter works normally in all versions — the fault
is specific to the in-process (callin) bridge.

## Environment

- **Image:** `intersystemsdc/irishealth-community:latest`,
  digest `sha256:b903ef34e907779cea524fd9c0e4d13e0c6f6040256e8af69d6e6640e118931a`
- **$ZV:** `IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2026.1 (Build 235U) Tue Apr 7 2026 16:39:12 EDT`
- **Container Python:** 3.12.3 (Ubuntu 24.04 system python)
- **Host:** Windows 11 Home 10.0.26200, Docker Desktop (WSL2 backend)
- Reproduced on a **pristine container** (fresh `docker run`, no customisation,
  default config) — not specific to our application image.

## Reproduction (3 commands)

```bash
docker run --rm -d --name ep-bug intersystemsdc/irishealth-community:latest
# wait ~30s for IRIS to start, then:
docker exec -it ep-bug iris session IRIS -U USER
```

```objectscript
USER> set b = ##class(%SYS.Python).Import("builtins")   ; succeeds
USER> write b.len("abc")                                 ; SIGSEGV - session dies
```

The session terminates immediately (exit code 1, no `<ERROR>` — the process is
gone). `messages.log`:

```
... (1121) 3 [Generic.Event] Process 1121 (JobType=Callin Connection,
    Dumpstyle=0, Directory='/usr/irissys/mgr/user/') caught signal 11.
... (1121) 3 [Generic.Event] Parent process will clean up and halt
```

## Variations tried (all crash on 2026.x)

| Scenario | Result |
|---|---|
| `Import("json")` / `Import("sqlparse")` (import only) | OK — proxy object returned |
| Any call on the proxy (`json.dumps`, `builtins.len`, custom module function) | process dies |
| Same call from a CSP/REST process | process dies → empty HTTP response to the client |
| Compile a class with a `[ Language = python ]` method | `ERROR #7802` work-queue worker(s) unexpectedly shut down |
| Same compile with `/multicompile=0` | the compiling session itself dies; class left half-compiled (dictionary says compiled, runtime `<CLASS DOES NOT EXIST>` / python methods return "") |
| Explicit runtime config (`PythonRuntimeLibrary=/usr/lib/x86_64-linux-gnu/libpython3.12.so.1.0`, `PythonRuntimeLibraryVersion=3.12` via `ISC_CPF_MERGE_FILE`) | merge applies (visible in iris.cpf), call still crashes |
| `docker run --security-opt seccomp=unconfined` | still crashes — Docker's syscall filter ruled out |
| `irispython` (external interpreter, same container) | **works normally** |
| **Same test on `2025.3`** (same host/kernel/Docker, same Ubuntu 24.04 + Py 3.12.3) | **works normally** |

## Crash signature (two levels)

- **IRIS level** (`messages.log`): `Process NNNN (JobType=Callin Connection ...) caught signal 11.` followed by `Parent process will clean up and halt`.
- **Kernel level** (WSL2 dmesg): the same pid then dies by **self-abort** — `potentially unexpected fatal signal 6`, `Comm: irisdb`, `ORIG_RAX: 0xea` (`tgkill`) — i.e. IRIS's own crash handler catches the SIGSEGV, logs it, and aborts the process. Consistent at both levels.

## Impact

- Any application feature relying on in-process Embedded Python dies
  un-catchably; in a web context this surfaces as silent empty responses.
- `[ Language = python ]` classes cannot be compiled, which also breaks
  work-queue-parallelised builds that include such a class.

## Workaround we shipped

**Run the Embedded Python out of process.** Since the *in-process callin*
bridge is what crashes — and the bundled `irispython` interpreter works
perfectly in the same container — we invoke the same module out-of-process from
ObjectScript via `$ZF(-100)`:

```
irispython /usr/irissys/mgr/python/fast_sqlguard.py <sqlfile>
```

The SQL is passed in a temp file (never on the command line, so no shell
injection), and the script prints its JSON verdict to stdout, which ObjectScript
reads back. This way the Embedded Python (sqlparse AST) gate **genuinely runs on
the affected image** — the application reports `readOnlyGuard:
"objectscript+sqlparse"` for real — instead of being permanently disabled by the
bug. A one-time boot probe (`Armed()`, verdict cached in `^IRIS.Temp`, so it
re-evaluates every restart and a baked image can't carry a stale verdict across
hosts) confirms availability; if `irispython`/sqlparse is missing the app falls
back to the ObjectScript keyword gate alone and says so. See
`FAST.Runtime.SqlGuard` (`Check` / `Armed`) in the FHIR Agent Studio repo.

(An earlier version used a "sacrificial JOB" to survive the in-process crash;
the out-of-process approach is strictly better — it actually returns a result
rather than just surviving — so the sacrificial-job probe was removed.)

## Where to file

1. **Developer Community post** (tag: Embedded Python, InterSystems IRIS) —
   required for contest-bonus visibility; link the repro.
2. Optionally also the community images repo
   (github.com/intersystems-community — the irishealth-community image) and/or
   WRC if a support contract applies.

## Notes / honesty caveats

- All reproductions are on one host profile: Windows 11, Docker Desktop 29.1.3,
  WSL2 kernel **5.15.167.4** (an older WSL2 kernel line; current Docker Desktops
  ship 6.x). We have not verified a native-Linux or newer-kernel host — it is
  possible 2026.x only crashes on older kernels. **But host-only blame is
  untenable**: 2025.3 runs Embedded Python flawlessly on this exact host with the
  identical OS/Python userland, so at minimum IRIS 2026.x *regressed relative to
  2025.3 on an extremely common developer environment* (default-ish Docker
  Desktop on Windows). The report states the environment precisely and invites
  reproduction elsewhere.
- Why others will hit this: the AI Agents for FHIR contest awards bonus points
  for Embedded Python, on this exact image, and entries already exist that route
  LLM calls through Embedded Python (e.g. CardioIris per its DC article). A large
  share of entrants and judges run Docker Desktop on Windows. And nobody can
  dodge it by pinning an older image: community-image licenses expire (2025.1
  already self-bricks), forcing everyone onto 2025.3+ / 2026.x.
- No existing public report found (searched DC, the embedded-python template's
  GitHub issues, and the web for the signature, 2026-06-06).
- `iris list` inside the container and all other IRIS functionality remain
  healthy; only the Python callin bridge is affected.
