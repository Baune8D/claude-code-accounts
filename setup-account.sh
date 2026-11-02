#!/bin/sh
# Create or re-align a Claude Code account config dir with the shared parts of ~/.claude.
#
#   ./setup-account.sh ~/.claude-<name>
#
# Idempotent. Also add the folder -> dir pair to ACCOUNTS in bin/claude and run ./install.sh,
# then start claude in that folder and /login with the account.
set -e
[ $# -eq 1 ] || { echo "usage: $0 <config-dir>" >&2; exit 1; }
REPO="$(cd "$(dirname "$0")" && pwd)"
BASE="$HOME/.claude"
CLAUDE="$HOME/.local/bin/claude"
mkdir -p "$1"
DIR="$(cd "$1" && pwd -P)"
[ "$DIR" = "$(cd "$BASE" && pwd -P)" ] && { echo "refusing to set up the base dir $BASE itself" >&2; exit 1; }

echo "== $DIR"

echo "-- links to shared files (CLAUDE.md, agents, ide lock files)"
for f in CLAUDE.md agents ide; do
  [ -e "$BASE/$f" ] || continue
  if [ -e "$DIR/$f" ] || [ -L "$DIR/$f" ]; then echo "   $f: exists"; else ln -s "$BASE/$f" "$DIR/$f"; echo "   $f: linked"; fi
done

echo "-- skills: own dir (claude.ai org skills sync into skills/synced per account), custom skills linked"
[ -L "$DIR/skills" ] && rm "$DIR/skills"   # an older setup linked the whole dir
mkdir -p "$DIR/skills"
for s in "$BASE"/skills/*/; do
  [ -d "$s" ] || continue
  name="$(basename "$s")"
  [ "$name" = synced ] && continue
  if [ -e "$DIR/skills/$name" ]; then echo "   $name: exists"; else ln -s "$BASE/skills/$name" "$DIR/skills/$name"; echo "   $name: linked"; fi
done

echo "-- settings.json (shared settings minus the EXCLUDE entries in bin/sync-settings)"
"$REPO/bin/sync-settings" "$DIR" | sed 's/^/   /'

echo "-- MCP servers, plugins, preferences"
python3 -I - "$DIR" "$CLAUDE" <<'EOF'
import json, os, subprocess, sys

acct, claude = sys.argv[1], sys.argv[2]
home = os.path.expanduser("~")
env = dict(os.environ, CLAUDE_CONFIG_DIR=acct)


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def run(*args):
    r = subprocess.run([claude, *args], env=env, capture_output=True, text=True)
    last = (r.stdout + r.stderr).strip().splitlines()[-1:] or [""]
    print(f"   [{'ok' if r.returncode == 0 else 'FAIL'}] {' '.join(args[:3])}: {last[0][:140]}")


base_global = load(f"{home}/.claude.json")

# User-scope MCP servers live in each account's .claude.json, so copy the missing ones.
have = load(f"{acct}/.claude.json").get("mcpServers", {})
for name, spec in base_global.get("mcpServers", {}).items():
    if name not in have:
        run("mcp", "add-json", "-s", "user", name, json.dumps(spec))

# Marketplaces and plugins enabled in the (already filtered) account settings.
settings = load(f"{acct}/settings.json")
known = load(f"{acct}/plugins/known_marketplaces.json")
# A fresh config dir only has the built-in directory; the official marketplace is added on the
# first interactive start, so add it up front when an enabled plugin needs it.
if "claude-plugins-official" not in known and any(
        p.endswith("@claude-plugins-official") for p, on in settings.get("enabledPlugins", {}).items() if on):
    run("plugin", "marketplace", "add", "anthropics/claude-plugins-official")
for name, m in settings.get("extraKnownMarketplaces", {}).items():
    src = m.get("source", {})
    ref = src.get("repo") or src.get("url") or src.get("path")
    if name not in known and ref:
        run("plugin", "marketplace", "add", ref)
installed = load(f"{acct}/plugins/installed_plugins.json")
installed = installed.get("plugins", installed)
for plugin, enabled in settings.get("enabledPlugins", {}).items():
    if enabled and plugin not in installed:
        run("plugin", "install", plugin, "-s", "user")

# Real user preferences kept in the global config rather than settings.json.
PREFS = ["claudeInChromeDefaultEnabled", "hasCompletedClaudeInChromeOnboarding", "showSpinnerTree",
         "diffSidebarOpen", "lspRecommendationNeverPlugins", "codeReviewLastEffort",
         "hasIdeOnboardingBeenShown", "autoModeEnvSetup"]
path = f"{acct}/.claude.json"
cfg = load(path)
copied = [k for k in PREFS if k in base_global and cfg.get(k) != base_global[k]]
if copied:
    for k in copied:
        cfg[k] = base_global[k]
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
print(f"   preferences copied: {copied or 'none needed'}")
EOF

echo "Done. Next: add '<folder> $DIR' to ACCOUNTS in bin/claude, run ./install.sh, then claude -> /login in that folder."
