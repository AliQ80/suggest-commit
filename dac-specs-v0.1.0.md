# Domain Area Commit Specification v0.1.0
### Author: Ali Karam

## Summary

The Domain Area Commit (DAC) specification is an architecture-first standard for structuring commit messages. By placing the impacted domain area at the front of every commit, DAC prioritizes codebase navigation, human readability, developer intent, and consistency while retaining machine-readable action types for tooling.

The structural commit message layout is defined as:

```
domain(type): title

[optional body]

[optional footer(s)]

```

For breaking changes, the exclamation indicator `!` **MUST** be placed immediately before the colon:

```
domain(type)!: title

[optional body]

[optional footer(s)]

```

---

## 1. Specification & Syntax Rules

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 (RFC 2119 and RFC 8174) when, and only when, they appear in all capitals, as shown here.

### 1.1 Domain Rules (The Location)

1. Commits **MUST** be prefixed with a `domain`, which identifies the primary stable architectural area, component, directory, or technical concern affected by the change (e.g., `auth`, `parser`, `deps`, `ci`, `ops`, `build`, `docs`).
2. A domain **MUST NOT** be a generic action type (e.g., `feat` or `fix` cannot be used as a domain area).
3. Domains **SHOULD** represent stable architectural concepts rather than individual files, temporary implementation details, or arbitrary task names.
4. Sub-domains **MAY** be specified using a forward slash `/` to indicate nested directory or module hierarchy (e.g., `auth/jwt`, `ui/button`, `billing/stripe`).
5. **Multi-Domain Rule:** A commit **SHOULD** affect only a single domain area so that the change remains easy to understand, review, and revert.
6. A commit **MAY** span multiple domain areas when those areas are inherently coupled and separating the change would make the resulting commits less meaningful or less atomic.

### 1.2 Type Rules (The Action)

1. The `domain` **MUST** be immediately followed by a structural `type` enclosed within parentheses `()`.
2. The `type` **MUST** be a concise classification describing the nature or purpose of the change (e.g., `feat`, `fix`, `improve`, `refactor`, `perf`, `security`, `bump`, `cleanup`, `style`, `test`, `revert`, `init`, `release`, `wip`, `merge`).
3. The standard DAC types are defined in Section 4.
4. Projects **MAY** define additional project-specific types when the standard vocabulary does not adequately describe their changes. DAC does not assign built-in release-version meaning to custom types.
5. Vague maintainer catch-alls (such as `chore`) are **DISCOURAGED** in favor of more precise types like `cleanup`, `bump`, `improve`, or `style`.

### 1.3 Breaking Changes

1. A breaking change **MUST** be explicitly indicated by appending an exclamation mark `!` immediately after the closing parenthesis of the type (e.g., `api(feat)!: change payload structure`).
2. The `!` indicator on the header line is **MANDATORY** for any commit introducing a breaking change.
3. The `!` marker signals a breaking change to a public interface or contract. It denotes the nature of the change only and does **NOT** by itself assign a release version or imply any release-automation behavior; versioning policy remains a project concern outside this specification.
4. A `BREAKING CHANGE:` header in the commit footer is **OPTIONAL** and serves to elaborate on breaking details, migration steps, or contractual impacts if not already fully detailed in the body.

### 1.4 Title Rules

1. A colon and space (`: `) **MUST** immediately follow the type's closing parenthesis (or breaking indicator `!`).
2. A `title` **MUST** follow the colon and space.
3. The title **SHOULD** be written in the imperative mood, following the sentence test: *"If applied, this commit will `<title>`"*. (e.g., prefer `add`, `fix`, `change` over `added`, `fixes`, `changing`).
4. Title formatting constraints:
* The title **SHOULD** be limited to 50 characters or fewer.
* The title **MUST NOT** exceed 72 characters.
* The title **MUST** start with a lowercase letter where natural, unless starting with a proper noun or code symbol (e.g., `api(fix): handle NullPointerException`).
* The title **MUST NOT** end with a period (`.`) or other trailing punctuation.



### 1.5 Body Rules

1. A longer commit `body` **MAY** be provided after the title line, separated by a single blank line.
2. Non-title body lines **MUST** be wrapped at 72 columns or fewer.
3. The commit body **MUST** provide self-contained context (*what* changed and *why*) so that a reader can understand the change without relying solely on external URLs or issue trackers.
4. Pure formatting, linting, or whitespace changes **MUST** be isolated into dedicated `domain(style)` or `domain(cleanup)` commits and **MUST NOT** be mixed into functional feature or bug fix commits.

### 1.6 Footer & Trailer Rules

1. Footers **MAY** be provided after the commit body, separated by a single blank line.
2. Each footer entry **MUST** appear on its own line and follow standard key-value or trailer syntax (e.g., `Key: value` or `key #value`).
3. Trailer keys **MUST** capitalize only the very first letter of the key name (e.g., favor `Signed-off-by:` over `Signed-Off-By:` and `Acked-by:` over `Acked-By:`).
4. **Issue Management Trailers:**
* `closes #10` (or full URL): Instructs forge automation to automatically transition referenced issues/PRs to a closed state upon landing in the default branch.
* `reopens #10` (or full URL): Instructs supported forge automation to reopen a previously closed issue or PR.
* `refs #10` (or full URL): Associates the commit with an issue or PR without altering its state.
* **Single-Issue Rule:** When a commit relates to multiple issues, each issue **MUST** sit on its own dedicated trailer line (e.g., `closes #10\ncloses #11`).


