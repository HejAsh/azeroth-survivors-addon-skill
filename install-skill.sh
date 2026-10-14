#!/bin/sh
# Install azeroth-survivors-addon to every Agent Skills location
# Run from the folder containing azeroth-survivors-addon/
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)/azeroth-survivors-addon"
[ -f "$SRC/SKILL.md" ] || { echo "canonical skill not found at $SRC" >&2; exit 1; }
for t in \
  "$HOME/.agents/skills/azeroth-survivors-addon" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/agents/skills/azeroth-survivors-addon" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/azeroth-survivors-addon" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/crush/skills/azeroth-survivors-addon" \
  "$HOME/.claude/skills/azeroth-survivors-addon" \
  "$HOME/.codex/skills/azeroth-survivors-addon" \
  "$HOME/.crush/skills/azeroth-survivors-addon" \
  "$HOME/.cursor/skills/azeroth-survivors-addon" \
  ; do
  mkdir -p "$t/references"
  cp "$SRC/SKILL.md" "$t/SKILL.md"
  cp -r "$SRC/references/." "$t/references/"
  echo "installed -> $t"
done
mkdir -p "./.agents/skills/azeroth-survivors-addon/references"
cp "$SRC/SKILL.md" "./.agents/skills/azeroth-survivors-addon/SKILL.md"
cp -r "$SRC/references/." "./.agents/skills/azeroth-survivors-addon/references/"
echo "installed -> ./.agents/skills/azeroth-survivors-addon"
