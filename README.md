# Azeroth Survivors Addon Skill

<div align="center">

<a href="https://ko-fi.com/hejash"><img alt="Ko-fi" src="https://img.shields.io/badge/Ko--fi-hejash-ff5e5b?logo=kofi&logoColor=white"></a>
<a href="https://buymeacoffee.com/hejash"><img alt="Buy Me a Coffee" src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-hejash-ffdd00?logo=buymeacoffee&logoColor=black"></a>

</div>

An [Agent Skills](https://agentskills.io)-compatible skill for building World of
Warcraft 1.12.1 addons for **Azeroth Survivors** (benilla / browser build).

It teaches any compatible coding agent how to read run state via the `AZS_*`
globals (clock, phase, bosses, guardians, hero, spells, buffs, damage meter),
hide the stock HUD to draw a custom one, and handle the raw `CHAT_MSG_ADDON`
messages — while respecting 1.12 Lua constraints and AZS quirks (phase-gating,
smooth clock, guardian-on-target-only, localized names vs. stable keys, etc.).

## What's inside

- `azeroth-survivors-addon/SKILL.md` — the skill (workflow, hard rules, API quick
  map, minimal Lua patterns). This is the canonical source; edit this file.
- `azeroth-survivors-addon/references/api.md` — full API reference (mirrors
  `addon_docs.md`): every function, table, field, HUD part, addon prefix, and
  example.
- `addon_docs.md` — the original API document the skill was built from.
- `install-skill.ps1` / `install-skill.sh` — install the skill to every known
  agent location on your machine.

## Compatibility

One format works everywhere because all of these agents read the open
`SKILL.md` (`name` + `description`) layout:

| Agent | Global install dir | Project install dir |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.codex/skills/` | `.codex/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.opencode/skills/`, `.agents/skills/` |
| Crush | `~/.config/crush/skills/` | `.agents/skills/`, `.crush/skills/` |
| Shared / other agents | `~/.agents/skills/`, `~/.config/agents/skills/` | `.agents/skills/` |

Crush additionally reads `~/.claude/skills/` and `%LOCALAPPDATA%\…` variants on
Windows; OpenCode additionally reads `~/.claude/skills/` and
`~/.agents/skills/`. Installing to all of them (see below) is the safe move.

## Install

Default:

```sh
# project-level: installs to .agents/skills/ (seen by OpenCode, Crush, and 15+ more)
npx skills@latest add HejAsh/azeroth-survivors-addon-skill

# global (your user account, all projects)
npx skills@latest add HejAsh/azeroth-survivors-addon-skill -g

# preview without installing
npx skills@latest add HejAsh/azeroth-survivors-addon-skill -l
```

Use the `@latest` pin to dodge the npx cache. Restore the same skills on another
machine or in CI with `npx skills experimental_install`.

### Fallback — scripts

From this folder:

```powershell
# Windows
.\install-skill.ps1
```

```sh
# macOS / Linux / Git Bash
sh install-skill.sh
```

This copies `azeroth-survivors-addon/` to every global location above plus the
project-local `./.agents/skills/azeroth-survivors-addon/` fallback.

## Use it

Ask your agent to build, debug, or extend an Azeroth Survivors addon, e.g.:

- "Using the azeroth-survivors-addon skill, build a boss timer bar addon"
- "Debug my AZS damage meter — it shows stale data out of a run"
- "Replace the stock HUD meter with my own"

The skill triggers on: creating/debugging AZS addons, reading run state
(clock, phase, bosses, guardians, hero, spells, buffs, meter), hiding the stock
HUD, or handling `AZS CHAT_MSG_ADDON` messages.

## Updating

Edit the canonical copy only: `azeroth-survivors-addon/SKILL.md`
(`references/api.md` follows `addon_docs.md`). Then re-run the install script so
the global/project copies don't go stale.
