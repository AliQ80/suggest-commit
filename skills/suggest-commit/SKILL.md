---
name: suggest-commit
description: "Suggests a readiness-aware, domain-based commit message formatted as `domain(type): title` for non-breaking changes or `domain(type)!: title` for breaking changes. Invoke ONLY when the user explicitly requests a commit suggestion — e.g. by running `/suggest-commit` or by clearly asking in natural language to 'suggest a commit message', 'draft a commit', or 'what should I commit'. Do NOT trigger automatically after an agent finishes work, and do NOT run on implicit or ambient requests. Read-only: never stages, commits, edits files, or changes VCS state. Output is ONLY the proposed commit message(s) (title/body as inline code spans; Markdown backticks are presentation-only); for logical splits an uncolored Files section is appended per commit; reverts use VCS-specific trailers; blockers/edge states emit a concise actionable message."
metadata:
  version: "0.7.0"
  requires-path: ""
---

# Suggest Commit

Produce a readiness-aware, domain-based commit message for the repository's
current working change. This skill is **read-only** and **explicitly invoked
only**.

## Invocation

Trigger ONLY through:
- The slash command `/suggest-commit`, OR
- A clear natural-language request such as "suggest a commit message",
  "draft my commit", "what should I commit here", or "help me write a commit".

Never activate automatically after another agent completes a task, and never
run on vague or unrelated requests (e.g. "commit this" is ambiguous — ask
which behavior is wanted, or treat as a suggestion request only). If the user
does not request a commit suggestion, do not run this workflow.

## Hard constraints

- **Read-only.** Use inspection commands only. Never `git add`, `git commit`,
  `jj commit`, `jj squash`, file edits, or any VCS mutation.
- **Explicit only.** No automatic post-task triggering.
- **Domain-based title format is the invariant output.** Exactly
  `domain(type): title` for non-breaking changes, or `domain(type)!: title`
  when the change is breaking (the `!` appears **immediately after** the closing
  parenthesis).
  - `domain` = the affected **subsystem, component, directory, or technical
    concern** (e.g. `auth`, `parser`, `notify`, `ci`, `docs`, `deps`). A
    domain is **never** a generic Conventional Commits *type*, a filename, a
    task name, a temporary implementation detail, or an arbitrary label. Prefer
    the most specific stable architectural area supported by the diff. Domain
    inference is internal; it is never explained or labeled in the user-facing
    message.
  - `type` = one entry from the vocabulary below. Pick the most accurate; add a
    project-specific custom type only if none fits.
  - **Pre-output self-check is mandatory.** Before emitting any message, validate
  each candidate: domain is a real concern (not a conventional type), type is
  from the vocabulary, breaking changes carry `!` immediately after `)`, the
  title has **no trailing punctuation** (reject and rewrite any `. , ; : ! ?`
  etc. — the structural breaking `!` belongs immediately after `)` as header
  syntax, not as a title-ending character), the title is <=50 chars (hard max
  72), and every non-title line wraps at 72 columns. Reject and fix any
  violation. Then render per the Output shape: the
  title line and every body/bullet line is wrapped in single backticks; the
  Files section (split suggestions only) is plain text and is never backticked.
  **Markdown backticks are presentation-only** — they are not part of the commit
  message; the underlying message content MUST be valid DAC without backticks.

## Type vocabulary

Choose the type from this standard DAC list:

`feat`, `improve`, `fix`, `perf`, `security`, `bump`, `revert`, `cleanup`,
`refactor`, `style`, `test`, `init`, `release`, `wip`, `merge`.

Add a project-specific custom type only when no standard type fits.

The following are **domains, not types**: `deps`, `ci`, `ops`, `build`,
`docs`. Represent the action with a DAC type — e.g. a dependency upgrade uses
`deps(bump): ...`, a CI defect uses `ci(fix): ...`, a build-config restructure
uses `build(refactor): ...` or `build(style): ...`, and documentation uses
`docs(...)`. Never emit `build(type)`, `ci(type)`, `ops(type)`, or
`deps(type)`.

