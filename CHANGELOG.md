# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Synced `azeroth-survivors-addon/references/api.md` and `SKILL.md` with the
  updated `addon_docs.md`: added `AZS_GetDebuffs()`, `AZS_GetHealing()`,
  `AZS_GetBossMeter()`, `AZS_GetLairs()`, the `debuffs` field on bosses and
  guardians, the `AZS_DEBUFFS`, `AZS_HEALING`, `AZS_BOSSMETER`, `AZS_CHESTS`
  and `AZS_LAIRS` tables, and their `CHAT_MSG_ADDON` prefixes.

### Added
- `CHANGELOG.md` to track notable changes going forward.

## How to publish a release

1. Update this file: move the `[Unreleased]` entries under a new
   `## [x.y.z] - YYYY-MM-DD` heading.
2. Commit, then tag: `git tag -a vX.Y.Z -m "vX.Y.Z"` and `git push origin vX.Y.Z`.
3. On GitHub, open **Releases → Draft a new release**, pick the tag, and
   use **Generate release notes** (or paste the changelog section) for the
   release body. GitHub will attach the source archive automatically.