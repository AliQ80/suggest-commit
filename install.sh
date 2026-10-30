#!/bin/sh
# Install the shared suggest-commit skill for Codex, OpenCode, or both.
# With no --target, offer a terminal menu; without a terminal, use OpenCode.
# Sources come from this clone, or BASE_URL when local files are absent.
set -eu

usage() {
  echo 'Usage: install.sh [--target codex|opencode|both]'
}

restore_terminal() {
  if [ -n "$terminal_state" ]; then
    stty "$terminal_state" <&3 || :
    terminal_state=''
  fi
  if [ "$cursor_hidden" -eq 1 ]; then
    printf '%s' "$cursor_normal" >&3
    cursor_hidden=0
  fi
}

cleanup() {
  restore_terminal
  if [ -n "$download_dir" ]; then
    rm -rf "$download_dir"
  fi
}

cancel() {
  printf '\nInstallation cancelled.\n' >&3
  exit 130
}

numbered_menu() {
  printf 'Install suggest-commit for:\n1. Codex\n2. OpenCode\n3. Both\n' >&3
  while :; do
    printf 'Choose [2], or q to cancel: ' >&3
    IFS= read -r choice <&3 || cancel
    case "$choice" in
      1) target=codex; return ;;
      2|'') target=opencode; return ;;
      3) target=both; return ;;
      q|Q) cancel ;;
      *) printf 'Choose 1, 2, or 3.\n' >&3 ;;
    esac
  done
}

checkbox_menu() {
  # Probe everything before switching terminal modes; otherwise use line input.
  command -v stty >/dev/null 2>&1 || return 1
  command -v tput >/dev/null 2>&1 || return 1
  command -v dd >/dev/null 2>&1 || return 1
  case "${TERM:-dumb}" in dumb|'') return 1 ;; esac
  menu_up=$(tput cuu 4 2>/dev/null) || return 1
  clear_line=$(tput el 2>/dev/null) || return 1
  cursor_hide=$(tput civis 2>/dev/null) || return 1
  cursor_normal=$(tput cnorm 2>/dev/null) || return 1
  columns=$(tput cols 2>/dev/null) || return 1
  rows=$(tput lines 2>/dev/null) || return 1
  [ "$columns" -ge 60 ] && [ "$rows" -ge 8 ] || return 1
  terminal_state=$(stty -g <&3) || return 1
  # Handle Ctrl-C as a key to avoid races between the shell and byte reader.
  if ! stty -icanon -echo -isig min 1 time 0 <&3; then
    restore_terminal
    return 1
  fi
  cursor_hidden=1
  printf '%sInstall suggest-commit for:\n' "$cursor_hide" >&3
  select_codex=0
  select_opencode=1
  focus=0
  notice=''
  escape=$(printf '\033')
  carriage_return=$(printf '\r')
  end_input=$(printf '\004')
  interrupt=$(printf '\003')
  while :; do
    codex_mark=' '
    opencode_mark=' '
    codex_focus=' '
    opencode_focus=' '
    [ "$select_codex" -eq 0 ] || codex_mark=x
    [ "$select_opencode" -eq 0 ] || opencode_mark=x
    if [ "$focus" -eq 0 ]; then codex_focus='>'; else opencode_focus='>'; fi
    printf '\r%s%s [%s] Codex\n' "$clear_line" "$codex_focus" "$codex_mark" >&3
    printf '\r%s%s [%s] OpenCode\n' "$clear_line" "$opencode_focus" "$opencode_mark" >&3
    printf '\r%sUp/Down Move | Space Toggle | Enter Install | q Cancel\n' "$clear_line" >&3
    printf '\r%s%s\n' "$clear_line" "$notice" >&3
    key=$(dd bs=1 count=1 <&3 2>/dev/null) || cancel
    case "$key" in
      "$escape")
        # A lone Escape cancels; time out rather than waiting for another key.
        stty min 0 time 1 <&3 || cancel
        prefix=$(dd bs=1 count=1 <&3 2>/dev/null) || cancel
        arrow=$(dd bs=1 count=1 <&3 2>/dev/null) || cancel
        stty min 1 time 0 <&3 || cancel
        case "$prefix$arrow" in
          '[A'|'[B'|'OA'|'OB') focus=$((1 - focus)) ;;
          '') cancel ;;
        esac ;;
      ' ')
        if [ "$focus" -eq 0 ]; then
          select_codex=$((1 - select_codex))
        else
          select_opencode=$((1 - select_opencode))
        fi
        notice='' ;;
      ''|"$carriage_return")
        if [ "$select_codex" -eq 1 ] && [ "$select_opencode" -eq 1 ]; then
          target=both
        elif [ "$select_codex" -eq 1 ]; then
          target=codex
        elif [ "$select_opencode" -eq 1 ]; then
          target=opencode
        else
          notice='Select at least one target.'
        fi
        if [ -n "$target" ]; then
          restore_terminal
          return 0
        fi ;;
      q|Q|"$end_input"|"$interrupt") cancel ;;
    esac
    printf '%s' "$menu_up" >&3
  done
}

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    echo 'install.sh: neither curl nor wget available for remote mode.' >&2
    return 1
  fi
}