`chore` is **non-standard / custom fallback** and is not a preferred DAC type.
Prefer a standard type plus a domain (e.g. `ops(cleanup): ...`, `ci(style):
...`). Use `chore` only when no standard DAC type fits the change, and treat it
as a last resort rather than a default.

## Repository inspection (VCS-aware)

Detect the VCS first.

1. **Prefer Jujutsu** when a `.jj/` directory exists at the repo root:
    - `jj status` — working-copy changes and untracked files
    - `jj log -r @ -n 20 --template ...` — recent history for semantic/type clues
    - `jj diff --summary` — files touched
    - `jj diff --stat` — change size per file
    - `jj diff --git` — full patch for evidence
2. **Git fallback** when no `.jj/` but a `.git/` exists:
    - `git status --short`
    - `git log --oneline -20` (semantic/type clues only)
    - **Staged changes first:** `git diff --cached --stat` and `git diff --cached`.
      When the index is non-empty the change to describe is the staged change.
      **Never** conclude the working tree is clean from an empty unstaged
      `git diff` — an empty `git diff` only means nothing is unstaged, not that
      there is nothing to commit.
    - **Unstaged changes:** `git diff --stat` and `git diff`.
    - `git ls-files --others --exclude-standard` — untracked files
3. **Unsupported state** when neither `.jj/` nor `.git/` is found, or the
    inspection commands fail: do NOT invent a message. Stop and output only a
    concise, actionable message (see Output shape), including an optional
    non-executed initialization suggestion — prefer `jj git init` when the user
    wants Jujutsu, otherwise `git init`. Never execute it.

Treat history as *semantic evidence only*. It may inform the type vocabulary or
an existing domain name, but a Conventional Commits prefix is never used as the
domain.

## Readiness assessment

Distinguish concrete unfinished signals from uncertainty. This assessment is
computed internally and governs whether a commit message may be emitted; it is
**not** printed as a report.

- **Apparently complete:** diff forms a coherent unit with no obvious
  unfinished signals → continue to message suggestion.
- **Obvious blockers** (do not present as ready): placeholders
  (`TODO`, `FIXME`, `XXX`), debug code, commented-out blocks, `print`/debugger
  leftovers, incomplete branches, half-renamed symbols, or unrelated
  unfinished edits in the same change. Keep the change **not-ready** and do
  **not** suggest a ready-to-commit message while blockers are present. Instead
  output only a concise actionable message (e.g.
  `Before committing, remove the TODO and leftover print() debug statement.`).
- **Uncertainty** (never a blocker, never printed as a finding): tests you did
  not run, behavior you could not verify, or assumptions about intent. Do not
  pretend to prove correctness; still emit the message only if no blockers exist.

Readiness assessment never alters the DAC syntax or vocabulary. When no blocker
exists, emit the full DAC-formatted message; blockers emit only the concise
actionable message, never a partially formatted one.

## Message format

For each cohesive unit, build one complete message:

```
domain(type): title

One-to-two sentence overview of the motivation or problem solved.

- Bullet for each granular change
- Key decision and, when relevant, discarded alternative
- Reference (issue/PR) when applicable

closes #10
refs #12
```

For a **breaking change**, add `!` immediately after `)` in the header and,
when migration or contract detail is warranted, append a `BREAKING CHANGE:`
footer after the body:

```
domain(type)!: title

Overview of the breaking change and its impact.

BREAKING CHANGE: <what breaks and how to migrate>
```

- For a **single cohesive commit** (all changed files belong together), emit
  only the message above. Do **not** include a Files section.
- For **logical split suggestions**, emit the message for each unit followed by
  a plain-text `Files:` section (see Logical split suggestions). Domain
  inference is internal and is never shown in the message.

### Title rules

- Format **exactly** `domain(type): title` for non-breaking changes, or
  `domain(type)!: title` for breaking changes (the `!` sits immediately after
  the `)`, with no space).
