# Applies a performance patch to YOUR OWN locally-downloaded copy of a mod zip.
# No mod files are distributed by this repository - this script edits the copy
# you already have (a backup is created next to it first).
#
# Usage (from the repo root, in PowerShell):
#   .\tools\Apply-Patch.ps1 -Mod aiTracks
#   .\tools\Apply-Patch.ps1 -Mod AITrafficNoCollision
#   .\tools\Apply-Patch.ps1 -Mod aiTracks -ZipPath "D:\path\to\FS25_aiTracks.zip"
#
# The patch only applies to the exact mod version it was written for
# (aiTracks v2.2.0.0 / AITrafficNoCollision v1.0.0.0). If the author has
# released a newer version, the script stops without changing anything.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('aiTracks', 'AITrafficNoCollision')]
    [string]$Mod,

    [string]$ZipPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$hunksFile = Join-Path $repoRoot ("patches\FS25_" + $Mod + "-hunks.json")
if (-not (Test-Path -LiteralPath $hunksFile)) { throw "hunks file not found: $hunksFile" }

if (-not $ZipPath) {
    $myGames = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\FarmingSimulator2025\mods'
    $ZipPath = Join-Path $myGames ("FS25_" + $Mod + ".zip")
}
if (-not (Test-Path -LiteralPath $ZipPath)) { throw "mod zip not found: $ZipPath (pass -ZipPath)" }

$spec = Get-Content -LiteralPath $hunksFile -Raw | ConvertFrom-Json

# backup
$backup = "$ZipPath.pre-patch.bak"
if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $ZipPath -Destination $backup
    Write-Host "backup created: $backup"
}

# extract to temp
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("modpatch_" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $work -Force

    foreach ($file in $spec.files) {
        $target = Join-Path $work ($file.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $target)) { throw "expected file missing in zip: $($file.path) - wrong mod version?" }

        $text = [System.IO.File]::ReadAllText($target)
        $n = 0
        foreach ($hunk in $file.hunks) {
            $old = $hunk.old -replace "`r`n", "`n"
            $new = $hunk.new -replace "`r`n", "`n"
            $norm = $text -replace "`r`n", "`n"
            $idx = $norm.IndexOf($old, [System.StringComparison]::Ordinal)
            if ($idx -lt 0) {
                throw "hunk $($n + 1) for $($file.path) did not match - the mod version differs from the one this patch targets. Nothing was changed (delete the .bak if you want to keep it anyway)."
            }
            $text = $norm.Remove($idx, $old.Length).Insert($idx, $new)
            $n++
        }
        [System.IO.File]::WriteAllText($target, $text)
        Write-Host "patched $($file.path): $n hunk(s)"
    }

    # rebuild zip in place
    Remove-Item -LiteralPath $ZipPath -Force
    $items = Get-ChildItem -LiteralPath $work | ForEach-Object { $_.FullName }
    Compress-Archive -Path $items -DestinationPath $ZipPath -Force
    Write-Host "done: $ZipPath"
    Write-Host "NOTE: decline ModHub update prompts for this mod, or the patch will be overwritten."
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
