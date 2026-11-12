---
name: azeroth-survivors-addon
description: Build WoW 1.12.1 addons for Azeroth Survivors (benilla). Use when creating, debugging, or extending AZS addons, checking whether a 1.12 API name exists in this client before calling it (globals, functions, widget methods, events, CVars, TOC directives, Lua 5.0 limits, library support), reading run state (clock, phase, bosses, guardians, hero, spells, buffs, timers, summons, totems, meters, debuffs, healing, boss/party damage, lairs, caches, banners, revive, downed allies, player position, local time, run end), using AZS meter/combat-text/world-anchor APIs, hiding the stock HUD, or handling AZS CHAT_MSG_ADDON messages.
---

# Azeroth Survivors Addon

Build World of Warcraft 1.12.1 addons for Azeroth Survivors (benilla / browser build).

Azeroth Survivors addons are stock 1.12 addons (`## Interface: 11200`, Lua + XML, stock frame API). The game exposes run state via `AZS_*` globals and helper functions, filled before addons load and kept current. Data covers the current run only — out of a run tables are empty or stale (and `AZS_END`/prior values may persist), so gate on `AZS_GetPhase()` / run state.

## Workflow

1. **Gate on run/phase first.** `AZS_GetPhase()` returns `ready | playing | choosing | paused | dead | victory`, or nil. Return early unless the phase fits. Never trust tables without this check.
2. **Prefer helpers over raw tables when available:** `AZS_GetRunTime()` (smooth clock), `AZS_GetBosses()`/`AZS_GetUpcomingBosses()`, `AZS_GetGuardians()`/`AZS_GetLairs()`/`AZS_GetFlaggedLair()`, `AZS_GetMeter()`/`AZS_GetHealing()`/`AZS_GetBossMeter()`/`AZS_GetPartyMeter()`, `AZS_GetDebuffs(id)`, `AZS_GetTimers([name])`, `AZS_GetSummons([which])`/`AZS_GetSummonGroups()`/`AZS_GetSummonCount()`, `AZS_GetTotems([key])`/`AZS_GetTotemCount()`, `AZS_GetRevive()`/`AZS_GetDownedPartyMembers()`, `AZS_GetPlayerPosition()`, `AZS_GetLocalTime()`, `AZS_GetRunSummary()`, `AZS_UnitKind(unit)`.
3. **React to changes via `CHAT_MSG_ADDON`** (tables are already updated when your handler runs), `AZS_RegisterBannerHandler(handler)` for banners, or poll in `OnUpdate`. Throttle `OnUpdate`; updates arrive at most 5x/sec and only on change. `AZSM` frames are for the meter API internals — use the meter API functions, not manual parsing.
4. **Hide HUD only for parts you replace**, only while enabled, and restore on disable/removal (settings persist in CVars). Keep custom frames over level-up/jewelry cards with `AZS_SetOnTopOfScreens(frame, true)` (and `GameTooltip` too if you show tooltips from them).
5. **Install/test:** Windows/Linux: `benilla-config/AddOns/<AddonName>/` next to exe, loads on next world entry. Browser: Options → AddOns → install `.zip`. `.toc` must have `## Interface: 11200`.

## Hard rules (1.12 + AZS quirks)

- Lua 1.12 only: `this, event, arg1...`, `table.getn`, `math.mod`, `string.find`. No `string.gmatch`, no GUID APIs.
- No `_G` table: look up and set globals with `getglobal`/`setglobal`, as in the original game.
- Spawn `id` is unique within a run but cannot be mapped from a unit token. Match enemies by `name` (+ target). Boss names are unique per zone.
- `names` are localized (same as `UnitName`); `zone / class / phase / kind / summon keys` etc. are stable keys — use keys for logic.
- Guardians: only `target` reports `guardian` via `AZS_UnitKind` / `AZS_TARGET.kind`; other units read as `elite`. Use `AZS_GetGuardians()` for the full list.
- Bosses: several can be alive at once, ordered by spawn. `AZS_GetUpcomingBosses()` is empty in endless mode — use `AZS_RUN.nb` / `AZS_RUN.nbn` instead.
- Meter numbers (legacy helpers) cover the whole run; the in-game Reset button affects only the stock window. For checkpoint/windowed/party/complete accounting use the **Meter API v1** in `references/api.md`.
- Read-only API: nothing changes the run except HUD visibility / HUD-related toggles exposed by the API.
- Raw numbers arrive as Lua numbers, flags as `0`/`1`. Many tables have a matching `*_UPDATED` global with `GetTime()` of last change.

## Field gotchas