- Target title length **<= 50 characters**; **hard maximum 72 characters**
  (reject and shorten any longer title).
- Imperative style; lowercase the first word (and others where natural); **no
  trailing punctuation** (the breaking `!` is header syntax after `)`, never a
  title-ending character).
- Preserve capitalization when the title begins with a proper noun or code
  symbol (e.g. `api(fix): handle NullPointerException`); otherwise lowercase
  the first word.
- `domain` is the affected subsystem, component, directory, or technical
  concern — **never** a generic Conventional Commits type. For a build refactor
  the domain is `build`/`ci`, not `refactor`.

### Footer and trailer rules

- Separate the body from the footer with **one blank line**. Each footer entry
  occupies its **own line** using standard trailer syntax; do not fold trailers
  into body bullets.
- Issue trailers: `closes`, `reopens`, `refs` — one issue per line
  (e.g. `closes #10` then `closes #11`), each key rendered in DAC lowercase.
  Prefer a compact **local** reference (`closes #42`) for issues in the
  repository's own namespace; use a full, unambiguous **external** URL for
  cross-repository, cross-forge, or named-tracker issues where a bare number
  would be ambiguous. This local-vs-external preference is a **skill-level
  convention** (a default for suggestion output), not a hard DAC syntax rule.
- Narrative vs formal trailers: the body may describe an issue's motivation or
  context in prose, but formal automation and collaboration metadata belongs in
  footer trailers, never folded into body bullets.
- Breaking-change footer: optional `BREAKING CHANGE:` describing the migration
  or contract detail (capitalization preserved exactly).
- Collaboration trailers: `Co-authored-by:`, `Reviewed-by:`, `Signed-off-by:`,
  `Acked-by:`, etc. — **capitalize only the first letter of the complete key**
  regardless of the casing seen in source history or external input (e.g. render
  `Signed-off-by:`, `Co-authored-by:`, `Reviewed-by:`, `Acked-by:`, not
  `signed-off-by:`, `CO-AUTHORED-BY:`, or `signed-off-By:`). Never copy
  inconsistent source casing.
- **Markdown backticks are presentation-only.** The footer/trailer text is part
  of the commit message; the surrounding backticks are not.

### Body rules

- **Wrap every non-title line at 72 columns**, preserving blank lines and bullet
  markers (`- `). Overview and bullets stay concise.
- When a body is emitted, it MUST explain what changed and why without relying
  solely on issue links or external URLs.
- Keep the overview to one or two sentences.

### Type selection guidance

- Pick the vocabulary type that best matches the change. A build refactor →
  `build(refactor): ...` (domain `build`, type `refactor`). A new feature in
  `notify` → `notify(feat): ...`. History may inform vocabulary but does not
  force the domain.
- **Choose the most specific type for the change's actual purpose.** For an auth
  bug fix, use `fix` (e.g. `auth(fix): ...`), **not** `security` — `security` is
  reserved for changes that specifically address a vulnerability, a security
  policy, or an encryption issue. A login-hardening fix that merely rejects bad
  input is a `fix`, not a `security` change. This preserves the full vocabulary
  and the `domain(type): title` format; reach for `security` only when the
  change's real purpose is the vulnerability/policy/encryption fix itself.
- **Domain inference is internal.** When the domain is newly inferred rather
  than reused from history, use the evidence to pick the domain, but do not
  surface it in the user-facing message.

## Revert protocol

Treat reverts as a dedicated output case distinct from ordinary suggestions.
Use the detected VCS to choose the trailer and the identifier format.

- **Header:** `domain(revert): revert "<original commit header>"` — the original
  header is quoted verbatim inside the title.
- **Body:** state the **operational reason** for the revert in one or two
  sentences (why it was undone, not just that it was undone).
- **Trailer (Git):** `Reverts-Commit: <8-character-short-sha>` — exactly eight
  characters.
