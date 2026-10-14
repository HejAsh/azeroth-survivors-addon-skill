# Installs azeroth-survivors-addon to every agent that speaks Agent Skills
# Run from the folder containing azeroth-survivors-addon/
$src = Join-Path $PSScriptRoot "azeroth-survivors-addon"
if (!(Test-Path "$src\SKILL.md")) { throw "canonical skill not found at $src" }
$targets = @(
  "$env:USERPROFILE\.agents\skills\azeroth-survivors-addon",
  "$env:USERPROFILE\.config\agents\skills\azeroth-survivors-addon",
  "$env:USERPROFILE\.config\opencode\skills\azeroth-survivors-addon",
  "$env:USERPROFILE\.config\crush\skills\azeroth-survivors-addon",
  "$env:USERPROFILE\.claude\skills\azeroth-survivors-addon",
  "$env:USERPROFILE\.codex\skills\azeroth-survivors-addon",
  "$env:LOCALAPPDATA\agents\skills\azeroth-survivors-addon",
  "$env:LOCALAPPDATA\crush\skills\azeroth-survivors-addon"
)
foreach ($t in $targets) {
  if ([string]::IsNullOrWhiteSpace($t)) { continue }
  New-Item -ItemType Directory -Force -Path $t | Out-Null
  Copy-Item "$src\SKILL.md" "$t\SKILL.md" -Force
  New-Item -ItemType Directory -Force -Path "$t\references" | Out-Null
  Copy-Item "$src\references\*" "$t\references\" -Recurse -Force
  Write-Host "installed -> $t"
}
# project-local universal fallback (picked up via cwd walk)
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\.agents\skills\azeroth-survivors-addon\references" | Out-Null
Copy-Item "$src\SKILL.md" "$PSScriptRoot\.agents\skills\azeroth-survivors-addon\SKILL.md" -Force
Copy-Item "$src\references\*" "$PSScriptRoot\.agents\skills\azeroth-survivors-addon\references\" -Recurse -Force
Write-Host "installed -> $PSScriptRoot\.agents\skills\azeroth-survivors-addon"