- Count guardian kills with `AZS_RUN.gk`: "is slain! Its lair yields treasure" is engine text, never an addon message.
- `AZS_SetHudShown` writes saved settings: an addon that hides a part and is removed leaves it hidden until the player re-enables it. Restore what you hid. `AZS_IsHudShown` reports the setting, not on-screen visibility in all cases (e.g. `localClock` still hides with minimap).
- Probe a custom font on a hidden FontString before use — a failed load renders blank text. Fall back to `Fonts\\FRIZQT__.TTF`.
- A saved frame position is in that frame's own scale units: after a scale change, convert saved coordinates or clamp to screen.
- `AZS_ZONE` is sent once per run: after mid-run `/reload` it can be empty. Fall back to `GetRealZoneText()` plus `AZS_RUN.fin` for zone facts.
- Phase can report `playing` while the level-up picker is up — detect choices with `AZS_RUN.owed > 0`. Bar slots 1–6 mirror `AZS_SPELLS` order (racial last = slot 12); `GetActionCooldown` is not wired. Card/deck model: `references/card-system.md`.
- Stored level-ups: count via `AZS_RUN.sl` / `AZS_GetStoredLevels()`, open with `AZS_OpenStoredLevels()`, read/set storing with `AZS_IsStoringLevels()` / `AZS_SetStoringLevels(on)`. Stock button part is `levels`.
- `AZS_GetPlayerPosition()` gives per-frame client-rendered position/facing/spaceId (use for projections/distances every frame). `AZS_RUN.px/py/pz/pf` are server-reported movement snapshots (~2/sec while running). Match chest/lair/downed/world-anchor spaces by `spaceId` (and map/run context).
- `AZS_GetLocalTime()` may be nil on first frame after `/reload` or temporarily; check it exists on older clients before relying on `localClock` HUD handling. Format follows game language, not device locale.
- `AZS_GetDownedPartyMembers()` and meter/loadout APIs can return `nil, err` with retryable errors (`NOT_READY`, `NO_WORLD`, etc.); handle `err.code`/`retryable` instead of assuming success.

## Using `references/client-api.md`

It is a lookup, not something to read end to end. To answer "can I call X":

1. Grep the file for `X`. Found under **API globals**, **Functions**, **Events**
   or **CVars** → it exists.
2. Found under the **missing** list in Globals → it is `nil`. Do not call it.
3. Not found at all → treat it as absent and feature-detect
   (`if (X) then ... end`) rather than assuming either way.

**A listed name does not promise a working feature.** This is a partial 1.12
implementation; a name can exist and still be a stub. The `debug*` family is the
standing example: `debuginfo` and friends exist and do nothing.

When the client is updated, its addon surface changes and this reference goes
stale. Re-derive it before trusting it: the client ships `scripts/api-coverage.sh`,
which asks its own VM what it exposes and diffs that against
`reference/lua_globals.tsv`; `cargo run -p benilla-ui --example dump_globals`
prints the live globals and `--example dump_widget_methods` the per-template
widget methods. Both are in the client's repo, not here.

## API quick map

Full, current field lists and contracts: `references/api.md` (mirrors upstream docs as of 2 Nov 2026). Client-wide 1.12 surface: `references/client-api.md`. Card/deck internals: `references/card-system.md`.

**Core functions:** `AZS_GetRunTime()`, `AZS_GetPhase()`, `AZS_GetRunLength()`, `AZS_GetBosses()`, `AZS_GetUpcomingBosses()`, `AZS_GetGuardians()`, `AZS_GetDebuffs(id)`, `AZS_GetMeter()`, `AZS_GetHealing()`, `AZS_GetBossMeter()`, `AZS_GetPartyMeter()`, `AZS_GetTimers([name])`, `AZS_GetRevive()`, `AZS_GetDownedPartyMembers()`, `AZS_GetLairs()`, `AZS_GetFlaggedLair()`, `AZS_GetPlayerPosition()`, `AZS_GetRunSummary()`, `AZS_GetStoredLevels()`, `AZS_OpenStoredLevels()`, `AZS_IsStoringLevels()` / `AZS_SetStoringLevels(on)`, `AZS_RegisterBannerHandler(handler)` / `AZS_UnregisterBannerHandler(handler)`, `AZS_GetSummons([which])` / `AZS_GetSummonCount([which])` / `AZS_GetSummonGroups()`, `AZS_GetTotems([key])` / `AZS_GetTotemCount([key])`, `AZS_UnitKind(unit)`, `AZS_SetHudShown(part, shown)` / `AZS_IsHudShown(part)`, `AZS_SetOnTopOfScreens(frame, on)` / `AZS_IsOnTopOfScreens(frame)`, `AZS_GetLocalTime()`.

**Core tables:** `AZS_ZONE`, `AZS_RUN`, `AZS_SCHEDULE`, `AZS_UNITS`, `AZS_DEBUFFS`, `AZS_TARGET`, `AZS_SPELLS`, `AZS_TIMERS`, `AZS_BUFFS`, `AZS_PETS`, `AZS_TOTEMS`, `AZS_METER`, `AZS_HEALING`, `AZS_BOSSMETER`, `AZS_PARTY`, `AZS_REVIVE`, `AZS_DOWNED`, `AZS_CHESTS`, `AZS_LAIRS`, `AZS_TAKEN`, `AZS_END`, `AZS_BANNERS`/`AZS_BANNER`, `AZS_STATS`.

