#!/usr/bin/env bash
# Sandboxed install.sh test.
#
# Plain bash rather than bats-core: the checks are filesystem and log
# assertions, and bash is already required by install.sh. No test package to
# install on Linux or macOS. Written for bash 3.2 (the macOS /bin/bash).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKS=0
TEST_TMP=""

cleanup() {
  if [[ -n "${TEST_TMP:-}" ]]; then
    rm -rf "$TEST_TMP"
  fi
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  CHECKS=$((CHECKS + 1))
}

assert_eq() {
  local got="$1"
  local expected="$2"
  local message="$3"
  if [[ "$got" != "$expected" ]]; then
    fail "$message (got: [$got], expected: [$expected])"
  fi
  pass
}

assert_file_contains() {
  local file="$1"
  local text="$2"
  if ! grep -F -q -- "$text" "$file"; then
    printf '---- %s ----\n' "$file" >&2
    cat "$file" >&2
    fail "expected [$file] to contain: $text"
  fi
  pass
}

assert_file_excludes() {
  local file="$1"
  local text="$2"
  if grep -F -q -- "$text" "$file"; then
    printf '---- %s ----\n' "$file" >&2
    cat "$file" >&2
    fail "expected [$file] to omit: $text"
  fi
  pass
}

# First matching line number of a fixed string. Empty means missing.
line_of() {
  local pattern="$1"
  local file="$2"
  local hit
  hit="$(grep -n -F -- "$pattern" "$file" || true)"
  hit="${hit%%$'\n'*}"
  if [[ -z "$hit" ]]; then
    fail "pattern not found in $file: $pattern"
  fi
  printf '%s\n' "${hit%%:*}"
}

assert_order() {
  local before="$1"
  local after="$2"
  local file="$3"
  local before_line after_line
  before_line="$(line_of "$before" "$file")"
  after_line="$(line_of "$after" "$file")"
  if [[ "$before_line" -ge "$after_line" ]]; then
    fail "expected [$before] (line $before_line) before [$after] (line $after_line) in $file"
  fi
  pass
}

count_matching() {
  local dir="$1"
  local mindepth="$2"
  local maxdepth="$3"
  local kind="$4"
  find "$dir" -mindepth "$mindepth" -maxdepth "$maxdepth" -type "$kind" | wc -l | tr -d ' '
}

# ------------------------------------------------------------------------------
# Static checks: the fixes stay in the repo files, independent of install.sh
# ------------------------------------------------------------------------------

static_checks() {
  local format_body email name zoxide_init

  grep -q -x 'brew "fzf-tab"' "$ROOT/Brewfile"
  pass
  grep -q -x 'brew "bat"' "$ROOT/Brewfile"
  pass
  grep -q -x 'brew "zoxide"' "$ROOT/Brewfile"
  pass

  zoxide_init="eval \"\$(zoxide init zsh)\""
  assert_order "autoload -Uz compinit" "fzf-tab.zsh" "$ROOT/.zshrc"
  assert_order "fzf-tab.zsh" "$zoxide_init" "$ROOT/.zshrc"
  assert_order "$zoxide_init" "zsh-autosuggestions.zsh" "$ROOT/.zshrc"
  assert_order "zsh-autosuggestions.zsh" "zsh-syntax-highlighting.zsh" "$ROOT/.zshrc"
  assert_order "zsh-syntax-highlighting.zsh" "source <(fzf --zsh)" "$ROOT/.zshrc"

  if grep -F -q '/opt/homebrew/share/' "$ROOT/.zshrc" || grep -F -q '/opt/homebrew/opt/' "$ROOT/.zshrc"; then
    fail ".zshrc still hardcodes a Homebrew plugin path"
  fi
  pass
  if grep -F '.fzf.zsh' "$ROOT/.zshrc" | grep -E -q 'source|\[ -f'; then
    fail ".zshrc still sources ~/.fzf.zsh"
  fi
  pass
  if ! grep -F -q 'HOMEBREW_PREFIX' "$ROOT/.zshrc"; then
    fail ".zshrc does not derive HOMEBREW_PREFIX"
  fi
  pass

  format_body="$(awk '
    $0 == "format = \"\"\"" { capture = 1; next }
    capture && $0 == "\"\"\"" { capture = 0 }
    capture { print }
  ' "$ROOT/starship/starship.toml")"
  if ! printf '%s\n' "$format_body" | grep -F -q "\$python"; then
    fail "starship format does not include \$python"
  fi
  pass
  if ! printf '%s\n' "$format_body" | grep -F -q "\$cmd_duration"; then
    fail "starship format does not include \$cmd_duration"
  fi
  pass

  if grep -q $'\t' "$ROOT/.gitconfig"; then
    fail ".gitconfig still contains tab indentation"
  fi
  pass
  email="$(git config --file "$ROOT/.gitconfig" --get user.email)"
  name="$(git config --file "$ROOT/.gitconfig" --get user.name)"
  assert_eq "$email" "2905652+ouap@users.noreply.github.com" "user.email changed"
  assert_eq "$name" "Ouams" "user.name changed"
  if ! grep -F -q 'excludesfile = ~/.config/git/ignore' "$ROOT/.gitconfig"; then
    fail "core.excludesfile is not ~/.config/git/ignore"
  fi
  pass

  if grep -F -q '.DS_STORE' "$ROOT/.gitignore"; then
    fail ".gitignore still has .DS_STORE"
  fi
  pass
  if ! grep -q -x '.DS_Store' "$ROOT/.gitignore"; then
    fail ".gitignore is missing .DS_Store"
  fi
  pass

  if ! grep -F -q 'zed/settings.json' "$ROOT/install.sh"; then
    fail "install.sh does not link zed/settings.json"
  fi
  pass
  if ! grep -F -q 'git/ignore' "$ROOT/install.sh"; then
    fail "install.sh does not link git/ignore"
  fi
  pass
  if grep -F -q 'install_fzf' "$ROOT/install.sh"; then
    fail "install.sh still installs fzf shell integration"
  fi
  pass
  if ! grep -F -q '.DS_Store' "$ROOT/git/ignore"; then
    fail "global gitignore is missing .DS_Store"
  fi
  pass
}

