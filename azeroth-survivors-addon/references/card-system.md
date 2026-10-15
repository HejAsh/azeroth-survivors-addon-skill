# Azeroth Survivors: the card system (reverse-engineered)

How the game builds and shows choice cards, learned from the shipped client.
Use it to align addon advice with what the game actually offers.

## Target and method

- Target: `C:\Games\AzerothSurvivors\AzerothSurvivors.exe`, PE x86_64,
  130,624,512 bytes, SHA-256
  `67f1b30f61304128a274507446493d8f9340c51b737718bcc2903f7bc58ebddf`.
- The client is a custom engine, not the stock 1.12 binary: Rust
  (`crates\wenilla-rogue\src\game\*.rs`, `crates\wenilla-rogue-app\src\screens\*.rs`)
  on Bevy 0.18 (bevy_ecs / bevy_ui / bevy_asset), with a Lua VM
  (`crates\benilla-ui\src\script\*`) providing the 1.12 addon API. Game UI is
  native Bevy; only the addon layer is Lua.
- Method: the binary embeds its string data in plaintext, so a static
  ASCII/UTF-8 scan (no decompiler — Ghidra/IDA were unavailable on the analysis
  machine) recovers the card model, texts and data tables at file offsets.
  Offsets below are file offsets into that exact SHA-256.

## The card model

Every offer is one of four kinds (strings at `0x58dbdd0` and `0x58e0000` region):

| kind | offered when | footer ("why") |
|---|---|---|
| spell (`abilities`) | level up | `Improves a spell you know` (rank-up) or `New spell` + `Takes a spell slot · {n}/{max}` |
| ring | guardian lair / cache | `Upgrades a ring you wear` / `Takes a ring slot · {n}/{max}` |
| trinket | guardian lair / cache | `Upgrades a trinket you wear` / `Takes a trinket slot · {n}/{max}` |
| amulet | guardian lair / cache | `Empowers your amulet` / `Takes the amulet slot` |

Observed fields of a card (Rust-side keys, `0x58dbdd0` + `0x66d46c8` region):
`title`, `text`/`lines`, `icon`, `kind`, `rarity`/`rarityName`, `rank`,
`replaces` (+`replacesText/Icon/Rarity/Rank`), `new` (NEW badge), `why`,
`worn` ("WORN NOW" / "Lost if you take this one" on jewelry), and the screen
state: `choices`, `whylevelup` (level-up vs `GUARDIAN SLAIN — Its Hoard!` vs
`BATTLEGROUND CACHE — Treasure!`), `rerolls`, `rerollCost`, `banishes`,
`skip`, `skipGold`.

Behavior learned from the strings:

- "Choose a spell. Its rarity decides how strong it is." — a card's rarity
  rolls the strength of its upgrade text (`-7% cooldown`, `+12% area`, …), so
  two cards for the same spell can differ in value.
- Rank-ups are always for spells you own (`Improves a spell you know`); the
  card shows `Rank {from} » {to}`. When every owned spell is capped the game
  shows `Nothing left to learn`.
- New spells consume a slot; the SPELLS bar shows the count (`5/6`, max
  observed 6).
- Jewelry cards compare against worn gear: `Replaces {name}`, `WORN NOW`,
  `Lost if you take this one`.
- Legendary amulets are per class, one per spell: "LEGENDARY AMULETS · EACH
  CLASS ITS OWN, ONE FOR EVERY SPELL" (`0x58fdb00` region), e.g. Eye of the
  Splitting Sky, Stormcaller's Amulet. An amulet "remakes {spell}".
