# mirror-fx

OCX mirror for [fx](https://github.com/antonmedv/fx), a terminal JSON viewer and
processor. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [fx](https://github.com/antonmedv/fx) | [`fx/mirror.yml`](fx/mirror.yml) | `ghcr.io/ocx-contrib/fx/fx` | [`ocx.sh/fx/fx`](https://index.ocx.sh/fx/fx) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`antonmedv` is a personal handle rather than a vendor, so the tool names
itself: the namespace is `fx`, not the maintainer.

## Layout

```
mirror-base.yml         repo-wide policy the spec inherits via `extends:`
fx/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. The logo is **not** — it sits
beside the spec, because a repo-root `logo.*` sits in no workflow's `paths:`
filter, so replacing it would publish nothing until some unrelated edit
happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. `fx/mirror.yml` does not
restate `platforms:` at all; the measured matrix lives in `mirror-base.yml`.

## Platforms

Six platform entries — both Linux arches, both macOS arches, both Windows
arches — which is upstream's complete set. fx publishes exactly six assets per
release and this mirror carries all six: there is no `armv7`/`i686`/`riscv64`
asset to exclude, no `.deb`, and no `.sha256` sidecar.

Every one of the six anchored patterns was checked against the full asset list
of **every** in-range release (39.0.4, 39.1.0, 39.2.0) and matches exactly one
asset each — a pattern matching zero is *silently skipped* by the pipeline, not
an error, and would ship a missing platform under a green run.

**Both Linux keys are bare.** `os.features` states what an artifact requires
*of the host*, never how it was built:

| Key | Asset | Measured |
|---|---|---|
| `linux/amd64` | `fx_linux_amd64` | statically linked, `INTERP` segment count **0**, zero `DT_NEEDED` → **bare** |
| `linux/arm64` | `fx_linux_arm64` | statically linked, `INTERP` segment count **0**, zero `DT_NEEDED` → **bare** |

fx is pure Go with no cgo, so upstream ships one Linux build per arch and there
is no musl/gnu split to choose between. Both were measured on **all three**
in-range tags, not just the newest. Tagging them `+libc.musl` would be a false
requirement hiding the package from every glibc host it in fact runs on. The
`alpine:3.20` container leg on each arch is what turns the universality claim
into evidence; zero `DT_NEEDED` is also why no leg needs a
`containers[].setup` line.

## Two traps this mirror is built around

**Asset filenames carry no version string.** `fx_linux_amd64` is spelled
identically on 39.0.4, 39.1.0 and 39.2.0, so nothing may resolve a download by
matching a version substring — the same asset name would otherwise republish
the newest build under every tag. The pipeline resolves through the release's
own asset list, which yields a tag-scoped
`/releases/download/<tag>/<asset>` URL. That was verified by *behaviour*, not
by URL shape: each downloaded binary self-reports the tag it came from
(`39.0.4` → `fx --version` = `39.0.4`, and likewise for the other two), and the
byte sizes differ per tag. A filename comparison could not have caught an
upstream shipping stale binaries under a new tag; the self-report can.

**The assets are raw binaries with no exec bit.** There is no archive wrapper
on any platform — not even a zip on Windows — so the file lands directly at the
content root and `PATH` is a bare `${installPath}`. That is the one layout where
a bare `${installPath}` is correct, and it forces `bin_scan: "off"`: the scan
only looks *below* an `${installPath}/<dir>` entry, so `auto`/`verify` is
rejected at spec load with exit 65. `fx/metadata.json` therefore hand-lists
`binaries: ["fx"]` — and that list is **load-bearing, not documentation**.
GitHub serves release assets mode `0644` (verified on all six in-range Linux
artifacts) and `prepare` chmods 0755 exactly the binaries metadata declares, so
an undeclared binary would ship unexecutable and `bin_scan: auto` could not
rescue it.

The upstream Windows assets already end in `.exe`, so the suffix survives into
the bundle and no per-platform `name: fx.exe` override is needed — unlike
`mirror-direnv`, whose 2.37.0+ Windows assets dropped the suffix and had to name
it back on.

## The smoke test

fx is a TUI as well as a processor, and its non-interactive path is narrower
than the help text suggests. `fx/tests/smoke.star` is written around two
measured traps:

- **Piped stdin with no expression panics** (`could not open a new TTY`,
  exit 2). Every invocation passes an expression.
- **A filename argument is not a filename when stdin is not a tty** — which is
  always the case under `ocx package test`. fx then reads the document from
  stdin and treats every positional argument as an *expression*, so
  `fx doc.json .x` fails with `ReferenceError: doc is not defined`, and with
  stdin empty it exits **0 printing nothing at all**. The obvious hermetic
  shape — `ocx.write_file()` plus a path argument — is therefore a *vacuous
  green*. The document is fed through `stdin=` instead and no assertion names a
  file.

The assertions are computed results rather than exit codes: a nested extraction
(`42`), a filtered count (`3` of five items), the same selection by identity
and order (`1,3,5`), and a transformation whose output appears nowhere in the
input (`ALPHA-BETA-GAMMA`). Those are paired with an inverse selector (a path
resolving to nothing must leave stdout empty) and a **negative control** —
malformed JSON must exit `1`. The success paths alone could be faked by a tool
that merely echoed its input; the last two cannot.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `fx/mirror.yml` | hand | yes — see below |
| `fx/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `fx/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec fx/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
