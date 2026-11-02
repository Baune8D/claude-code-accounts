#!/bin/sh
# Install the account-switching wrapper and the settings sync into ~/.local/claude-switch,
# and put the wrapper first on PATH via ~/.zshrc. Safe to re-run, e.g. after editing bin/claude.
set -e
REPO="$(cd "$(dirname "$0")" && pwd)"
PREFIX="$HOME/.local/claude-switch"

[ -x "$HOME/.local/bin/claude" ] || echo "warning: real claude not found at ~/.local/bin/claude (native installer location)" >&2

mkdir -p "$PREFIX/bin"
cp "$REPO/bin/claude" "$PREFIX/bin/claude"
cp "$REPO/bin/sync-settings" "$PREFIX/sync-settings"
chmod +x "$PREFIX/bin/claude" "$PREFIX/sync-settings"
echo "installed $PREFIX/bin/claude and $PREFIX/sync-settings"

LINE='export PATH="$HOME/.local/claude-switch/bin:$PATH"'
ZSHRC="$HOME/.zshrc"
if grep -qF "$LINE" "$ZSHRC" 2>/dev/null; then
  echo "PATH line already in $ZSHRC"
else
  printf '\n# Claude Code: wrapper that picks the account (config dir) by folder (claude-code-accounts).\n# Must stay first on PATH so IDEs (e.g. JetBrains Air) also resolve it from the shell environment.\n%s\n' "$LINE" >> "$ZSHRC"
  echo "added PATH line to $ZSHRC"
fi
echo "Open a new terminal, and restart your IDE, to pick it up."