- Codex tracks what a run has offered ("SEEN UP TO {rarity}", "A NEW ONE, BY
  RARITY").
- Reroll: "Second Thoughts" talent gives free rerolls ("One more free reroll
  every run…"); beyond that rerolls cost gold (`Reroll ({cost} gold)`).
  Banish: "Once a run, banish a card: it never comes up again that run, and
  the hand is dealt again." (1–3 uses by talents). Skip grants gold
  (`Skip (+{skip_gold} gold)`).
- "Picked again, it grows by nearly the pick's whole worth every time." —
  repeated picks of the same upgrade keep most of their value.

## Class ability pools (the new-spell deck)

Plaintext table at `0x66c6800`–`0x66c8000`: per class, color, icon and the
complete ability key list. These keys match `AZS_SPELLS.key` and
`AZS_UnitKind`-style stable keys (lowercase, underscored):

- **warrior** `#C79C6E` INV_Sword_27: cleave, whirlwind, thunder_clap,
  mortal_strike, execute, demo_shout, battle_shout, bloodthirst, rend,
  shield_slam, bloodrage
- **paladin** `#F58CBA` Spell_Holy_HolyBolt: consecration, exorcism,
  hammer_of_wrath, holy_shock, holy_wrath, judgement, hammer_of_justice,
  holy_light, divine_shield, holy_shield, redemption
- **hunter** `#ABD473` INV_Weapon_Bow_07: auto_shot, arcane_shot, multi_shot,
  serpent_sting, volley, explosive_trap, concussive_shot, aimed_shot,
  immolation_trap, frost_trap, hunters_mark
- **rogue** `#FFF569` INV_ThrowingKnife_04: sinister_strike, eviscerate,
  blade_flurry, rupture, kidney_shot, gouge, ghostly_strike,
  adrenaline_rush, backstab, slice_and_dice, seal_fate
- **priest** `#FFFFFF` INV_Staff_30: smite, sw_pain, mind_blast, holy_nova,
  pw_shield, renew, holy_fire, mind_flay, psychic_scream, devouring_plague
- **shaman** `#0070DE` Spell_Nature_BloodLust: lightning_bolt,
  chain_lightning, earth_shock, flame_shock, frost_shock, lightning_shield,
  magma_totem, searing_totem, fire_nova, healing_wave, call_of_flame
- **mage** `#69CCF0` INV_Staff_13: fireball, frostbolt, arcane_missiles,
  frost_nova, arcane_explosion, blizzard, flamestrike, fire_blast,
  cone_of_cold, blast_wave, pyroblast, ice_barrier, polymorph
- **warlock** `#9482C9` Spell_Nature_FaerieFire: shadow_bolt, corruption,
  immolate, curse_of_agony, rain_of_fire, hellfire, death_coil, searing_pain,
  drain_life, fear, soul_fire
- **druid** `#FF7D0A` Ability_Druid_Maul: wrath, moonfire, starfire,
  hurricane, insect_swarm, entangling_roots, rejuvenation, regrowth, thorns,
  swipe, faerie_fire

The racial is not in these pools (it is granted, not offered); the last
`AZS_SPELLS` entry stays the racial and is excluded from predictions.

## What reaches addons

The addon channel carries only the ten documented prefixes (`AZSZONE`,
`AZSRUN`, `AZSBOSSES`, `AZSUNITS`, `AZSTGT`, `AZSSPELLS`, `AZSBUFFS`,
`AZSMETER`, `AZSTAKEN`, `AZS`) — a full prefix scan of the exe found no
card/offer prefix. The offered cards never leave the native UI, so an addon
can predict the deck but never see the hand. The same holds for engine
announcements: the guardian toast ("is slain! Its lair yields treasure") is
native text, not an addon message — count guardian kills from `AZS_RUN.gk`.

## Prediction model an addon can support

- **Rank-up candidates**: owned, non-racial spells — every one below its cap
  will be offered again (`Improves a spell you know`). Prioritize by live
  damage share.
- **New-spell candidates**: `CLASS_POOLS[class]` minus owned spells; offered
  while spell slots remain (`Takes a spell slot · {n}/{max}`). An addon can
  report the remaining pool and slot usage.
- **Cap**: when pool minus owned is empty → `Nothing left to learn`.

## Unknowns (not recoverable without a decompiler)

- Exact rarity odds and how they shift with level/luck ("Better odds of rarer
  upgrades when you level up" exists as a talent/effect text).
- Per-ability rank caps and per-rank modifier ranges.
- Offer weights within the rank-up/new pools (does the game bias toward your
  carry spell? unknown).
- Whether jewelry offers are drawn from zone-specific tables
  (`armory.zone_drops` string suggests so).