# ------------------------------------------------------------------------------
# install.sh against a fake HOME and stubbed brew / xcode-select / open / curl
# ------------------------------------------------------------------------------

SOURCES=""
TARGETS=""

add_link() {
  SOURCES="${SOURCES}${1}"$'\n'
  # Second argument is a path relative to the fake HOME.
  TARGETS="${TARGETS}${2}"$'\n'
}

nth_line() {
  local n="$1"
  local data="$2"
  printf '%s\n' "$data" | sed -n "${n}p"
}

link_count() {
  printf '%s\n' "$SOURCES" | sed '/^$/d' | wc -l | tr -d ' '
}

assert_all_symlinks() {
  local home="$1"
  local i count source target got
  count="$(link_count)"
  i=1
  while [[ "$i" -le "$count" ]]; do
    source="$(nth_line "$i" "$SOURCES")"
    target="$home/$(nth_line "$i" "$TARGETS")"
    if [[ ! -L "$target" ]]; then
      fail "not a symlink: $target"
    fi
    got="$(readlink "$target")"
    assert_eq "$got" "$source" "symlink target for $target"
    i=$((i + 1))
  done
}

seed_real_files() {
  local home="$1"
  local i count target
  count="$(link_count)"
  i=1
  while [[ "$i" -le "$count" ]]; do
    target="$home/$(nth_line "$i" "$TARGETS")"
    mkdir -p "$(dirname "$target")"
    printf 'original:%s\n' "$target" > "$target"
    i=$((i + 1))
  done
}

assert_backups() {
  local home="$1"
  local backup_root i count target backup_file
  local dirs files
  dirs="$(count_matching "$home/.dotfiles-backup" 1 1 d)"
  assert_eq "$dirs" "1" "backup timestamp directories"
  files="$(count_matching "$home/.dotfiles-backup" 1 999 f)"
  assert_eq "$files" "$(link_count)" "backed up file count"
  backup_root="$(find "$home/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d)"
  count="$(link_count)"
  i=1
  while [[ "$i" -le "$count" ]]; do
    target="$home/$(nth_line "$i" "$TARGETS")"
    backup_file="$backup_root$target"
    if [[ ! -f "$backup_file" || -L "$backup_file" ]]; then
      fail "missing regular backup file: $backup_file"
    fi
    assert_eq "$(cat "$backup_file")" "original:$target" "backup contents of $target"
    i=$((i + 1))
  done
}

write_stubs() {
  local bin_dir="$1"
  local log="$2"

  cat > "$bin_dir/xcode-select" << EOF
#!/usr/bin/env bash
printf '%s\n' "xcode-select \$*" >> "$log"
if [[ "\${1:-}" == "-p" ]]; then
  printf '%s\n' "/Library/Developer/CommandLineTools"
  exit 0
fi
exit 0
EOF

  cat > "$bin_dir/brew" << EOF
#!/usr/bin/env bash
printf '%s\n' "brew \$*" >> "$log"
case "\${1:-}" in
  shellenv)
    printf '%s\n' 'export HOMEBREW_PREFIX="/opt/homebrew"'
    ;;
  --prefix)
    printf '%s\n' "/opt/homebrew"
    ;;
esac
exit 0
EOF

  cat > "$bin_dir/open" << EOF
#!/usr/bin/env bash
printf '%s\n' "open \$*" >> "$log"
exit 0
EOF

  cat > "$bin_dir/curl" << EOF
#!/usr/bin/env bash
printf '%s\n' "curl \$*" >> "$log"
printf '%s\n' "curl must not be called during the sandboxed install" >&2
exit 1
EOF

  chmod +x "$bin_dir/xcode-select" "$bin_dir/brew" "$bin_dir/open" "$bin_dir/curl"
}

