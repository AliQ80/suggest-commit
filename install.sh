#!/bin/sh
# install.sh — install the suggest-commit skill and command for OpenCode.
#
# Two modes:
#   1. LOCAL mode (default): run from a cloned/downloaded copy of this project.
#      Source files are expected next to this script at:
#        <script-dir>/skills/suggest-commit/SKILL.md
#        <script-dir>/commands/suggest-commit.md
#      They are copied into the user's OpenCode config directory.
#
#   2. REMOTE mode: when the distribution files are NOT present locally but a
#      BASE_URL is supplied, this script downloads the raw files with curl/wget
#      into a temp dir and installs them. Enable by setting BASE_URL to the raw
#      GitHub repository root URL (the directory that contains skills/ and
#      commands/).
#
# Usage:
#   ./install.sh                         # local install from a clone
#   BASE_URL=https://raw.githubusercontent.com/OWNER/REPO/main \
#     ./install.sh                       # remote install (downloads files)
#   # or via curl:
#   curl -fsSL https://raw.githubusercontent.com/AliQ80/suggest-commit/main/install.sh | sh
#
# BASE_URL can still be overridden when installing from a fork or another
# distribution source.

set -eu

# Resolve the directory containing this script.
# POSIX-safe: average shells set $0; fall back to PWD for the running shell.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
if [ -z "${SCRIPT_DIR}" ]; then
  SCRIPT_DIR=$(pwd)
fi

DIST_DIR="${SCRIPT_DIR}"
SKILL_SRC="${DIST_DIR}/skills/suggest-commit/SKILL.md"
CMD_SRC="${DIST_DIR}/commands/suggest-commit.md"

# Destination under the user's OpenCode config.
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
SKILL_DST="${CONFIG_HOME}/opencode/skills/suggest-commit/SKILL.md"
CMD_DST="${CONFIG_HOME}/opencode/commands/suggest-commit.md"

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/AliQ80/suggest-commit/main}"

have_local=0
if [ -f "${SKILL_SRC}" ] && [ -f "${CMD_SRC}" ]; then
  have_local=1
fi

# --- Remote bootstrap: download into a temp dir when no local copy exists. ---
if [ "${have_local}" -eq 0 ]; then
  if [ -z "${BASE_URL}" ]; then
    cat >&2 <<'EOF'
install.sh: no local distribution found and BASE_URL is not set.

This script was likely invoked via curl|sh with no BASE_URL, or run from a
location that does not contain the suggest-commit/ distribution.

To install from a clone:
    git clone <repo> && cd <repo> && ./install.sh

To install via curl with downloads:
    BASE_URL=https://raw.githubusercontent.com/OWNER/REPO/main \
      curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | sh
EOF
    exit 1
  fi

  # Strip a trailing slash for safe joining.
  BASE_URL="${BASE_URL%/}"
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "${TMP_DIR}"' EXIT

  fetch() { # fetch <url> <outfile>
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$2" "$1"
    else
      echo "install.sh: neither curl nor wget available for remote mode." >&2
      exit 1
    fi
  }

  echo "Downloading from BASE_URL=${BASE_URL}"
  fetch "${BASE_URL}/skills/suggest-commit/SKILL.md" "${TMP_DIR}/SKILL.md"
  fetch "${BASE_URL}/commands/suggest-commit.md" "${TMP_DIR}/suggest-commit.md"

  SKILL_SRC="${TMP_DIR}/SKILL.md"
  CMD_SRC="${TMP_DIR}/suggest-commit.md"
fi

install_one() { # install_one <src> <dst>
  src="$1"
  dst="$2"
  if [ ! -f "${src}" ]; then
    echo "install.sh: source file missing: ${src}" >&2
    exit 1
  fi
  dstdir=$(dirname -- "${dst}")
  mkdir -p "${dstdir}"

  if [ -f "${dst}" ]; then
    if cmp -s "${src}" "${dst}"; then
      echo "Already up to date: ${dst}"
      return
    fi
    # Do not overwrite without confirmation.
    if [ -t 0 ]; then
      printf 'Overwrite %s? [y/N] ' "${dst}"
      read -r ans
      case "${ans}" in
        y|Y|yes|YES) ;;
        *) echo "Skipped: ${dst}"; return ;;
      esac
    else
      echo "Refusing to overwrite existing ${dst} (non-interactive). Re-run interactively or delete it." >&2
      exit 1
    fi
  fi

  cp "${src}" "${dst}"
  echo "Installed: ${dst}"
}

install_one "${SKILL_SRC}" "${SKILL_DST}"
install_one "${CMD_SRC}" "${CMD_DST}"

echo
echo "Done. Restart OpenCode (or reload) to pick up the new skill/command."
