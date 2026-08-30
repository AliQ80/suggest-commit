---
name: suggest-commit
description: "Suggests a readiness-aware, domain-based commit message formatted as `domain(type): title`. Invoke ONLY when the user explicitly requests a commit suggestion — e.g. by running `/suggest-commit` or by clearly asking in natural language to 'suggest a commit message', 'draft a commit', or 'what should I commit'. Do NOT trigger automatically after an agent finishes work, and do NOT run on implicit or ambient requests. Read-only: never stages, commits, edits files, or changes VCS state. Output is ONLY the proposed commit message(s) (title/body as inline code spans); for logical splits an uncolored Files section is appended per commit; blockers/edge states emit a concise actionable message."
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
  `domain(type): title`.
  - `domain` = the affected **subsystem, component, directory, or technical
    concern** (e.g. `auth`, `parser`, `notify`, `ci`, `readme`). A domain is
    **never** a generic Conventional Commits *type*. Domain inference is
    internal; it is never explained or labeled in the user-facing message.
  - `type` = one entry from the vocabulary below. Pick the most accurate; add a
    new type only if none fits.
- **Pre-output self-check is mandatory.** Before emitting any message, validate
  each candidate: domain is a real concern (not a conventional type), type is
  from the vocabulary, title is <=50 chars (hard max 72), and every non-title
  line wraps at 72 columns. Reject and fix any violation. Then render per the
  Output shape: the title line and every body/bullet line is wrapped in single
  backticks; the Files section (split suggestions only) is plain text and is
  never backticked.

## Type vocabulary

Choose the type from this list:

`feat`, `fix`, `style`, `refactor`, `perf`, `test`, `build`, `ci`,
`ops`, `chore`, `revert`, `merge`, `init`, `deps`, `design`, `improve`,
`security`, `release`, `wip`.

Add a new type only when none of these fits accurately.

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

## Message format

For each cohesive unit, build one complete message:

```
domain(type): title

One-to-two sentence overview of the motivation or problem solved.

- Bullet for each granular change
- Key decision and, when relevant, discarded alternative
- Reference (issue/PR) when applicable
```

- For a **single cohesive commit** (all changed files belong together), emit
  only the message above. Do **not** include a Files section.
- For **logical split suggestions**, emit the message for each unit followed by
  a plain-text `Files:` section (see Logical split suggestions). Domain
  inference is internal and is never shown in the message.

### Title rules

- Format **exactly** `domain(type): title`.
- Target title length **<= 50 characters**; **hard maximum 72 characters**
  (reject and shorten any longer title).
- Imperative style; lowercase the first word (and others where natural); **no
  trailing period**.
- `domain` is the affected subsystem, component, directory, or technical
  concern — **never** a generic Conventional Commits type. For a build refactor
  the domain is `build`/`ci`, not `refactor`.

### Body rules

- **Wrap every non-title line at 72 columns**, preserving blank lines and bullet
  markers (`- `). Overview and bullets stay concise.
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

`ci(build): bump runner image`

`- pin ubuntu-24.04 in workflow`

Files:
- .github/workflows/test.yml
