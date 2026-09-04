# suggest-commit

An OpenCode skill and slash command that suggests a readiness-aware commit
message from the current repository change.

It produces domain area commit based messages in this format:

```text
domain(type): title
```

The skill is read-only: it inspects repository state but never stages, commits,
edits, or otherwise mutates files.

## Install

The one-line installer downloads the skill and command into your OpenCode
configuration:

```sh
curl -fsSL https://raw.githubusercontent.com/AliQ80/suggest-commit/main/install.sh | sh
```

The installer places files under:

```text
~/.config/opencode/skills/suggest-commit/SKILL.md
~/.config/opencode/commands/suggest-commit.md
```

Set `XDG_CONFIG_HOME` to use a different configuration directory.

### Install from a clone

```sh
git clone https://github.com/AliQ80/suggest-commit.git
cd suggest-commit
./install.sh
```

After installation, restart or reload OpenCode.

## Usage

Invoke the command explicitly:

```text
/suggest-commit
```

You can also ask OpenCode directly:

```text
Suggest a commit message for these changes.
```

The skill does not activate automatically after another agent finishes work.

## What it checks

- Detects Jujutsu or Git repository state.
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
differs, the installer asks before overwriting it when run interactively.

## License

This project is licensed under the MIT License.