**Advanced APIs (see `references/api.md` for full contracts):**
- **Meter API v1:** `AZS_GetMeterCapabilities`, `AZS_GetMeterContext`, `AZS_GetMeterSnapshot`, `AZS_GetMeterLoadout`, `AZS_CreateMeterCheckpoint`, `AZS_ReleaseMeterCheckpoint`, `AZS_SetMeterPortrait` (structured results + `nil, err` with retryable/error codes).
- **World-anchored combat text v1:** `AZS_GetCombatTextCapabilities`, `AZS_GetCombatTextEvents`, `AZS_ProjectCombatTextAnchors`, `AZS_RegisterCombatTextFrameHandler` / `AZS_UnregisterCombatTextFrameHandler`.
- **World anchors v1:** `AZS_GetWorldAnchorCapabilities`, `AZS_GetWorldAnchors`, `AZS_ProjectWorldAnchors`, `AZS_RegisterWorldAnchorFrameHandler` / `AZS_UnregisterWorldAnchorFrameHandler`.

**HUD parts:** `clock, bosses, tally, build, banners, loot, meter, levels, flag, revive, localClock`, plus `all`/nil. CVar equivalents e.g. `hudClock`..`hudLocalClock` (`"1"` shown / `"0"` hidden). Saved; some parts (`levels, flag, revive`) have no Options checkbox.

**Addon prefixes (`arg1`) → table/state:** `AZSZONE→AZS_ZONE`, `AZSRUN→AZS_RUN`, `AZSBOSSES→AZS_SCHEDULE`, `AZSUNITS→AZS_UNITS`, `AZSDEBUFFS→AZS_DEBUFFS`, `AZSTGT→AZS_TARGET`, `AZSSPELLS→AZS_SPELLS`, `AZSTIMERS→AZS_TIMERS`, `AZSREVIVE→AZS_REVIVE`, `AZSDOWNED→AZS_DOWNED`, `AZSBUFFS→AZS_BUFFS`, `AZSPETS→AZS_PETS`, `AZSTOTEMS→AZS_TOTEMS`, `AZSMETER→AZS_METER`, `AZSHEAL→AZS_HEALING`, `AZSBOSSDMG→AZS_BOSSMETER`, `AZSPARTY→AZS_PARTY`, `AZSCHESTS→AZS_CHESTS`, `AZSLAIRS→AZS_LAIRS`, `AZSTAKEN→AZS_TAKEN`, `AZS→AZS_STATS`, `AZSEND→AZS_END`, `AZSBANNER→AZS_BANNERS/AZS_BANNER`. `AZSM` is meter-API stream (use API functions). Most are `key=value;` or `a,b,c;` entries; `AZSBANNER` text is last/whole and may contain separators.

**Keys:** zones `elwynn, duskwood, wsg, ab, feralas, arena, av, brm, aq`; classes `warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid`; phases `ready, playing, choosing, paused, dead, victory`; kinds `final, boss, guardian, elite, normal`. Refer to `references/api.md` for Heroic affixes (`bolstering, sanguine, explosive`) and other domain-specific keys.

**Card system:** the game's choice cards (spell/ring/trinket/amulet kinds, `why` texts, rarity-rolled upgrades, class ability pools) are documented in `references/card-system.md`, reverse-engineered from the client. The addon channel never carries the offered cards — predict the deck client-side.

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

## Minimap button (menu entry)

Parent a `Button` to `Minimap`, park it by angle, drag to move, persist the
angle in `SavedVariables`, tooltip + click menu included:

```lua
local btn = CreateFrame("Button", "MyAddonMinimapButton", Minimap);
btn:SetWidth(31); btn:SetHeight(31);
local icon = btn:CreateTexture(nil, "BACKGROUND");
icon:SetWidth(20); icon:SetHeight(20);
icon:SetPoint("CENTER", btn, "CENTER", 0, 0);
icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
local border = btn:CreateTexture(nil, "OVERLAY");
border:SetWidth(53); border:SetHeight(53);
border:SetPoint("CENTER", btn, "CENTER", 0, 0);
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");

local function place()
  local a = MyDB.mmAngle or (math.pi * 1.1);
  btn:ClearAllPoints();
  btn:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a));
end
place();

btn:RegisterForDrag("LeftButton");
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp");
btn:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", function() -- runs while held
    local mx, my = Minimap:GetCenter();
    local px, py = GetCursorPosition();
    local s = UIParent:GetScale();
    MyDB.mmAngle = math.atan2(py / s - my, px / s - mx);
    place();
  end);
end);
btn:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil); end);
btn:SetScript("OnClick", function()
  if ( arg1 == "RightButton" ) then ToggleMyMenu(); else ToggleMyAddon(); end
end);
btn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT");
  GameTooltip:SetText("My Addon");
  GameTooltip:AddLine("Left-click: on/off", 1, 1, 1);
  GameTooltip:AddLine("Right-click: menu", 1, 1, 1);
  GameTooltip:Show();
end);
btn:SetScript("OnLeave", function() GameTooltip:Hide(); end);
```

Notes: a drag ending on the button also fires `OnClick`, so guard it with a
`dragged` flag (set in the `OnUpdate`, consumed in `OnClick`). Keep the button
at `MEDIUM` strata like the stock minimap buttons; popups/menus go `DIALOG`.
Radius 80 assumes the stock round minimap; if a square minimap is in play,
clamp the position to ride outside its border instead.
