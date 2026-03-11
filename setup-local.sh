#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────
# GSD Local Dev Setup
# Symlinks a cloned get-shit-done repo into ~/.claude/
# so edits to the repo are instantly live.
# ──────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

info()  { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET} $1"; }
err()   { echo -e "  ${RED}✗${RESET} $1"; exit 1; }

# ── Uninstall mode (check first, before any install logic) ──

if [[ "${1:-}" == "--uninstall" ]]; then
  echo ""
  echo -e "  ${CYAN}GSD Local Dev Uninstall${RESET}"
  echo ""

  # Remove command symlink
  if [[ -L "$CLAUDE_DIR/commands/gsd" ]]; then
    rm "$CLAUDE_DIR/commands/gsd"
    info "Removed commands/gsd symlink"
  fi

  # Remove agent symlinks
  for agent in "$CLAUDE_DIR"/agents/gsd-*.md; do
    if [[ -L "$agent" ]]; then
      rm "$agent"
    fi
  done
  info "Removed gsd-*.md agent symlinks"

  # Remove core symlink
  if [[ -L "$CLAUDE_DIR/get-shit-done" ]]; then
    rm "$CLAUDE_DIR/get-shit-done"
    info "Removed get-shit-done symlink"
  fi

  # Remove hook symlinks
  for hook in "$CLAUDE_DIR"/hooks/gsd-*.js; do
    if [[ -L "$hook" ]]; then
      rm "$hook"
    fi
  done
  info "Removed hook symlinks"

  # Clean settings.json
  if [[ -f "$SETTINGS" ]]; then
    node -e "
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));

if (settings.statusLine && settings.statusLine.command &&
    settings.statusLine.command.includes('gsd-statusline')) {
  delete settings.statusLine;
}

if (settings.hooks) {
  ['SessionStart', 'PostToolUse'].forEach(event => {
    if (settings.hooks[event]) {
      settings.hooks[event] = settings.hooks[event].filter(e =>
        !(e.hooks && e.hooks.some(h => h.command &&
          (h.command.includes('gsd-check-update') || h.command.includes('gsd-context-monitor'))))
      );
      if (settings.hooks[event].length === 0) delete settings.hooks[event];
    }
  });
  if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
}

fs.writeFileSync(process.argv[1], JSON.stringify(settings, null, 2) + '\n');
" "$SETTINGS"
    info "Cleaned settings.json"
  fi

  echo ""
  echo -e "  ${GREEN}Uninstalled.${RESET} Your ~/.claude/ is clean of GSD."
  echo ""
  exit 0
fi

# ── Install mode ──────────────────────────────────────

echo ""
echo -e "  ${CYAN}GSD Local Dev Setup${RESET}"
echo -e "  Repo: ${REPO_DIR}"
echo -e "  Target: ${CLAUDE_DIR}"
echo ""

# ── Preflight ─────────────────────────────────────────

if [[ ! -f "$REPO_DIR/package.json" ]]; then
  err "Not a GSD repo — package.json not found in $REPO_DIR"
fi

mkdir -p "$CLAUDE_DIR"

# ── 1. Symlink commands ──────────────────────────────

# Claude Code reads commands from ~/.claude/commands/
mkdir -p "$CLAUDE_DIR/commands"

if [[ -L "$CLAUDE_DIR/commands/gsd" ]]; then
  rm "$CLAUDE_DIR/commands/gsd"
  info "Replaced existing gsd commands symlink"
elif [[ -d "$CLAUDE_DIR/commands/gsd" ]]; then
  warn "~/.claude/commands/gsd/ is a real directory (from npx install?)"
  echo -n "  Replace with symlink to repo? [y/N] "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -rf "$CLAUDE_DIR/commands/gsd"
  else
    err "Aborted — remove ~/.claude/commands/gsd/ manually first"
  fi
fi

ln -s "$REPO_DIR/commands/gsd" "$CLAUDE_DIR/commands/gsd"
info "Linked commands/gsd → repo"

# ── 2. Symlink agents ────────────────────────────────

# Claude Code reads agents from ~/.claude/agents/
if [[ -L "$CLAUDE_DIR/agents" ]]; then
  rm "$CLAUDE_DIR/agents"
elif [[ -d "$CLAUDE_DIR/agents" ]]; then
  # Might have non-GSD agents — only symlink GSD ones
  for agent in "$REPO_DIR"/agents/gsd-*.md; do
    name="$(basename "$agent")"
    if [[ -f "$CLAUDE_DIR/agents/$name" && ! -L "$CLAUDE_DIR/agents/$name" ]]; then
      rm "$CLAUDE_DIR/agents/$name"
    elif [[ -L "$CLAUDE_DIR/agents/$name" ]]; then
      rm "$CLAUDE_DIR/agents/$name"
    fi
    ln -s "$agent" "$CLAUDE_DIR/agents/$name"
  done
  info "Linked individual gsd-*.md agents → repo"
  # Skip the directory-level symlink since non-GSD agents exist
  AGENTS_DONE=true