5. **Standard Collaboration & Credit Trailers:** The following standard trailers are **RECOMMENDED** when they adequately represent the contribution or collaboration. Projects **MAY** use additional trailers when needed.
* `Signed-off-by: Name <email>`
* `Co-authored-by: Name <email>`
* `Reported-by: Name <email>`
* `Reviewed-by: Name <email>`
* `Acked-by: Name <email>`
* `Tested-by: Name <email>`
* `Helped-by: Name <email>`
* `Mentored-by: Name <email>`
* `Suggested-by: Name <email>`



---

## 2. Revert Commit Protocol

When undoing a prior commit, the message **MUST** adhere to the following structure:

1. **Header Format:** The header **MUST** use the `revert` action type and repeat the original commit header enclosed in double quotes:
`domain(revert): revert "<original commit header>"`
2. **Body Requirement:** The commit body **MUST** state the operational reason for the revert.
3. **Identifier Trailer Requirement:** The footer **MUST** include an explicit 8-character short identifier trailer referencing the targeted change:
* For **Git** repositories: `Reverts-Commit: <8-char-short-sha>`
* For **Jujutsu** repositories: `Reverts-Change: <8-char-short-id>`



---

## 3. Standard Domain Area Guidelines

Technical domain areas and repository infrastructure are classified strictly as **Domains**, never as Types. Common cross-cutting domain areas include:

* **`deps`**: Dependency manifests, package locks, and version declarations (`package.json`, `Cargo.toml`, `go.mod`, `pnpm-lock.yaml`).
* **`ci`**: Continuous integration workflows and test pipelines (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`).
* **`ops`**: Infrastructure as Code, container manifests, and deployment scripts (`Dockerfile`, `terraform/`, `k8s/`, `nginx.conf`).
* **`build`**: Compiler profiles, module bundler options, and transpiler configurations (`vite.config.ts`, `tsconfig.json`, `webpack.config.js`).
* **`docs`**: Root or module documentation files (`README.md`, `CONTRIBUTING.md`).

---

## 4. Action Type Vocabulary

The standard DAC type vocabulary describes the nature of the action performed on a domain area, evaluated **independent of the `domain` prefix**. Type descriptions explain how to classify a change; they do not prescribe release or versioning behavior.

| Type | Purpose |
| --- | --- |
| **ANY Type** + `!` | Breaking public interface or contractual change |
| `feat` | Adds new user- or system-facing functionality |
| `improve` | Enhances existing functionality without breaking interfaces |
| `fix` | Fixes a bug or unintended behavior |
| `perf` | Improves execution performance or resource usage |
| `security` | Patches a vulnerability, policy issue, or encryption routine |
| `bump` | Upgrades external dependencies or base images |
| `revert` | Reverts a previous commit to restore state |
| `cleanup` | Removes dead code, obsolete files, or unused assets |
| `refactor` | Internal code restructuring without behavioral change |
| `style` | Formatting, whitespace, semi-colons, linter rule updates |
| `test` | Adds missing tests or corrects existing test suites |
| `init` | Project setup or initial module bootstrap |
| `release` | Version bump commit or release tag marker |
| `wip` | Work-in-progress commit (temporary branch marker) |
| `merge` | Explicit branch merge commit |

---

## 5. Relationship to Conventional Commits

DAC is an independent commit-message standard inspired by the structure and conventions of Conventional Commits. It retains familiar concepts such as structured types, breaking-change indicators, bodies, and trailers while making the affected domain area the first structural element.

The primary structural distinction is:

```text
DAC:                  domain(type): title
Conventional Commits: type(scope): title
```

DAC therefore treats the domain as the primary navigation element and the type as the classification of the change.

---

## 6. Design Principles

DAC is guided by the following principles:

1. **Domain first:** A reader should be able to identify where a change belongs immediately.
2. **Consistent vocabulary:** Projects should prefer a small, recognizable set of types over vague or redundant classifications.
3. **Human-readable history:** Commit messages should remain useful when read months or years after they were written.
4. **Consistent structure:** Every commit should follow the same recognizable pattern.
5. **Atomic changes:** Commits should represent coherent changes that can be understood and, when appropriate, reverted independently.
6. **Useful hierarchy:** Sub-domains may provide additional architectural context without requiring an elaborate taxonomy.
7. **Practicality:** DAC should improve everyday project history without requiring excessive ceremony from contributors.

---

## 7. Examples

### 7.1 Standard Feature & Bug Fix

```
auth(feat): add passkey authentication support

```

```
parser(fix): reject empty input strings gracefully

```

### 7.2 Sub-Domain Hierarchy

```
auth/jwt(fix): validate token expiration timestamps

```

```
ui/button(improve): add hover state animations

```

### 7.3 Dependency & Infrastructure Updates (Using Domains)

```
deps(bump): upgrade react to v19.0.0

```

```
ci(fix): resolve race condition in test runner workflow

```

```
ops(security): update base container image to alpine 3.19

```

### 7.4 Revert Commits

#### Git Repository Revert

```
auth(revert): revert "auth(fix)!: require mfa for admin routes"

Reverting due to session lockouts on legacy admin accounts during staging deployment.

Reverts-Commit: 8f2a1b9c

```

#### Jujutsu Repository Revert

```
auth(revert): revert "auth(fix)!: require mfa for admin routes"

Reverting due to session lockouts on legacy admin accounts during staging deployment.

Reverts-Change: zzzzzzzz

```

### 7.5 Complete Structured Commit with Body and Footers

```
notify(feat): implement exponential backoff for webhooks

Adds retry logic to prevent server saturation during subscriber downtime.
Calculates initial delay using base factor of 2 with maximum cap of 5 retries.

- implement WebhookSender.retry_with_backoff()
- log warning after 3 failed delivery attempts

closes #402
closes #405
Co-authored-by: Alex River <alex@example.com>
Signed-off-by: Taylor Smith <taylor@example.com>

```
