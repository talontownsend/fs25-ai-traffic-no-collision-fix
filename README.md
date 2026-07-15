# FS25 Mod Performance Patches

Tested performance fixes for two popular Farming Simulator 25 mods, offered to their authors
for adoption — published here as **patches you apply to your own downloaded copy**. This
repository distributes **no mod files**: only diffs, an apply script, and the measurement data.

| Mod | Author | Issue | Result |
| --- | --- | --- | --- |
| AI Traffic No Collision v1.0.0.0 | Huxinator | ~24 ms main-thread stall every 1.009 s | 597 → ~0 stutter events / 10 min |
| True AI Tracks v2.2.0.0 | KCHARRO | throttle bug → full vehicle scan every frame | ≈ +0.6 ms/frame back (+1.8 fps with 3 helpers) |

Both mods are ModHub-only releases without public repositories, so these fixes can't be
submitted as pull requests. They have been offered directly to both authors — if either ships
an official update containing a fix, use that and delete these patches.

## Applying a patch

You need the mod already installed from the official ModHub (the exact versions above).

```powershell
git clone https://github.com/talontownsend/fs25-mod-performance-patches
cd fs25-mod-performance-patches
.\tools\Apply-Patch.ps1 -Mod aiTracks
.\tools\Apply-Patch.ps1 -Mod AITrafficNoCollision
```

The script backs up your original zip next to itself (`*.pre-patch.bak`), verifies every hunk
matches the expected mod version (it refuses to touch anything else), edits the scripts inside
your copy, and rebuilds the zip in place.

**Notes**
- Decline ModHub update prompts for patched mods, or the patch is overwritten (that's also how
  you *adopt* an official fix later — just accept the update).
- Patched zips have a different hash than ModHub's: fine in singleplayer; multiplayer requires
  all players (and the server) to use the same zip.
- If your mods folder is in a non-default location, pass `-ZipPath`.

## Fix 1: AI Traffic No Collision — periodic stutter

**Symptom.** A metronomic ~24 ms main-thread block every 1.009 s (the mod's 1000 ms scan timer
plus the discarded frame remainder). CapFrameX: 597 stutter events in 10 minutes; also reported
by ModHub reviewers ("fps drops every ~2 seconds") and in the mod's GIANTS forum thread.

**Root cause.** Every second the mod re-derived the traffic set from scratch:
1. `overlapSphere` with `CollisionMask.ALL` at 90 m around up to 3 positions returns *every
   shape nearby* (often thousands); each hit costs a C++→Lua callback invocation even when
   rejected.
2. Rejected static geometry was re-classified every scan, forever (`overlapVisitedNodes` reset
   per scan), using name searches and recursive child scans.
3. All scan positions were processed within a single frame.

**Fix** (`patches/FS25_AITrafficNoCollision-performance.patch`) — detection semantics unchanged:
- query the overlap with the mod's own vehicle/traffic collision flags (dozens of hits instead
  of thousands); `CollisionMask.ALL` kept as fallback where flags are unavailable
- persistent "not traffic" verdict cache (reset every 2 min for engine node-id recycling)
- per-hit classification deferred to a 24-hits-per-frame budget
- one scan position per fire (round-robin), memoized per-vehicle classification, throttled
  bookkeeping

**Measured** (10-minute CapFrameX captures, same save/scenario):

| build | metronomic events | spike cost | p99 frametime |
| --- | --- | --- | --- |
| original | 597 | ~26 ms | 41–53 ms |
| + cache/defer/round-robin | 188 | ~13 ms | 29 ms |
| + targeted overlap mask | **10 (aperiodic)** | — | **27 ms** |

Functionality verified in-game after each step: AI traffic still passes through / yields to
player and AI vehicles.

## Fix 2: True AI Tracks — every-frame scan

**Symptom.** Constant per-frame cost that grows with vehicle count (worst with several AI
helpers running).

**Root cause.** `scripts/aiGround.lua` accumulates FS25's **millisecond** `dt` but compares it
against `CHECK_INTERVAL / 1000` (= `0.15`), so the 150 ms throttle trips on the first frame,
every frame — the full `g_currentMission.vehicles` scan with recursive implement processing
runs ~50× more often than intended.

**Fix** (`patches/FS25_aiTracks-throttle-fix.patch`): compare milliseconds to milliseconds.

**Measured** (10-minute captures, same scenario, 2–3 AI helpers): median frametime
19.27 → 18.67 ms, average 50.8 → 52.6 fps. Track visuals unchanged (the scan still runs at the
author's intended 150 ms cadence). The companion mods (NEXAT / CRAWLERS) contain no periodic
code and need no changes.

## Methodology

Frame-time data captured with [CapFrameX](https://www.capframex.com/) (10-minute PresentMon
captures), analyzed for spike cadence (inter-event interval histograms) and per-frame
CPU/GPU-busy attribution. The 1.009 s fingerprint — 1000 ms timer + discarded frame remainder
at ~50 fps — is what identified the scan timer from the capture data alone.

## Rights & takedown

The mods remain the property of their authors (Huxinator; KCHARRO / "True AI Tracks"). The
diffs contain the minimal code fragments needed to describe and apply the fixes — standard
bug-report practice. Nothing here enables using a mod you haven't downloaded from the official
ModHub yourself. **If you are one of the authors and want anything here changed or removed,
open an issue and it will be done promptly** — the goal of this repository is to get these
fixes into your official releases, nothing more.

The apply script and documentation are MIT-licensed (see LICENSE). The `.patch` files include
fragments of the respective authors' code, which remain under their rights.
