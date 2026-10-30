# suggest-commit

A shared Codex and OpenCode skill that suggests a readiness-aware commit
message from the current repository change, with an OpenCode slash command.

It produces domain area commit based messages in this format:

```text
domain(type): title
```

The skill inspects changes without editing files, staging, creating commits,
rebasing, or squashing. Normal automatic Jujutsu snapshots are allowed so it
sees up-to-date working-copy contents.

## Install

Requires Codex or OpenCode, and Git or Jujutsu for repository inspection.
The installer uses a POSIX shell and standard command-line utilities; remote
installation also requires `curl` or `wget`.

```sh
curl -fsSL https://raw.githubusercontent.com/AliQ80/suggest-commit/main/install.sh | sh
```

When a terminal is available, choose either or both hosts in a checkbox menu:

```text
Install suggest-commit for:
> [ ] Codex
  [x] OpenCode

Up/Down Move | Space Toggle | Enter Install | q Cancel
```

OpenCode is initially selected. Use **Up/Down** to move, **Space** to toggle,
and **Enter** to install at least one selected target. Press **q**, **Escape**,
or **Ctrl-C** to cancel. Terminals without checkbox support use numbered
Codex/OpenCode/Both choices instead (q or Ctrl-C cancels there).
The menu reads from the controlling terminal even with `curl | sh`.
With no terminal and no target flag, installation defaults to OpenCode.

### Choose a target directly

Target flags skip the selection menu. For example, install for Codex:

```sh
curl -fsSL https://raw.githubusercontent.com/AliQ80/suggest-commit/main/install.sh |
  sh -s -- --target codex
```

Use `--target opencode` or `--target both` for the other choices.
For unattended installation, supply a target explicitly; existing differing
files are never overwritten without interactive confirmation.

### Install from a clone

```sh
git clone https://github.com/AliQ80/suggest-commit.git
cd suggest-commit
./install.sh
```

Or bypass the selection menu:

```sh
./install.sh --target codex
./install.sh --target opencode
./install.sh --target both
```

### Installation locations

| Host | Files |
| --- | --- |
| Codex | `~/.agents/skills/suggest-commit/SKILL.md` |
| OpenCode | `~/.config/opencode/skills/suggest-commit/SKILL.md` and `~/.config/opencode/commands/suggest-commit.md` |

`XDG_CONFIG_HOME` changes the OpenCode configuration location only. Selecting
both installs the same skill for each host and the command wrapper for OpenCode.
Codex detects new skills automatically; restart if it does not appear. Restart
or reload OpenCode after installation.

### Install for one repository in Codex

From this clone, copy the skill into the target repository:

```sh
mkdir -p /path/to/repo/.agents/skills/suggest-commit
cp skills/suggest-commit/SKILL.md /path/to/repo/.agents/skills/suggest-commit/SKILL.md
```

Choose either user-wide or repository-local installation to avoid duplicate
entries for the same skill.

## Usage

In Codex, select the skill explicitly:

```text
$suggest-commit
```

In OpenCode, run:

```text
/suggest-commit
```

In either host, you can also ask directly:

```text
Suggest a commit message for these changes.
```

The skill does not activate automatically after another agent finishes work.
A request to create a commit does not authorize this suggestion workflow to
stage files or commit anything.

## What it checks

- Detects Jujutsu or Git from repository roots, subfolders, and Git worktrees.
- Reads recent history for established domain names and wording; the current
  diff determines the message content.
- Describes staged changes first when Git has staged changes.
- Identifies cohesive changes and suggests logical commit splits when needed.
- Uses the affected subsystem as the message domain.
- Checks for obvious blockers such as TODOs, debug leftovers, and incomplete
  branches before suggesting a ready-to-commit message.
- Reports unsupported, empty, or untracked-only states instead of inventing a
  commit message.

Standard DAC types are `feat`, `improve`, `fix`, `perf`, `security`, `bump`,
`revert`, `cleanup`, `refactor`, `style`, `test`, `init`, `release`, `wip`, and
`merge`. The `chore` type is **discouraged** and is not part of the standard DAC
vocabulary; prefer a precise type plus a domain (e.g. `ops(cleanup): ...`).
Cross-cutting areas such as `build`, `ci`, `deps`, `ops`, and `docs` are
**domains, not types** — represent the action with a DAC type
(e.g. `deps(bump): ...`, `ci(fix): ...`).

## Repository layout

```text
commands/suggest-commit.md       OpenCode slash command
skills/suggest-commit/SKILL.md   Skill instructions
install.sh                       Local and remote installer
```

## Updating

Run the installer again to install the latest version. If an existing file
differs, the installer asks through the terminal before overwriting it. Without
a terminal, it refuses replacement. Both-target installation applies this rule
to each file; it reports installed, unchanged, skipped, and failed counts and
can partially succeed if a later file cannot be installed.

## Validation

Run installer integration checks in temporary directories using Python 3:

```sh
python3 -B -m unittest discover -s tests -v
sh -n install.sh
shellcheck install.sh
```

The installer tests cover local/remote sources, target selection, overwrite
safeguards, and pseudo-terminal menu interaction without installing into your
real configuration.

## License

This project is licensed under the MIT License.
