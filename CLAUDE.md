# claude-code-accounts

Per-folder Claude Code account switching on macOS. One config directory per account (`CLAUDE_CONFIG_DIR`), picked by a wrapper from the working directory, so it also works in IDEs that start `claude` without a shell, such as JetBrains Air.

- `bin/claude`: the wrapper. It maps the working directory (`pwd -P`) to a config dir through its `ACCOUNTS` list, exports `CLAUDE_CONFIG_DIR` unless one is set, re-syncs settings when needed, links the account's project dirs into `~/.claude/projects` for JetBrains Air, and `exec`s the real `~/.local/bin/claude`. POSIX `sh`.
- `bin/sync-settings`: Python. Builds an account's `settings.json` from `~/.claude/settings.json` (deep merge, base wins) minus the `EXCLUDE` patterns.
- `install.sh` copies both to `~/.local/claude-switch` and adds the `PATH` line to `~/.zshrc`. `setup-account.sh` creates or re-aligns an account dir. Both are idempotent.
- The README documents what is shared and what is per account, and the gotchas. Keep it in step with the scripts.

## Workflow

- Conventional commits (`feat:`, `fix:`, `chore(deps):`, `ci:`, `build:`, `docs:`), one commit per concern, directly on `main`.
- Only push, tag, publish or edit GitHub releases when asked.
- Commit messages must be accurate. If one turns out to be wrong before it is pushed, reword it (replay the commits and check that the tree is unchanged). Never rewrite pushed history.

## Dependencies

- Dependabot updates the GitHub Actions weekly on Monday with a 7-day cooldown, in one grouped pull request.

## Testing

- CI runs `shellcheck install.sh setup-account.sh bin/claude` and `python3 -m py_compile bin/sync-settings`. Run both before committing.
- There are no automated tests. The scripts change `~/.zshrc`, `~/.local/claude-switch` and account dirs, so try changes against a scratch `HOME` (e.g. `HOME=$(mktemp -d) sh install.sh`) rather than the real one.
- Keep the shell scripts POSIX `sh`: `bin/claude` runs before any shell setup, including from IDEs.