- **Trailer (Jujutsu):** `Reverts-Change: <8-character-short-id>` — exactly
  eight characters.
- **Insufficient evidence:** if the original header or the eight-character
  identifier cannot be obtained from the repository, do not fabricate them.
  Emit `Insufficient evidence to suggest a commit message.` instead.

Example — Git revert:

`auth(revert): revert "auth(fix): reject expired sessions"`

`Rollback introduced a regression that dropped valid sessions for clock-skewed clients.`

`Reverts-Commit: a1b2c3d4`

Example — Jujutsu revert:

`auth(revert): revert "auth(fix): reject expired sessions"`

`Rollback introduced a regression that dropped valid sessions for clock-skewed clients.`

`Reverts-Change: e5f6a7b8`

## Grouping and domain decisions

These decisions govern how changes are organized into one or more suggested
commits and how the domain prefix is chosen. They are computed internally and
never printed as a report.

### Group changes by intent and atomicity

Group by functional intent and commit atomicity — do not split every changed
hunk, whitespace difference, or incidental edit into its own unit.

- **Incidental formatting stays with the functional hunk only when directly
  related.** Whitespace, indentation, or lint changes that occur within,
  adjacent to, or directly support a functional change remain in the same
  suggested unit **only if** separating them would make either resulting unit
  incomplete, misleading, or non-atomic. When the incidental formatting is
  merely coincidental to the functional change, do not force it into the same
  unit.
- **Independent formatting remains style/cleanup.** When formatting, lint, or
  whitespace changes are intentionally made on their own and are unrelated to a
  functional change, suggest a separate `style` or `cleanup` unit.
- **Keep units atomic.** If separating a formatting or cross-file change would
  make either resulting unit incomplete, misleading, or non-atomic, keep the
  changes together.

Example — incidental formatting stays grouped:

`parser(fix): reject empty input`

`- guard parse() against None and empty string`
`- reindent parse() for readability`

### Select domains conservatively

- **Prefer the stable parent domain.** Use the most specific stable
  architectural area supported by the diff; do not split a domain merely
  because files live in sub-directories.
- **Sub-domain only with clear evidence.** Use a sub-domain in the DAC prefix
  only when the repository shows the child area is stable, recurring,
  independently meaningful, and would materially improve history navigation or
  ownership. One sub-domain is sufficient; deeper path mirroring is out of
  scope.
- **Allow exactly one meaningful slash-separated sub-domain.** A sub-domain may
  be expressed as a single `parent/child` segment (e.g. `auth/oauth`) when the
  child area is stable, recurring, and independently meaningful. Deeper
  `a/b/c/...` chains are not permitted.
- **No mechanical path-derived sub-domains.** Never derive a sub-domain by
  mechanically truncating or mirroring the file path (e.g. do not turn
  `src/api/v1/handlers/login.py` into `api/v1/handlers/login`); the sub-domain
  must carry architectural meaning on its own.

### Handle coupled multi-domain changes

- **One primary domain per commit.** When a change touches multiple domains,
  choose a single primary domain for the header. Do not invent multi-domain
  header syntax that DAC does not define.
- **Preserve atomicity.** Keep inherently coupled cross-domain changes together
  when splitting would produce an incomplete, non-buildable, or non-atomic
  commit.
- **Mention secondary domains in the body.** When a coupled change includes a
  secondary domain whose role helps explain the commit, name that domain in the
  body rather than the header.

Example — coupled domains use one primary domain:

`notify(feat): add webhook sender`

`- implement WebhookSender.post()`
`- update token scope the sender requires`

(`notify` is the primary domain; the coupled `auth` scope change is described in
the body, not the header.)

## File / hunk grouping

- For a **single cohesive commit**, do not include a Files section.
- For **logical split suggestions**, include a plain-text `Files:` section per
  proposed commit (see Logical split suggestions). The Files section is
  uncolored (never wrapped in backticks).
