# NOTICE

This repository packages and redistributes upstream software published by the
[fx](https://github.com/antonmedv/fx) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — the redistributed bytes carry their
own license, recorded below.

The package logo is upstream's own mark, taken from the project website
(<https://fx.wtf/img/favicons/favicon.svg>) and used for catalog identification
only. No endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `fx` | `ghcr.io/ocx-contrib/fx/fx` | `MIT` |

---

## `fx`

Upstream: <https://github.com/antonmedv/fx>
Published to `ghcr.io/ocx-contrib/fx/fx`.

| Component | SPDX | Holder |
|---|---|---|
| fx | **MIT** | Anton Medvedev |

The upstream [`LICENSE`](https://github.com/antonmedv/fx/blob/master/LICENSE)
was read directly from the repository blob rather than taken from GitHub's
cached SPDX field: it is the unmodified MIT text, `Copyright (c) 2018 Anton
Medvedev`, with no added clauses, field-of-use restriction or non-commercial
rider. MIT grants redistribution of the compiled binary on the sole condition
that the copyright and permission notices accompany it; that condition is met
by this file, which reproduces the attribution, and by the
`org.opencontainers.image.licenses: MIT` annotation carried on every published
image index.

fx ships as a single statically linked Go binary with no accompanying license
files in the release asset — the asset *is* the executable — so unlike an
archive-based mirror there is no upstream `LICENSE` file inside the bundle to
republish. The published binaries statically link third-party Go modules under
permissive licenses, enumerated in upstream's `go.mod` / `go.sum`.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle. The only transformation the
pipeline applies is a rename of the platform-suffixed asset (`fx_linux_amd64`)
to the plain command name (`fx`) and a mode change to 0755 — GitHub serves
release assets without the executable bit.