install_one() {
  source_file=$1
  destination=$2
  if [ ! -f "$source_file" ]; then
    echo "Source file missing: $source_file" >&2
    return 1
  fi
  if [ -f "$destination" ]; then
    if cmp -s "$source_file" "$destination"; then
      echo "Already up to date: $destination"
      unchanged=$((unchanged + 1))
      return 0
    fi
    if [ "$have_terminal" -eq 1 ]; then
      printf 'Overwrite %s? [y/N] ' "$destination" >&3
      IFS= read -r answer <&3 || answer=n
      case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Skipped: $destination"; skipped=$((skipped + 1)); return 0 ;;
      esac
    else
      echo "Refusing to overwrite existing $destination (no terminal). Re-run interactively." >&2
      return 1
    fi
  fi
  mkdir -p "$(dirname -- "$destination")" || return 1
  cp "$source_file" "$destination" || return 1
  echo "Installed: $destination"
  installed=$((installed + 1))
}

main() {
  target=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target)
        [ "$#" -ge 2 ] && [ -z "$target" ] || { usage >&2; exit 2; }
        target=$2
        case "$target" in codex|opencode|both) ;; *) usage >&2; exit 2 ;; esac
        shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; exit 2 ;;
    esac
  done

  terminal_state=''
  cursor_hidden=0
  download_dir=''
  have_terminal=0
  trap cleanup 0
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  # Never read menu/confirmation input from stdin: it may contain this script.
  if ( : <> /dev/tty ) 2>/dev/null; then
    exec 3<> /dev/tty
    if [ -t 3 ]; then have_terminal=1; fi
  fi
  if [ -z "$target" ]; then
    if [ "$have_terminal" -eq 1 ]; then
      checkbox_menu || numbered_menu
    else
      target=opencode
    fi
  fi

  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || script_dir=$PWD
  skill_source="$script_dir/skills/suggest-commit/SKILL.md"
  command_source="$script_dir/commands/suggest-commit.md"
  need_opencode=0
  case "$target" in opencode|both) need_opencode=1 ;; esac
  base_url=${BASE_URL:-https://raw.githubusercontent.com/AliQ80/suggest-commit/main}
  base_url=${base_url%/}
  if [ ! -f "$skill_source" ] || { [ "$need_opencode" -eq 1 ] && [ ! -f "$command_source" ]; }; then
    download_dir=$(mktemp -d)
    echo "Downloading from BASE_URL=$base_url"
    skill_source="$download_dir/SKILL.md"
    fetch "$base_url/skills/suggest-commit/SKILL.md" "$skill_source"
    if [ "$need_opencode" -eq 1 ]; then
      command_source="$download_dir/suggest-commit.md"
      fetch "$base_url/commands/suggest-commit.md" "$command_source"
    fi
  fi

  installed=0
  unchanged=0
  skipped=0
  failed=0
  config_home=${XDG_CONFIG_HOME:-$HOME/.config}
  case "$target" in
    codex|both)
      install_one "$skill_source" "$HOME/.agents/skills/suggest-commit/SKILL.md" || failed=$((failed + 1)) ;;
  esac
  if [ "$need_opencode" -eq 1 ]; then
    install_one "$skill_source" "$config_home/opencode/skills/suggest-commit/SKILL.md" || failed=$((failed + 1))
    install_one "$command_source" "$config_home/opencode/commands/suggest-commit.md" || failed=$((failed + 1))
  fi
  printf '\nInstalled: %s; unchanged: %s; skipped: %s; failed: %s.\n' "$installed" "$unchanged" "$skipped" "$failed"
  [ "$failed" -eq 0 ] || exit 1
  echo 'Codex detects new skills automatically; restart if needed. Reload or restart OpenCode.'
}

# Parse the full workflow before running it, including when invoked through sh's stdin.
main "$@"