fi

if [[ "${AGENTS_DONE:-}" != "true" ]]; then
  mkdir -p "$CLAUDE_DIR/agents"
  for agent in "$REPO_DIR"/agents/gsd-*.md; do
    name="$(basename "$agent")"
    ln -sf "$agent" "$CLAUDE_DIR/agents/$name"
  done
  info "Linked gsd-*.md agents → repo"
fi

# ── 3. Symlink core infrastructure ───────────────────

# Workflows, templates, references, bin — all under get-shit-done/
if [[ -L "$CLAUDE_DIR/get-shit-done" ]]; then
  rm "$CLAUDE_DIR/get-shit-done"
elif [[ -d "$CLAUDE_DIR/get-shit-done" ]]; then
  warn "~/.claude/get-shit-done/ is a real directory (from npx install?)"
  echo -n "  Replace with symlink to repo? [y/N] "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -rf "$CLAUDE_DIR/get-shit-done"
  else
    err "Aborted — remove ~/.claude/get-shit-done/ manually first"
  fi
fi

ln -s "$REPO_DIR/get-shit-done" "$CLAUDE_DIR/get-shit-done"
info "Linked get-shit-done/ → repo"

# ── 4. Symlink hooks ─────────────────────────────────

mkdir -p "$CLAUDE_DIR/hooks"

for hook in "$REPO_DIR"/hooks/gsd-*.js; do
  name="$(basename "$hook")"
  ln -sf "$hook" "$CLAUDE_DIR/hooks/$name"
done
info "Linked hooks → repo"

# ── 5. Configure settings.json ────────────────────────

# Read existing settings or start fresh
if [[ -f "$SETTINGS" ]]; then
  EXISTING=$(cat "$SETTINGS")
else
  EXISTING='{}'
fi

# Use node (available since Claude Code requires it) to merge settings
node -e "
const fs = require('fs');
const settings = JSON.parse(process.argv[1]);

// Statusline
const hooksDir = process.argv[2] + '/hooks';
settings.statusLine = {
  type: 'command',
  command: 'node \"' + hooksDir + '/gsd-statusline.js\"'
};

// Hooks
if (!settings.hooks) settings.hooks = {};

// SessionStart — update checker
if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [];
const hasUpdate = settings.hooks.SessionStart.some(e =>
  e.hooks && e.hooks.some(h => h.command && h.command.includes('gsd-check-update'))
);
if (!hasUpdate) {
  settings.hooks.SessionStart.push({
    hooks: [{ type: 'command', command: 'node \"' + hooksDir + '/gsd-check-update.js\"' }]
  });
}

// PostToolUse — context monitor
if (!settings.hooks.PostToolUse) settings.hooks.PostToolUse = [];
const hasContext = settings.hooks.PostToolUse.some(e =>
  e.hooks && e.hooks.some(h => h.command && h.command.includes('gsd-context-monitor'))
);
if (!hasContext) {
  settings.hooks.PostToolUse.push({
    hooks: [{ type: 'command', command: 'node \"' + hooksDir + '/gsd-context-monitor.js\"' }]
  });
}

fs.writeFileSync(process.argv[3], JSON.stringify(settings, null, 2) + '\n');
" "$EXISTING" "$CLAUDE_DIR" "$SETTINGS"

info "Updated settings.json (statusline + hooks)"

# ── 6. Write VERSION file ─────────────────────────────

VERSION=$(node -p "require('$REPO_DIR/package.json').version")
echo -n "$VERSION" > "$REPO_DIR/get-shit-done/VERSION"
info "Wrote VERSION ($VERSION)"

# ── 7. Ensure package.json for CommonJS ───────────────

if [[ ! -f "$CLAUDE_DIR/package.json" ]]; then
  echo '{"type":"commonjs"}' > "$CLAUDE_DIR/package.json"
  info "Created package.json (CommonJS mode)"
fi

# ── Done ──────────────────────────────────────────────

echo ""
echo -e "  ${GREEN}Done!${RESET} GSD is linked from your cloned repo."
echo ""
echo -e "  ${CYAN}How it works:${RESET}"
echo "  - Edit files in $REPO_DIR"
echo "  - Changes are instantly live (symlinks, no copy step)"
echo "  - Open any project in Claude Code and run /gsd:new-project"
echo ""
echo -e "  ${CYAN}To uninstall:${RESET} bash $REPO_DIR/setup-local.sh --uninstall"
echo ""
