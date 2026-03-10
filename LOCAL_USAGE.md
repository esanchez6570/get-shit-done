# Local Usage (Cloned Repo)

Use this when you've cloned get-shit-done to customize it rather than installing from npm.

## Quick Start

```bash
git clone <your-fork-url> ~/code/get-shit-done
cd ~/code/get-shit-done
bash setup-local.sh
```

That's it. Open any project in Claude Code and run `/gsd:new-project`.

## What the Setup Script Does

`setup-local.sh` creates **symlinks** from `~/.claude/` to your cloned repo:

```
~/.claude/
├── commands/gsd → <repo>/commands/gsd/       (32 slash commands)
├── agents/gsd-*.md → <repo>/agents/gsd-*.md  (12 agents)
├── get-shit-done → <repo>/get-shit-done/     (workflows, templates, bin)
├── hooks/gsd-*.js → <repo>/hooks/gsd-*.js    (3 hooks)
├── settings.json                              (updated with GSD hooks)
└── package.json                               (CommonJS mode)
```

Because everything is symlinked, **edits to the repo are instantly live** — no reinstall, no copy step.

## Prerequisites

- **Node.js** >= 16.7 (any version Claude Code supports)
- **Claude Code** installed and working
- **git** (for cloning and GSD's atomic commits)

No `npm install` needed — GSD has zero runtime dependencies. All tooling is vanilla Node.js using only built-in modules (`fs`, `path`, `child_process`).

## Updating

Since you're working from a clone:

```bash
cd ~/code/get-shit-done
git pull        # if tracking upstream
# Your symlinks still point here — changes are live immediately
```

If you've forked and want upstream updates:

```bash
git remote add upstream https://github.com/nicholmikey/get-shit-done.git
git fetch upstream
git merge upstream/main
```

## Uninstalling

```bash
bash ~/code/get-shit-done/setup-local.sh --uninstall
```

This removes all symlinks and cleans GSD entries from `~/.claude/settings.json`. Your existing non-GSD settings are preserved.

## Switching Between Local and npm

If you previously installed via `npx get-shit-done-cc`, the setup script will detect the existing directories and ask before replacing them. To go back to the npm version:

```bash
bash setup-local.sh --uninstall
npx get-shit-done-cc
```

## Customizing

The whole point of cloning is to customize. Key files:

| What | Where | Purpose |
|------|-------|---------|
| Slash commands | `commands/gsd/*.md` | What users invoke (`/gsd:plan-phase`, etc.) |
| Agents | `agents/gsd-*.md` | Specialized agents (planner, executor, checker, etc.) |
| Workflows | `get-shit-done/workflows/*.md` | Multi-step workflow implementations |
| Templates | `get-shit-done/templates/*.md` | PLAN.md, SUMMARY.md, PROJECT.md scaffolds |
| References | `get-shit-done/references/*.md` | Supporting docs (TDD patterns, verification, etc.) |
| CLI tools | `get-shit-done/bin/gsd-tools.cjs` | State management, config, git operations |
| Hooks | `hooks/gsd-*.js` | Statusline, update checker, context monitor |

Edit any of these and the changes take effect on the next Claude Code command invocation.

## Troubleshooting

**Commands not showing up in Claude Code?**
- Verify symlinks: `ls -la ~/.claude/commands/gsd`
- Should point to your repo's `commands/gsd/` directory
- Restart Claude Code if commands were just added

**"gsd-tools.cjs not found" errors?**
- Verify: `ls -la ~/.claude/get-shit-done/bin/gsd-tools.cjs`
- Should point to your repo's `get-shit-done/bin/gsd-tools.cjs`

**Hooks not running?**
- Check: `cat ~/.claude/settings.json | grep gsd`
- Re-run `bash setup-local.sh` to re-register hooks
