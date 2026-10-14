---
name: azeroth-survivors-addon
description: Build WoW 1.12.1 addons for Azeroth Survivors (benilla). Use when creating, debugging, or extending AZS addons, reading run state (clock, phase, bosses, guardians, hero, spells, buffs, meter), hiding the stock HUD, or handling AZS CHAT_MSG_ADDON messages.
---

# Azeroth Survivors Addon

Build World of Warcraft 1.12.1 addons for Azeroth Survivors (benilla / browser build).

Azeroth Survivors addons are stock 1.12 addons (`## Interface: 11200`, Lua + XML, stock frame API). The game exposes run state via `AZS_*` globals, filled before addons load and kept current. Data covers the current run only — out of a run tables are empty or stale.

## Workflow

1. **Gate on phase first.** `AZS_GetPhase()` returns `ready | playing | choosing | paused | dead | victory`, or nil. Return early unless the phase fits. Never trust tables without this check.
2. **Read state via functions, not raw tables where a helper exists:**
   - smooth clock: `AZS_GetRunTime()` (not `AZS_RUN.t`)
   - bosses alive: `AZS_GetBosses()`; bosses to come: `AZS_GetUpcomingBosses()`
   - guardians alive: `AZS_GetGuardians()`; meter: `AZS_GetMeter()`
   - enemy kind: `AZS_UnitKind("target")`
3. **React to changes via `CHAT_MSG_ADDON`** (tables are already updated when your handler runs) or poll in `OnUpdate`. Throttle `OnUpdate` with an elapsed accumulator; updates arrive max 5x/sec and only on change.
4. **Hide HUD only for parts you replace**, only while enabled. Restore on disable.
5. **Install/test:** Windows/Linux: `benilla-config/AddOns/<AddonName>/` next to exe, loads on next world entry. Browser: Options → AddOns → install `.zip`. `.toc` must have `## Interface: 11200`.

## Hard rules (1.12 + AZS quirks)

- Lua 1.12 only: `this, event, arg1...`, `table.getn`, `math.mod`, `string.find`. No `string.gmatch`, no GUID APIs.
- Spawn `id` is unique within a run but cannot be mapped from a unit token. Match enemies by `name` (+ target). Boss names are unique per zone.
- `names` are localized (same as `UnitName`); `zone / class / phase / kind` keys are NOT localized — use keys for logic.
- Guardians: only `target` reports `guardian` via `AZS_UnitKind` / `AZS_TARGET.kind`; other units read as `elite`. Use `AZS_GetGuardians()` for the full list by id+name.
- Bosses: several can be alive at once, ordered by spawn. `AZS_GetUpcomingBosses()` is empty in endless mode — use `AZS_RUN.nb` / `AZS_RUN.nbn` instead.
- Meter numbers cover the whole run; the in-game Reset button affects only the stock window.
- Read-only API: nothing changes the run except HUD visibility.
- Raw numbers arrive as Lua numbers, flags as `0`/`1`. Each table has a `*_UPDATED` global with `GetTime()` of last change.

## API quick map

Full field lists: see `references/api.md` (mirrors `addon_docs.md`).

**Functions:** `AZS_GetRunTime()`, `AZS_GetPhase()`, `AZS_GetRunLength()`, `AZS_GetBosses()`, `AZS_GetUpcomingBosses()`, `AZS_GetGuardians()`, `AZS_GetMeter()`, `AZS_UnitKind(unit)`, `AZS_SetHudShown(part, shown)` / `AZS_IsHudShown(part)`.

**Tables:** `AZS_ZONE` (fixed facts, once per run), `AZS_RUN` (live run), `AZS_SCHEDULE` (`{index,at,name,final,state}`), `AZS_UNITS` (`{kind,id,name,hp,hpm,state}`, max 40), `AZS_TARGET`, `AZS_SPELLS` (`{key,spell,rank,cd,cdmax}`), `AZS_BUFFS` (`{spell,left}`), `AZS_METER`, `AZS_TAKEN` (`{source,dmg}`), `AZS_STATS`.

**HUD parts:** `clock, bosses, tally, build, banners, loot, meter`, plus `all`/nil. CVar equivalents: `hudClock` etc. (`"1"` shown / `"0"` hidden). Same as Options → Interface checkboxes; saved.

**Addon prefixes (`arg1`) → table:** `AZSZONE→AZS_ZONE`, `AZSRUN→AZS_RUN`, `AZSBOSSES→AZS_SCHEDULE`, `AZSUNITS→AZS_UNITS`, `AZSTGT→AZS_TARGET`, `AZSSPELLS→AZS_SPELLS`, `AZSBUFFS→AZS_BUFFS`, `AZSMETER→AZS_METER`, `AZSTAKEN→AZS_TAKEN`, `AZS→AZS_STATS`. `key=value;` format for ZONE/RUN/TGT/STATS, `a,b,c;` entries for lists. Names never contain `;,=`.

**Keys:** zones `elwynn, duskwood, wsg, ab, feralas, arena, av, brm, aq`; classes `warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid`; phases `ready, playing, choosing, paused, dead, victory`; kinds `final, boss, guardian, elite, normal`.

## Minimal patterns

```lua
-- .toc:
-- ## Interface: 11200
-- ## Title: My AZS Addon
-- MyAddon.lua
```

```lua
-- smooth gated poll
local f = CreateFrame("Frame");
local elapsed = 0;
f:SetScript("OnUpdate", function()
  elapsed = elapsed + arg1;
  if ( elapsed < 0.25 ) then return; end
  elapsed = 0;
  if ( AZS_GetPhase() ~= "playing" ) then return; end
  local t = AZS_GetRunTime();
end);
```

```lua
-- react to change
local f = CreateFrame("Frame");
f:RegisterEvent("CHAT_MSG_ADDON");
f:SetScript("OnEvent", function()
  if ( arg1 == "AZSUNITS" ) then
    -- AZS_UNITS already updated
  end
end);
```

```lua
AZS_SetHudShown("meter", false); -- hide one; "all"/nil for all
AZS_SetHudShown("clock", true);  -- restore
```