- List a file **without hunks** (a whole-file listing) when the entire file
  belongs to that commit (e.g. `src/api.py`).
- Show **specific hunks only** when a file is split between commits or only
  selected lines belong to this commit. Use precise line ranges or recognizable
  hunk descriptions (e.g. `src/api.py: lines 10-14`).
- **Never** stage, commit, or physically split the changes — only describe the
  grouping. The listing is a suggestion, not an action performed.

## Logical split suggestions

Identify unrelated cohesive units in the change and provide one complete
`domain(type): title` message per unit — without performing the split.

- Tests/docs that directly support the same implementation change stay in one
  unit.
- Independent fixes, features, refactors, or docs changes should be separated;
  for each proposed unit, emit its message (title/body as inline code spans),
  then a plain-text `Files:` section listing the files/hunks assigned to that
  commit (whole-file or hunk-specific as above).
- Between complete commit units, place a Markdown horizontal separator `---`
  on its own unstyled line — outside any inline-code span, after the previous
  unit's plain `Files:` section and before the next commit message. Do not add
  a separator for a single cohesive commit.

## Edge-state handling

Compute internally and stop with a concise actionable message instead of
inventing one:

- **No meaningful change:** nothing to describe →
  `Nothing to suggest: no meaningful change detected.`
- **Untracked-only:** report untracked files in the concise message (e.g.
  `Untracked files detected: src/new.py. Add them, then re-run.`); do not treat
  them as a safe complete diff if their contents can't be reliably interpreted.
- **Ambiguous / unsupported state:** identify the limitation and stop with a
  concise message; when no VCS is present, include the optional non-executed
  initialization suggestion (`jj git init` preferred when the user wants
  Jujutsu, otherwise `git init`). Never execute it.
- **Insufficient evidence:** if the change can't be responsibly described, output
  only `Insufficient evidence to suggest a commit message.` rather than guessing.

These messages are plain text (not wrapped in backticks) and contain no VCS,
readiness, or other metadata labels.

## Output shape

The user-facing output is **ONLY the commit message** (or, for
blocker/edge/unsupported states, only a concise actionable message). No
VCS/readiness headings, no explanations, labels, or prose outside the
message(s), and no code fences.

- **Single cohesive commit:** emit the title line and every body/bullet line as
  its own inline Markdown code span using single backticks, preserving blank
  lines as actual blank lines between spans. No Files section.
- **Logical split:** for each unit, emit its title/body as inline code spans,
  then a plain-text `Files:` section (uncolored, not backticked) listing that
  commit's files/hunks. Between units, place a Markdown `---` separator on its
  own unstyled line (outside inline-code spans), after the previous unit's
  Files section and before the next commit message. Do not add a separator for
  a single cohesive commit.
- **Blockers / unsupported / edge states:** emit only the concise actionable
  plain-text message described above. Never fabricate a commit message when one
  is prohibited.

Example — single cohesive commit:

`parser(fix): reject empty input`

`- guard parse() against None and empty string`
`- drop leftover TODO in scanner`

Example — breaking change:

`auth(fix)!: reject expired sessions`

`- treat session expiry as a hard failure`
`- drop lenient grace-period fallback`

`BREAKING CHANGE: clients must refresh tokens before expiry; the grace period is removed.`

Example — dependency bump (domain, not type):

`deps(bump): upgrade requests to 2.32`

`- pin requests 2.32.0 to fix redirect handling`

Example — issue trailers:

`notify(feat): add webhook sender`

`- implement WebhookSender.post()`
`- retry with exponential backoff`

`closes #10`
`refs #12`

Example — logical split:

`parser(fix): reject empty input`

`- guard parse() against None and empty string`

Files:
- src/parser.py
- src/scanner.py: lines 22-30

`notify(feat): add webhook sender`

`- implement WebhookSender.post()`

Files:
- src/notify/webhook.py

---

`ci(bump): bump runner image`

`- pin ubuntu-24.04 in workflow`

Files:
- .github/workflows/test.yml