run_install() {
  local home="$1"
  local outfile="$2"
  local log="$3"
  local bin_dir="$4"
  local skip="${5:-}"
  local status

  if [[ "$skip" == "1" ]]; then
    set +e
    env DOTFILES_SKIP_BREW=1 HOME="$home" PATH="$bin_dir:/usr/bin:/bin" \
      bash "$ROOT/install.sh" >"$outfile" 2>&1
    status=$?
    set -e
  else
    set +e
    env -u DOTFILES_SKIP_BREW HOME="$home" PATH="$bin_dir:/usr/bin:/bin" \
      bash "$ROOT/install.sh" >"$outfile" 2>&1
    status=$?
    set -e
  fi

  if [[ "$status" -ne 0 ]]; then
    printf '---- install.sh output ----\n' >&2
    cat "$outfile" >&2
    printf '---- command log ----\n' >&2
    cat "$log" >&2
    fail "install.sh exited $status"
  fi
  pass
}

sandbox_checks() {
  local home bin_dir log out home_skip out_skip
  local backup_files before_files i count target

  # Global so the EXIT trap still sees the path after this function returns.
  TEST_TMP="$(mktemp -d)"

  home="$TEST_TMP/home"
  home_skip="$TEST_TMP/home-skip"
  bin_dir="$TEST_TMP/bin"
  log="$TEST_TMP/commands.log"
  out="$TEST_TMP/run.out"
  out_skip="$TEST_TMP/run-skip.out"
  mkdir -p "$home" "$home_skip" "$bin_dir"
  : > "$log"

  add_link "$ROOT/.zshrc" ".zshrc"
  add_link "$ROOT/.gitconfig" ".gitconfig"
  add_link "$ROOT/git/ignore" ".config/git/ignore"
  add_link "$ROOT/starship/starship.toml" ".config/starship.toml"
  add_link "$ROOT/ghostty/config" "Library/Application Support/com.mitchellh.ghostty/config"
  add_link "$ROOT/zed/settings.json" ".config/zed/settings.json"

  write_stubs "$bin_dir" "$log"

  # Existing real files are backed up, then every expected symlink is created.
  seed_real_files "$home"
  run_install "$home" "$out" "$log" "$bin_dir"
  assert_all_symlinks "$home"
  assert_backups "$home"
  assert_file_contains "$log" "xcode-select -p"
  assert_file_contains "$log" "brew shellenv"
  assert_file_contains "$log" "brew bundle --file $ROOT/Brewfile"
  assert_file_excludes "$log" "curl "
  count="$(link_count)"
  i=1
  while [[ "$i" -le "$count" ]]; do
    target="$home/$(nth_line "$i" "$TARGETS")"
    assert_file_contains "$out" "Linked $target ->"
    i=$((i + 1))
  done

  # Second run is idempotent: same symlinks, no extra backup, "Already linked".
  before_files="$(count_matching "$home/.dotfiles-backup" 1 999 f)"
  : > "$log"
  run_install "$home" "$out" "$log" "$bin_dir"
  assert_all_symlinks "$home"
  backup_files="$(count_matching "$home/.dotfiles-backup" 1 999 f)"
  assert_eq "$backup_files" "$before_files" "backup file count after re-run"
  assert_eq "$(count_matching "$home/.dotfiles-backup" 1 1 d)" "1" "backup dirs after re-run"
  assert_file_excludes "$out" "Moved existing"
  assert_file_excludes "$out" "Linked "
  i=1
  while [[ "$i" -le "$count" ]]; do
    target="$home/$(nth_line "$i" "$TARGETS")"
    assert_file_contains "$out" "Already linked: $target"
    i=$((i + 1))
  done

  # A symlink that points somewhere else is replaced, not backed up as a file.
  ln -sfn "/tmp/not-the-dotfiles-repo" "$home/.gitconfig"
  : > "$log"
  run_install "$home" "$out" "$log" "$bin_dir"
  assert_eq "$(readlink "$home/.gitconfig")" "$ROOT/.gitconfig" "relinked .gitconfig"
  assert_file_contains "$out" "Linked $home/.gitconfig ->"
  assert_eq "$(count_matching "$home/.dotfiles-backup" 1 999 f)" "$before_files" \
    "backup file count after relink"

  # DOTFILES_SKIP_BREW skips brew, still links, and does not require a backup.
  : > "$log"
  run_install "$home_skip" "$out_skip" "$log" "$bin_dir" "1"
  assert_all_symlinks "$home_skip"
  if [[ -d "$home_skip/.dotfiles-backup" ]]; then
    fail "skip-brew run created a backup for an empty home"
  fi
  pass
  assert_file_contains "$log" "xcode-select -p"
  assert_file_excludes "$log" "brew "
  assert_file_contains "$out_skip" "Skipping Homebrew steps"
}

static_checks
sandbox_checks

printf 'ok: %s checks\n' "$CHECKS"
