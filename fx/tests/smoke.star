# fx/tests/smoke.star — stable across upstream fx releases.
# Asserts the contract (exit code, version shape, computed results of real JSON
# transformations, and a malformed-input negative control), never help/version
# prose. See ocx.mirror testing-practices.md.
#
# ─── Two invocation traps this file exists to route around ─────────────────
#
# fx is a TUI as well as a processor, and its non-interactive path is narrower
# than the help text suggests. Both traps were measured on 39.2.0:
#
#   1. NO EXPRESSION ⇒ PANIC. `fx` with piped stdin and no expression argument
#      tries to take over the terminal and dies:
#        panic: could not open a new TTY: open /dev/tty: no such device
#      exit 2. Every ocx.run below therefore passes an expression.
#
#   2. A FILENAME ARGUMENT IS NOT A FILENAME HERE. When stdin is not a tty —
#      which is always true under `ocx package test` and in CI — fx reads the
#      DOCUMENT FROM STDIN and treats every positional argument as an
#      EXPRESSION. `fx doc.json .x` then fails with
#      `ReferenceError: doc is not defined`, and with stdin empty
#      (`fx doc.json .value </dev/null`) it exits 0 printing NOTHING AT ALL.
#      So the obvious hermetic shape — ocx.write_file() + a path argument —
#      is a VACUOUS GREEN: expect.ok passes while the tool did nothing. The
#      document is fed through `stdin=` for exactly this reason, and no test
#      below names a file.
#
# `stdin=` also guarantees stdin is a pipe rather than an inherited terminal,
# which is what keeps trap 1 from re-appearing on a runner that has a tty.

FX = "fx.exe" if ocx.target_platform.os == ocx.os.Windows else "fx"

# Hermetic input. Chosen so that every assertion below is a value the input
# does NOT literally contain — a tool that merely echoed its stdin could not
# produce "3", "1,3,5" or "ALPHA-BETA-GAMMA".
DOC = """{
  "service": "fx-smoke",
  "tags": ["alpha", "beta", "gamma"],
  "nested": { "deep": { "value": 42 } },
  "items": [
    {"id": 1, "on": true},
    {"id": 2, "on": false},
    {"id": 3, "on": true},
    {"id": 4, "on": false},
    {"id": 5, "on": true}
  ]
}"""

def out(r):
    # fx writes results to stdout and diagnostics ("undefined", parse errors)
    # to stderr, so every assertion here reads stdout only — no prose, and no
    # exposure to whatever colouring a future release adds to its errors.
    return r.stdout.replace("\r", "").strip()

# Tier 1 + 2: liveness on the composed PATH + version SHAPE. The digits are the
# contract; the vendor banner is not.
r_version = ocx.run(FX, "--version", stdin = "")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# Tier 3a: navigate to a NESTED value. `42` sits three levels down and is the
# only integer at that path, so a tool that echoed the document, or that
# resolved only the first path segment, cannot produce this.
r_nested = ocx.run(FX, ".nested.deep.value", stdin = DOC)
expect.ok(r_nested)
expect.eq(out(r_nested), "42")

# Tier 3b: a filtered COUNT — never merely exit 0.
#
# ⚠️ exit code alone has no teeth on a query tool: a selector matching
# everything, nothing, or the wrong thing all exit 0. Five items exist and
# exactly three carry `on: true`, so the count discriminates three distinct
# failures at once — an ignored predicate answers 5, an inverted one answers 2,
# a dropped `.length` answers a JSON array.
r_count = ocx.run(FX, ".items.filter(x => x.on).length", stdin = DOC)
expect.ok(r_count)
expect.eq(out(r_count), "3")

# Tier 3c: the same selection by IDENTITY and ORDER, not just cardinality. A
# filter that happened to keep three arbitrary elements passes 3b and fails
# here.
r_ids = ocx.run(FX, ".items.filter(x => x.on).map(x => x.id).join(\",\")", stdin = DOC)
expect.ok(r_ids)
expect.eq(out(r_ids), "1,3,5")

# Tier 3d: a genuine TRANSFORMATION, not a projection. "ALPHA-BETA-GAMMA"
# appears nowhere in the input — producing it requires the embedded JS engine
# to actually run `toUpperCase` and `join` over the parsed array. This is the
# assertion that reds against a truncated or wrong-flavour artifact whose
# runtime failed to link.
r_upper = ocx.run(FX, ".tags.map(t => t.toUpperCase()).join(\"-\")", stdin = DOC)
expect.ok(r_upper)
expect.eq(out(r_upper), "ALPHA-BETA-GAMMA")

# Tier 3e: the INVERSE selector over the same document. A path that resolves to
# nothing must yield an EMPTY stdout while still exiting 0 (fx reports the
# `undefined` on stderr). This is the half expect.ok cannot see: it reds
# against a binary that echoes its input regardless of the expression.
r_missing = ocx.run(FX, ".missing", stdin = DOC)
expect.ok(r_missing)
expect.eq(out(r_missing), "")

# Tier 3f: NEGATIVE CONTROL — malformed JSON must FAIL.
#
# Everything above is a success path, and a passthrough-shaped tool can fake a
# success path. This is the assertion that cannot be faked by echoing: a
# truncated document has no parse, so fx must reject it. Measured exit 1 on
# 39.0.4, 39.1.0 and 39.2.0 alike — asserted exactly, not as "non-zero", since
# a range of tolerated exit codes is a habit rather than a check.
r_bad = ocx.run(FX, ".service", stdin = "{\"service\": ")
expect.eq(r_bad.exit_code, 1)
expect.eq(out(r_bad), "")

# No Tier 4: metadata.json declares PATH only, and Tier 1 already proves it.
